# 里々のチェック結果の読み方

`scripts/check.ps1`（`check-dic.ps1`）と `scripts/shiori.ps1` の出力の扱い。全体の手順は `references/workflows/check.md`。

## 里々は読み込み時にほとんど検査しない

里々は、辞書を読み込むときに文法をほとんど検査せず、文を実行するときに解釈する。読み込みで通っても、`-Run` を付けるか、`scripts/shiori.ps1` で実際に呼ばないと、実行時のエラーは見つからない。

## check-dic の error

tamacs.exe で `satori.dll` に `ghost/master` の一時コピーの辞書を読み込ませ、里々のログからエラーを拾う（パターンは `scripts/shiori/satori/satori.json`）。

- `カッコの対応関係が正しくない部分があります。` / `辞書は正しく読み込まれていません。`（その前の行に、対象の辞書ファイルのパスが出る）: 閉じていない `（` がある。カッコを文字として使うときは `φ（` と書く。全角の `（` `）` の数と、`）` の閉じ忘れを、表示されたファイルから探す。
- `SAORI読み込み中にエラーが発生: <行>`: `satori_conf.txt` の `＠SAORI` の行の誤り（`呼び出し名,相対パス` の形か、重複した呼び出し名か、DLL が無いか）。`saori/` のファイルの有無も見る。`SakuraDLLClient::load '…' ...failed.` は、SAORI の DLL が読み込めなかった（中身が SAORI でない、依存するライブラリが無いなど）。
- `loading dic…txt... failed.` / `no dictionary file (dic*.txt) was loaded`: 辞書が読めない、または 1 つも無い。辞書は `ghost/master` の直下の `dic*.txt` だけが読まれる（`＄辞書フォルダ` で変えていなければ、`another/` などの下のファイルは読まれない）。
- `loading satori_conf...failed`（warning）: `satori_conf.txt` が無いので、`＊初期化` と `＠SAORI` が読まれない。

## `-Run` のとき（展開中のエラー）

名前が単純な文（`＊名前`。条件付きと、名前のない文を除く）を一時コピーの中で 1 回ずつ実行し、その間のエラーも拾う。

- `（名前、引数） not found.`（引数付きなので関数呼び出しとみなす。関数名の打ち間違いか、`＠SAORI` に登録していない SAORI）
- `式が計算不能です。`（式のカッコの数、演算子、0 での除算を確かめる）
- `引数が足りません。` などの引数の誤り
- `※　＄による変数代入文には…　※`（`＄` の行に、タブか `＝` が無い）
- `呼び出し回数超過`（循環呼び出し）、`ジャンプ回数超過`、`括弧展開サイズ超過`
- `（名前） not found.`（warning）: 引数の無い呼び出しの名前違い、または一度も代入していない変数を読んでいる。変数を意図して読んでいるのなら問題ない（`＊初期化` で初期値を入れる書き方がある）ので、打ち間違いでないかだけ確かめる。存在しないジャンプ先（`＞名前 not found.`）は、辞書が意図して使うことが多いので、`check-dic` は表示しない（`shiori.ps1` では `[note]` で出る）。
- タイマや入力ボックスから呼ばれる文（そのときだけある変数を読む文）は、名前で直接実行すると意味のない警告が出る。その文の `＊` の行のすぐ上に、`check-dic: no-run` を含むコメント行（`＃check-dic: no-run（理由）`）を書くと、`-Run` で実行しない。実行しなかった数は、最後の行に `(N marked no-run)` と出る。同じ名前の文が複数あるときは、1 つに書けば、その名前はすべて実行しない。
- 名前のない文（ランダムトーク）は `-Run` では実行されない。`scripts/shiori.ps1 -Event OnTalk` で 1 つ実行される（選ばれるのはランダムなので、何度か実行する）。

`-Run` は、SAORI を使う文も本当に実行する（`＠SAORI` に登録した SAORI は動く）。画面や PC に影響する SAORI を使うときは、その文の中身を読んでから実行する。

## shiori.ps1 のエラー

`-Eval` や `-Event` の後に、里々のログから拾ったエラー（`[error]`）・警告（`[warning]`）・参考（`[note]`）が出る。終了コード 2 なら、表示された内容（`[in ＊名前]` が、そのとき実行していた文）から直す。使い方は `references/satori/commands.md`。

## 補足

- チェックは `ghost/master` の一時コピーで行う。里々が終了時に書く `satori_savedata.txt` / `satori_savebackup.txt` を、本物のフォルダに残さないため。
- `satori.dll` は、ビルドによっては `[ERROR]` の通知が遅れたり、まとめて出たりする。ログの通常の行からも拾っているので、表示は変わらない。
- tamacs.exe は `Set_loghandler` で里々のログを受け取る。`Set_loghandler` は里々 Mc201-10 から入ったので、それより古い `satori.dll` では、チェックが SKIPPED（終了コード 3）になる。`references/satori/update.md` の手順で更新する。

## 関連

- 里々のエラーメッセージ: https://ukatech.shillest.net/satori-docs/other/error-messages/
- コマンドと終了コード: `references/satori/commands.md`
