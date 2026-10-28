# 華和梨のチェック結果の読み方

`scripts/check.ps1`（`check-dic.ps1`、`lint.ps1`）と `scripts/shiori.ps1` の出力の扱い。全体の手順は `references/workflows/check.md`。

## 華和梨の 3 つの調べ方

| 調べ方 | 使うもの | 見つかるもの | 副作用 |
|---|---|---|---|
| `check-dic.ps1` | kosui.exe `--check`（最新の華和梨の安全モード） | 読み込みのエラー（括弧やクォートの閉じ忘れ、`=kis` の外の KIS の文など）と、読み込み中に `=kis` が実行されて出たエラー・警告。`-Event OnBoot` で、イベントの実行時のエラーも | なし（ファイルを書かない、SAORI を読まない、SSP に送らない） |
| `lint.ps1` | kosui.exe `--check` の静的検査 | 実行しなくても分かるもの: どこにも定義されていないエントリの参照、未知のコマンド名、正規表現の括弧。イベントでしか呼ばれない単語も含めて全部 | なし |
| `shiori.ps1` | このゴーストの `shiori.dll`（tamacs.exe） | 実際に返すトークと、その処理中のエラー・警告 | 一時コピーで動かす。SAORI は本当に動く |

まず `check.ps1` で上の 2 つを行い、直したトークやイベントは `shiori.ps1` で実際に呼ぶ。kosui.exe は `scripts/setup.ps1` がホームフォルダに入れる（無いと `SKIPPED`、終了コード 3）。

## 診断の書式

どれも華和梨 Phase 9.2 の書式で、パスはゴーストのルートからの相対にして出す。

```
ghost/master/dict-main.txt(12): error K-E0028: undefined function "fooo" called.
    in <word> at ghost/master/dict-main.txt(12)
    in ${System.Callback.OnGET} at ghost/master/kawarirc.kis(5)
```

- 1 行目が誤りの位置（実行時の診断は、実行していた単語が定義されている行）。2 行目からが呼び出しの連鎖（`<word>` は単語、`<kis zone>` は `=kis` のゾーン、`${名前}` はエントリ、`$(名前)` は関数）。複数行の単語は、その単語の先頭の行になる。実行時に作られた単語（`setstr` などで入れたもの）には位置が無い。
- 番号（`K-E0028` など）は華和梨が変えない・使い回さないもの。下の表で意味を引く。
- 位置の無い診断（`error K-E0028: ...` だけ）は、`-Eval` に書いた式の中や、実行時に作られた単語の中で起きた。

## check-dic の error と warning

- **error（K-E）は直す。** 括弧の誤りは、誤りの位置より後ろの行で出て、後ろに偽のエラーが続く。最初の 1 つを直して、もう一度行う。疑わしい範囲を `:rem` 〜 `:endrem` で囲んで絞り込む方法もある。
- 読み込み中の `=kis` が出したエラーは、本物の SSP でも起動のたびに出ている（たとえば、全エントリを `clear` で消す処理が書き込み禁止の `System.DataPath` にも触れて K-E0030 になる）。辞書の動作に影響が無いこともあるが、作者に伝えてから直すか決める。
- **warning（K-W）** は確かめて、直すか、そのままでよい理由を作者に伝える。`-Strict` なら失敗になる。
- `-Decl` を付けると、空のエントリの読み出し（K-W0003）も出す。あとで値を入れる変数も空として出るので数が多い。綴りの誤りを探すときに使う。
- `-Event OnBoot,OnClose` は、読み込みの後に、そのイベントを SSP と同じ形（`System.Request.ID` に ID を入れて `System.Callback.OnGET` を評価）で安全モードのまま実行し、実行時のエラーも出す。返すトークは出さない（見るなら `shiori.ps1`）。`-Reference '0,0,0,0,Head'` で Reference も渡せる。ID と Reference は ASCII だけ（kosui が引数を ANSI のコードページで読むため）。
- kosui.exe は**最新の華和梨**で、このゴーストの `shiori.dll` ではない。`shiori.dll` より新しいコマンドを使っていても通るので、`scripts/doctor.ps1` の `KAWARI up to date` が missing なら、その版で使えるか kawari-docs の `other/changelog.md` で確かめる（または更新を作者に提案する。`references/kawari/update.md`）。
- 安全モードでも `=kis` は本当に実行される。終わらない繰り返しがあるとタイムアウト（`timed out`）になる。

## lint の読み方（`scripts/lint.ps1`）

kosui `--check` が、辞書の全部の単語と `=kis` を、実行せずに調べる。実行されない枝やイベントでしか呼ばれない単語も見る。

| コード | 内容 | 扱い |
|---|---|---|
| K-W2001 | どこにも定義されていないエントリの参照（`reference to undefined entry "名前"`） | 綴りの誤り、コメントアウトされた定義、どこでも値を入れていない変数のことが多い。実行時に名前を組み立てて定義している（`setstr ${x}.name ...`）なら誤りではない |
| K-W2002 | 組み込みでも定義済みの関数でもないコマンド名（`unknown command "名前"`） | 綴りの誤り（`serstr`）、Phase 7 の `$([ ... ])`、`);` の後に取り残された `else` など。ほぼ本物の誤り |
| K-W2003 | `regex_*` の引数に、引用符の無い `( )` | 括弧が消えている。パターンを `"..."` で囲む |
| K-W2004 | `regex_replace` の置換文字列に、引用符の無い `${N}` | `"${1}"` のように囲む |

- 定義済みとみなされるもの: 辞書にあるエントリ、`setstr` などの引数にリテラルで書かれた名前、文字列の中の `$(...)` に書かれた名前、先頭だけリテラルで後ろを組み立てる名前（`launch_a_${n}` の `launch_a_`）、`System.*`、`@*`。`${...}` で組み立てた名前は調べない。
- 誤りでないものは、その行の**すぐ上の行**に `# lint:disable-next-line=K-W2001` と書いて抑える（複数なら `K-W2001, K-W2003`）。華和梨のコメントは行頭の `#` だけなので、行末には書けない。複数行の単語はエントリ定義の前の行に書く。抑えられるのは K-W2xxx だけ。
- lint の終了コードは、指摘があっても 0（`-Strict` で 1）。

## 診断コードの一覧

kawari-docs にまとまった一覧は無いので、華和梨のソース（`kawari_log.h`、`kawari_rc.cpp`）とメッセージを突き合わせたもの。メッセージの日本語の説明は https://ukatech.shillest.net/kawari-docs/other/error-messages/ 。

| コード | メッセージ | 意味 |
|---|---|---|
| K-E0001 / K-E0002 | `unexpected EOL (EOF) in quoted string.` | クォートが閉じない |
| K-E0003 / K-E0029 | `unknown mode found :` / `can not change to unknown mode.` | `=kis` `=dict` `=end` 以外の `=` の行 |
| K-E0004 | `no entry names.` | エントリ名が無い（辞書定義ゾーンに KIS の文を書いた） |
| K-E0005 | `')' not found. runaway entry definition?` | 括弧で書いたエントリ定義が閉じていない |
| K-E0006 | `':' not found.` | `:` が無い（辞書定義ゾーンに KIS の文を書いた） |
| K-E0007 / K-E0023 | `illegal character found in inline script (expression).` | 使えない文字。クォートし忘れ |
| K-E0008 / K-E0009 / K-E0010 | `could not find EntryId ...` / `first statement` / `separator ','` | 辞書定義の形が崩れている（`=kis` の書き忘れなど） |
| K-E0013 | `')' not found. runaway script?` | `$( )` の括弧が合わない |
| K-E0015 / K-E0022 / K-E0026 | `')' not found. runaway block?` | ブロック、式、集合演算の括弧が閉じていない |
| K-E0016 / K-E0017 / K-E0018 / K-E0020 | `$名前[ ]` の誤り | 名前、`[`、添え字の式、`]` |
| K-E0021 | `parse error after` | 演算式が解釈できない |
| K-E0025 | `'}' not found. runaway entry call?` | `${` が閉じていない（`${名前)` など） |
| K-E0027 | `divide by zero.` | 0 で割った |
| K-E0028 | `undefined function "名前" called.` | 未定義のコマンドを実行した |
| K-E0030 | `access violation. "名前" is write protected.` | 書き込み禁止のエントリ（`System.DataPath`、`writeprotect` したもの）に書いた |
| K-E0032 / K-E0033 | `invalid index` / `can not copy parent to child` | 辞書操作の範囲、`copytree` の宛先 |
| K-E0034 / K-E0035 | `save failed` / `load failed` | 保存・読み込みの失敗（ファイル名の誤りなど） |
| K-E0036 | `calling SAORI (...) failed.` | SAORI を呼べない（別名の誤り、モジュールが拒んだ） |
| K-E0037 / K-E0038 | `'break' ('continue') is used out of loop` | ループの外の `break` / `continue` |
| K-E1000 / K-E1100〜1102 / K-E1200 | KIS コマンド / `regex_*` / SAORI のエラー | 個別の番号の無いもの。メッセージを読む |
| K-W0001 | `blank definition.` | 単語の無いエントリ定義（`名前 :` だけ） |
| K-W0002 | `EntryIdList can not end with ','` | `,` の後にエントリ名が無い（`,` の連続、行末、`$` やクォート）。たいてい `':' not found.` が続く |
| K-W0003 | `read access to empty entry '名前'` | 空のエントリを読んだ（`-Decl` のときだけ） |
| K-W1000 / K-W1001 / K-W1002 / K-W1200 | `KIS[コマンド] too few (many) arguments.` など | 引数の数の誤り、KIS / SAORI の警告 |
| K-W2001〜K-W2004 | （上の lint の表） | 静的検査 |

K-E0011、0012、0014、0019、0024、0031 は華和梨の内部エラー（ふつうは出ない）。

## shiori.ps1 のエラー

`-Event` や `-Eval` の応答のあとに、その処理中に華和梨が出したエラー・警告を、上と同じ書式で出す（`messages while handling the request`）。終了コード 2 なら、表示された位置を直す。読み込みのときの診断（`messages while loading the dictionaries`）は check-dic と同じものなので、そちらで直す。`-Decl` で K-W0003 も出す。使い方は `references/kawari/commands.md`。

- `shiori.ps1` は `shiori.dll` を `ghost/master` の一時コピーで動かし、一時コピーの `kawarirc.kis` の最初と最後にログの設定（`logfile` / `loglevel`）を足して、そのログを読む。表示する行番号は本物のファイルのもの。
- `shiori: SKIPPED - shiori.dll is ...` は、`shiori.dll` が Phase 9 でない。`references/kawari/update.md`。

## 関連

- コマンドと終了コード: `references/kawari/commands.md`
- kosui の検査モード: https://ukatech.shillest.net/kawari-docs/kosui/check-mode/
