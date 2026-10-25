# 里々のコマンド

里々のゴーストで、`check-dic` `shiori` `update-shiori` が実行する `scripts/shiori/satori/` の使い方。共通のコマンドは `references/commands.md`。`<ps>` は `powershell -NoProfile -ExecutionPolicy Bypass -File` の略。

| コマンド | 内容 | 終了コード |
|---|---|---|
| `<ps> scripts/check-dic.ps1` | tamacs.exe で `satori.dll` に辞書を実際に読み込ませ（`ghost/master` の一時コピーで動かすので、本物のフォルダにセーブデータなどは残らない）、里々のログからエラーを探して表示する。読み込み時に分かるのは、閉じていない `（`、`＠SAORI` の誤りや SAORI の読み込み失敗、読めない辞書、辞書が 1 つも無いこと。`-Run` を付けると、名前が単純な文（`＊名前`。条件付きと名前のない文を除く）を一時コピーの中で 1 回ずつ実行し、展開中のエラー（引数付きの呼び出しの名前違い、`式が計算不能です。`、引数の数の誤り、`＄` の行の書式の誤り）も探す。読むログの一覧は `references/workflows/check.md`。`-ShowLog` でログ全体、`-Ci` で GitHub Actions の注釈、`-Strict` で警告も失敗にする | 0 OK / 1 エラー / 3 確かめられない（tamacs.exe をビルドできない、satori.dll が Mc201-10 より古くて `Set_loghandler` が無い） |
| `<ps> scripts/shiori.ps1 -Eval '（calc、1+2）'` | SSP を使わずに、tamacs.exe でこのゴーストの `satori.dll` に SHIORI リクエストを 1 回送る。`-Eval` は里々の文を展開して、さくらスクリプトとして結果を表示する（里々の `ShioriEcho`。複数行なら 1 行ずつ Reference0、Reference1…。使い方は下の「里々の文を試す」）。`-Event <ID> -Reference '0,0,0,0,Head'` は SSP と同じ形の GET（`-Notify` で NOTIFY）、`-Request` は生のリクエスト。呼ぶたびに `ghost/master` の一時コピーで辞書を読み込み直す（`OnBoot` などは先に送らない）ので、`satori_savedata.txt` などは変わらない。応答のあとに、その処理で里々が出したエラー・警告（`（名前） not found.` など）を表示する | 0 / 1 失敗（辞書の読み込みエラー、エラー応答など）/ 2 処理中に里々がエラーか警告を出した / 3 tamacs.exe をビルドできない、satori.dll に `Set_loghandler` が無い |
| `<ps> scripts/update-shiori.ps1` | `satori.dll` と `satorite.exe`（ゴーストに `saori/ssu.dll` が残っていればそれも）を、[ukatech/satoriya-shiori](https://github.com/ukatech/satoriya-shiori/releases) の最新リリースの `satori.zip` に更新する。ゴーストにあるファイルだけを置き換え、無いファイルは足さない（`satori.dll` が無いときだけ `-Force`）。更新の前後のバージョン（DLL の中の `phase McXYY-Z`）を表示し、更新後に辞書チェックを行って、失敗したら元に戻す。手元と同じ系統（Unicode 版 `Mc2XX` か ACP 版 `Mc1XX`）の最新を取り、Unicode 版は当面プレリリースなのでプレリリースも対象にする（`-StableOnly` で除く）。`-Variant Unicode` / `-Variant Acp` で系統を切り替え、`-Tag Mc201-5` で版を指定、`-DryRun`（`-WhatIf`）で確認のみ、手元より古いリリースは `-Tag` / `-Variant` / `-Force` が無ければ入れない | 0 / 1 失敗 |

## 里々の文を試す（`scripts/shiori.ps1`）

`-Eval` は、里々のデバッグ用 ID の `ShioriEcho` に、渡した行を 1 行ずつ「トークの本文の 1 行」として展開させる。SSP もゴーストの起動も要らない。

```
<ps> scripts/shiori.ps1 -Eval '（calc、1+2）'                            → 3 の入ったさくらスクリプト
<ps> scripts/shiori.ps1 -Eval '（メニュー）' -Plain                       → ＊メニュー を呼ぶ（-Plain: 自動ウェイトと自動改行を入れない）
<ps> scripts/shiori.ps1 -Eval '（call、あいさつ、太郎）'                  → 引数付きで文を呼ぶ（文の中では（A0）で参照）
<ps> scripts/shiori.ps1 -Eval "＄好感度＝１０`n（好感度）"               → 複数行は 1 つの文字列にして渡す。＄の行も 1 行として実行され、変数は同じ実行の中の次の行から見える
<ps> scripts/shiori.ps1 -Event OnTalk                                    → 名前のない文（ランダムトーク）を 1 つ実行する
<ps> scripts/shiori.ps1 -Event OnBoot                                    → イベントとして実行する（＊OnBoot）
<ps> scripts/shiori.ps1 -Event メニュー                                   → On で始まらない ID は、（メニュー）として展開される
```

- **名前で文や単語群を呼ぶには、`（名前）` と書く**。`＊メニュー` の文も `＠あいさつ` の単語群も `（メニュー）` `（あいさつ）` で呼べる（単語群は中の 1 つがランダムに選ばれる）。名前は、関数（内蔵関数・ssu・`＠SAORI` に登録した SAORI）、単語群、文、変数、組み込み名の順に探される。`＊名前<タブ>条件` の文は条件が真のときだけ候補になる。名前のない文（ランダムトーク）は `-Event OnTalk` で呼ぶ。
- `-Eval` は文字列 1 つを取る。複数行は、改行を含む 1 つの文字列（PowerShell なら ``"1行目`n2行目"``）にする。空行は捨てられる。変数への代入は本物の `satori_savedata.txt` には残らない（一時コピーで動かすため）。
- 結果は、里々が作ったさくらスクリプト（ウェイトや改行が入る。`-Plain` で外せる。`-Event` にも付けられる）。文字コードは UTF-8。
- 里々は、選択肢 `\q[ラベル,ID]` の ID の後ろに、バイト値 1、ラベル、バイト値 1、通し番号を足す（`OnChoiceSelect` で読み戻すため）。表示では、バイト値 1 を `<01>` と書く。`-Plain` では、足した部分を外して `\q[ラベル,ID]` と表示する。
- `ShioriEcho` は、辞書側で `＄デバッグ＝有効` にしていて、かつ `SecurityLevel: local` のときだけ動く。`scripts/shiori.ps1` は、一時コピーの `satori_conf.txt` の `＊初期化` の最後に `＄デバッグ＝有効` を足して実行するので、ゴースト側でデバッグモードを有効にしておく必要はない（本物の `satori_conf.txt` は変えない）。
- 実行は `ghost/master` の一時コピーで行うので、`satori_savedata.txt` と `satori_savebackup.txt` は変わらない。ただし辞書のコードは本物なので、SAORI の呼び出しや外部プログラムの実行は本当に行われる。
- 応答のあとに、里々のログから拾ったエラー（`[error]`）・警告（`[warning]`）・参考（`[note]`）を出す。よくあるもの: 引数付きの呼び出しの名前違い（`（foo、1） not found.` は [error]）、名前が見つからない（`（名前） not found.` は [warning]。一度も代入していない変数もこう出る）、`式が計算不能です。`、引数の数の誤り、存在しないジャンプ先（`＞名前 not found.` は [note]）。

`-Eval` と `-Event` は任意の里々のコードを実行できる（`load_saori` や `set_property` などのローカル専用の関数も使える）。SKILL.md の `allowed-tools` で、スキルを使っているターンの間は確認なしで実行できる（許可は次のメッセージで切れる。ずっと許可するには、README.md の「許可の確認を減らす」）。SAORI の呼び出しや外部プログラムの実行を含む文は、中身を読んでから呼ぶこと。

