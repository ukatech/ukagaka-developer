# 里々のログの読み方（check-dic と shiori）と ShioriLint（lint）

`scripts/check-dic.ps1` と `scripts/shiori.ps1` が、里々のログのどこを見てエラーとしているか。パターンは `scripts/shiori/satori/satori.json` の `patterns` にあり、`scripts/shiori/satori/lib.ps1` の `Get-DevkitSatoriDiagnostics` が読む。

## 何が検査されるか

- 里々は、辞書を読み込むときに、ほとんど検査しない。読み込み時に分かるのは、辞書のカッコの対応（`カッコの対応関係が正しくない部分があります。`）、`satori_conf.txt` の `＠SAORI` の誤りと SAORI の読み込み失敗、辞書ファイルが読めないこと、辞書が 1 つも無いこと。
- 未定義の関数・名前、`＄` の行の書式の誤り、式の誤りなどは、その文を実行するときに初めて分かる。そこで `check-dic.ps1 -Run` が、名前が単純な文（`＊名前`。`名前<タブ>条件` の形と、名前のない文を除く）を、`ShioriEcho` で 1 回ずつ実行する。里々のマニュアルの `other/error-messages.md` が、メッセージの一覧。
- 名前のない文（ランダムトーク）と、条件付きの文は、`-Run` では実行しない（条件が偽なら `not found` が出て、誤検出になる）。`scripts/shiori.ps1 -Event OnTalk` を使う。
- 実行せずに調べるには、里々 Mc206-1 の ShioriLint を使う（下の「ShioriLint」）。

## 見ているもの

1. tamacs が `[ERROR]` / `[FATAL]`（エラー）、`[WARN]`（警告）として出した行。Mc201-5 では、エラー用の行が遅れて、`1057598` でつながって出ていた（`tamacs.md`）。
2. 通常のログの行。パターンの `level` は `error` / `warning` / `note`（`note` は `-IncludeNotes` のときだけ。`shiori.ps1` は付け、`check-dic.ps1` は付けない）。
3. `LoadDicFolder(` から `ok.` までに `loading` の行が 1 つも無い → 辞書が 1 つも読まれていない。

### 誤検出を避けるための扱い

- `＞名前 not found.`（ジャンプ先が無い）は `note`。里々は次の行から続きを実行するので、辞書が意図して使う（サンプルのポストと狛犬でも、日付ごとの特別なトークへのジャンプが、ほとんどの日に見つからない）。
- `（名前） not found.` は、`（名前、引数） not found.`（区切りのある呼び出し。関数の名前違いや、`＠SAORI` に登録していない SAORI）だけを `error` とし、区切りの無いものは `warning`（一度も代入していない変数を読むと、こう出る。展開結果は `（名前）` のまま残る）。
- `return: …` の行（トークの結果の繰り返し）は、スクリプトの中身そのものを見るパターン（`extract`）以外は読まない。`（名前、引数）→結果` の行は、結果がエラーの文字列で始まるもの（`→引数が足りません。`、`→'1+' 式が計算不能です。` など）だけを拾う（呼び出し元の行に、エラーの文字列が含まれて繰り返されるため）。
- リクエストの行（`--- Request ---` から `--- Operation ---` まで）と `Value=` の行は読まない。
- 同じメッセージは 1 つにまとめる（`(x3)`）。実行中のエラーには、そのとき実行していた文（`[in ＊名前]`）を、ログのインデントから求めて付ける。

## パターンを足すとき

1. 里々のソース（`satoriya/satori/`、Shift_JIS）の `GetSender().sender() <<` と `errsender() <<` からメッセージを探し、`other/error-messages.md` と照らす。一時フォルダに壊れた辞書を作り、`tamacs.exe -r`（`scripts/shiori.ps1 -ShowLog`）で実際のログの行を確かめる。
2. `scripts/shiori/satori/satori.json` の `patterns` に、`level`、`regex`、`hint` を足す。日本語はこのファイルに書く（`scripts/*.ps1` は ASCII だけ）。行頭の空白（ネストのインデント）を許す（`^\s*`）。
3. 誤検出が出ないか、`scripts/check-dic.ps1 -Run`（このゴーストの全文）で確かめる。

## ShioriLint（`scripts/shiori/satori/lint.ps1`）

里々 Mc206-1 以降の静的検査。`ID: ShioriLint`（`SecurityLevel: local`）の GET を tamacs.exe（`-r`）で送ると、里々が読み込み済みの辞書を実行せずに調べ、`ErrorLevel` / `ErrorDescription` ヘッダ（バイト値 1 区切り）で返す。仕様は https://ukatech.shillest.net/satori-docs/shiori/lint/ 。

- **バージョンで判定する**: Mc206-1 より古い里々は `ShioriLint` を名前として展開し（実測では `204 No Content`。ログに `（ShioriLint） not found.`）、Mc206-1 の「問題が無い」（200 でヘッダ無し）と、辞書によっては区別できない。だから `Get-DevkitSatoriVersion` で `Mc206-1` 未満なら SKIPPED（終了コード 3）にする。バージョンが読めない（`(unknown)`）ときは送ってみて、204 なら SKIPPED にする。
- **応答の読み方**: `ErrorLevel` と `ErrorDescription` を `[char]1` で分け、説明を `ファイル(行) : error|warning|notice: 内容` として読む。`ErrorLevel` は `error` `warning` `notice` `info`（省略の知らせ）のほか、里々の通常のエラー通知が合流して `critical` なども来る（`ファイル(行)` の形にならず、メッセージに一時コピーのパスが入るので、`ConvertTo-DevkitGhostText` で `ghost/master` に直す）。`info` と `notice` 以外は、`critical` も含めて error の数に入れる。
- **ログとの二重取りを避ける**: 里々は同じ内容を `lint: …` の行でログにも出す。`Get-DevkitSatoriDiagnostics` は、その行を読まない（`satori.json` のパターンが別の重さで拾ってしまうため）。
- **終了コード**: error があれば 1（YAYA の lint は参考情報で 0。里々の error は、実行しても意図どおりにならないと確実に言えるものに限られる）。warning は `-Strict` のときだけ失敗。notice は数えるだけで、失敗にしない。`check.ps1` は SHIORI を問わず lint を行い、古い里々では SKIPPED なので失敗にならない。
- **検証**: `ghost/master` を一時フォルダに複製して `＄foo`（タブも `＝` も無い）、`（set、a）`、閉じ忘れの `（` を足し、error と終了コード 1 を確かめる。古い `satori.dll` を上書きして、SKIPPED を確かめる。サンプルのポストと狛犬（Mc206-1）は、error も warning も 0 件で、notice が 4 件。
