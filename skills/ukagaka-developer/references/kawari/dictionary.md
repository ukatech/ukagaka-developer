# 華和梨辞書の書き方の要点

華和梨（KAWARI）のゴーストの辞書（`ghost/master/kawarirc.kis` と、そこから `load` する辞書）を書くときの要点。対象は **Phase 9 の `shiori.dll`**（Phase 8 の辞書は、そのまま Phase 9 で動く）。仕様書は kawari-docs（https://ukatech.shillest.net/kawari-docs/ 。リポジトリ: https://github.com/ukatech/kawari-docs ）。ここに書いた要点は、そこで確かめたもの。構文や KIS コマンドは推測で書かず、kawari-docs で確かめる（ukagaka-doc MCP なら `source` に `kawari_docs`。`SKILL.md` の「仕様を調べる」）。ゴースト固有の決まり（どの辞書ファイルに何を書くか、イベントのエントリ名の付け方、キャラクター、口調）は `GHOST.md` にある。

kawari-docs の構成: `startup/`（導入）、`grammar/`（辞書の文法）、`shiori/`（SHIORI としての動作、イベント、ランダムトーク、SAORI）、`kis/`（KIS コマンド。1 コマンド 1 ページ、一覧は `kis/index.md`）、`kosui/`（幸水と `kosui --check`）、`tips/`、`migration/`（Phase 7 以前からの移行）、`spec/`（仕様書、BNF）、`other/`（`error-messages.md`、`changelog.md`）。生の Markdown は `https://ukatech.shillest.net/kawari-docs/kis/set.md` のように、リポジトリと同じパスで読める。

## まず確かめること（ゴーストごとに違う）

- **`System.Callback.OnGET` の定義を探す。** 華和梨（Phase 8 以降）は、イベントを自動では辞書のどこにも割り振らない。本体からの GET はすべて `System.Callback.OnGET` が受け、その中に書かれた「振り分け」がイベントのエントリを呼ぶ。振り分けの書き方はゴーストやミドルウェア（OpenKEEPS など）ごとに違う。
  - `${event.${System.Request.ID}}`（`event.OnBoot` などに書く。`On` で始まらない ID は `resource.<ID>`）
  - `${reply.${System.Request.ID}}`（`reply.OnBoot` などに書く）
  - `OnSecondChange` のように、ID と同じ名前のエントリを直接呼ぶもの
  - NOTIFY は `System.Callback.OnNOTIFY`（`notify.<ID>` など）
  
  新しいイベントは、そのゴーストの振り分けが呼ぶ名前で書く。わかったことは `GHOST.md` の「イベントと辞書ファイルの対応」に書いておく。
- **コールバックのエントリは、全部の単語を順に評価してつなげる**（普通のエントリのように 1 つを選ぶのではない）。`System.Callback.OnGET` をもう 1 か所で定義すると、両方が動いて出力がつながる。ミドルウェアの入ったゴーストに、別の振り分けを書き足さない。
- **辞書ファイルの一覧と読み込み順**は `kawarirc.kis` の `=kis` の中の `load ファイル名;` の並び。ファイル名と拡張子は自由（`dict-*.txt`、`ghost-*.txt` などは推奨にすぎない）。`kawari.ini` は Phase 8 以降は読まれない（`load kawari.ini;` のように辞書として読ませているゴーストはある）。
- **文字コードを確かめる**（下の「文字コード」）。`scripts/doctor.ps1` の `UTF-8 dictionaries` が、Shift_JIS の辞書を挙げる。

## 辞書の書き方

- 辞書ファイルは、`=` で始まる行で 2 つのゾーンに分かれる。既定は**辞書定義ゾーン**（`=dict` 〜 `=end` でも書ける）、`=kis` 〜 `=end` が**スクリプトのゾーン**（KIS の文を `;` で区切って並べる。読み込んだ瞬間に実行される）。`function` の定義や `load`、`saoriregist` は `=kis` の中に書く。
- **エントリ定義**: `エントリ名 : 単語 , 単語 , 単語`。`,` が単語の区切りで、エントリを呼ぶとその中から 1 つがランダムに選ばれる。`:` と `,` の前後、行頭と行末の空白は消える。定義は改行で終わる。**同じエントリ名を何度定義しても、単語が足されるだけ**（置き換わらない）。`名前1 , 名前2 : 単語` で複数のエントリに同じ単語を入れる。
  - エントリ名に使えるのは英数字、`.`、`_`、`@`、`?`、全角文字。先頭に `.` は使えない。`@` で始まる名前は一時エントリ（1 つの単語を実行している間だけある。関数の引数は `@arg`）。`System.` で始まる名前は華和梨の予約。
- **単語の中にそのまま書けない文字**: どこでも `"` `'` `$` `(` `)`。辞書定義ゾーンの単語ではさらに `,`、`$( )` と `=kis` の中ではさらに `;`。使うときは `"..."` か `'...'` で囲む（中は書いたとおりに出力され、`${}` も展開されない。特別なのは `\"`（`\'`）と `\\` だけ）。文頭・文末の空白を残したいときも囲む。さくらスクリプトの `\s[0]` などは、そのまま書いてよい（`\\` にしない）。
- **ブロック `( ... )`**: 中は 1 つの単語の要素になり、`,` `;` を書けて自由に改行できる（改行と行頭の空白は消える。括弧自体も出力されない）。長いトークやメニューはこれで書く。**開き括弧はエントリ名と同じ行に書く**（次の行に書くと、前の行で定義が終わってしまう）。`${ }` `$[ ]` `$( )` も、閉じるまでは改行してよい。

  ```
  event.OnBoot : (
      \0\s[0]こんにちは。\w9\n
      \1\s[10]よう。\e
  )
  ```
- **コメント**は、行頭（空白を除いた最初の文字）が `#` の行だけ。**行末にコメントは書けない**（`単語 # メモ` の `# メモ` は単語の一部になる）。`:rem` だけの行から `:endrem` だけの行までも無視される。複数行の単語の途中でも、行頭が `#` の行は消える。
- **置換**（入れ子にでき、内側から評価される）:
  - `${エントリ}`: 単語を 1 つ選んで評価する。無いエントリは**黙って空文字列**になる（綴りの誤りが見つかりにくい。`scripts/lint.ps1` が K-W2001 で見つける）。`${event.${System.Request.ID}}` のように名前を組み立てられる。
  - `$エントリ[式]`: 指定位置の単語（0 から。負なら末尾から）。
  - `$[ 式 ]`: 演算式。**整数のみ（32bit）**。演算子は C 風（`+ - * / % ** == != < <= > >= && || !`、`=~` は部分文字列を含むか）。数値に見えるものは数値として比べる（`"001" == "1"` は真。文字列として比べるのは `compare`）。結果は `true` / `false`。**偽は `""` `"0"` `"false"` だけ**。
  - `$( コマンド 引数 ; コマンド 引数 )`: インラインスクリプト（KIS）。
  - `${0}` `${1}` …: 同じ単語の中で先に置換した結果。集合演算 `${A & B}` `${A + B}` `${A - B}`。
- **KIS の文**: `$(if 条件 真の文 else if 条件2 文2 else 偽の文)`（`else` の前後に空白か改行）。`if` `while` `until` `loop` `foreach` `function` `lambda` `return` `silent` などの**構文コマンドは、使う枝だけを評価する**。それ以外の**関数コマンドは、引数を先に全部展開してから実行する**。`$( )` の最後の文以外は、構文コマンドの後にも `;` が要る。
- よく使うコマンド（書式は kawari-docs の `kis/<名前>.md` で確かめる）:
  - 代入: `setstr E 文字列`（文字列として登録。ふつうはこれ）/ `set E 単語`（`${}` を残すと、読むたびに評価される）。どちらもエントリを空にしてから入れる。追加は `adddictstr` `pushstr`（`adddict` `push`）。
  - 読む: `${E}`、`entry E 既定値`（1 つ選ぶ。空なら既定値）、**`get E` は全単語を評価してつなげる**、`size E`（単語数）、`getrandom`、`getcode`。
  - `inc E [増分 [上限]]` / `dec`、`clear E` / `cleartree E`、`rand N`（0 以上 N 未満）、`date 書式`、`echo`、`eval`、`length` `substr` `match` `match_at` `sub` `gsub` `split` `join` など。正規表現は `regex_*`（Phase 9。**括弧を含むパターンは `"..."` で囲む**。囲まないと華和梨のブロックとして括弧が消える）。
  - 関数: `=kis` の中で `function 名前 $( ... );`。引数は `$@arg[1]` 以降（`$@arg[0]` は名前）。呼び出しは `$(名前 引数)`。
- **SHIORI とのやりとり**: 要求のヘッダは `System.Request.<ヘッダ名>`（`${System.Request.ID}`、`${System.Request.Reference0}`）、要求の種類は `System.Request`。応答ヘッダは `System.Response.<ヘッダ名>` に `setstr` する（コミュニケートの宛先は `System.Response.Reference0`）。`OnGET` の評価結果が空なら 204、あれば 200 で Value になる。`version` などの ID は、`OnGET` が空を返したときだけ華和梨が自動で答える。
- **ランダムトーク**は、多くのゴーストで `OnSecondChange` でカウンタを進め、決めた秒数で話す。`OnSecondChange` は最小化中にも来るので、`${System.Request.Reference3}` が 1 のときだけ話す。どう作られているかはゴーストごとに違うので、そのゴーストの書き方に合わせる（`GHOST.md`）。
- **SAORI**: `=kis` の中で `saoriregist saori\foo.dll 別名 [preload|loadoncall|noresident];`、呼ぶのは `$(callsaori 別名 引数...)`（`callsaorix 別名 格納エントリ 引数...` は `格納エントリ.Value0` などにも入る）。本体内蔵の `internal_*` は登録なしで呼べる（Phase 9）。
- **保存**: 変数（エントリ）は自動では保存されない。辞書が `save ファイル エントリ...`（`savecrypt` は暗号化）で書き、起動時に `load` で読み戻す。どのファイルに保存しているかは `GHOST.md` に書いておく。Phase 9 の `save` は UTF-8（BOM あり）で書く。
- **セキュリティ**: 外部（`SecurityLevel` が local でない要求）からは、本体との通信や SAORI over DirectSSTP が使えない。`securitylevel` は初期化中に 1 回だけ設定できる（既定は high）。

## 文字コード

- Phase 9 は、辞書ファイルを、**先頭に BOM があるか、ファイル全体が UTF-8 として正しければ UTF-8、そうでなければ Shift_JIS** として読む。古いゴーストの辞書は、ほとんどが Shift_JIS（CRLF）。
- **Shift_JIS の辞書を、UTF-8 前提の道具（エージェントのファイル編集など）で編集しない。** 日本語が化けるうえに、UTF-8 の行が 1 行混じったファイルは「UTF-8 として正しくない」ので全体が Shift_JIS として読まれ、足した行が化ける。
  - 作者の了承を得て、**BOM なしの UTF-8 に変換してから**編集する: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori/kawari/convert-utf8.ps1`（確認のみ）→ `-Apply`（元のファイルはホームフォルダの `backups/` に退避する）。変換の後は `scripts/check-dic.ps1` と `scripts/lint.ps1` の結果が変換前と同じことを確かめる。
  - 変換すると、Phase 8.2.x の `shiori.dll` では読めなくなる（Phase 8 は UTF-8 を判定しない）。`convert-utf8.ps1` は、`shiori.dll` が Phase 9 でなければ止まる。
  - **BOM は付けない。** 暗号化した行（`!KAWA0000` / `!KAWA0001`）は、BOM のあるファイルでは UTF-8、無いファイルでは Shift_JIS として復号されるので、Shift_JIS で暗号化された行は BOM を付けると壊れる。
  - 変換しないなら、Shift_JIS のまま読み書きできる方法（PowerShell で `[Text.Encoding]::GetEncoding(932)` を使うなど）で編集し、改行も元のまま（CRLF）にする。
- 新しく作る辞書は UTF-8（BOM なし）、改行は LF でよい（`.editorconfig`）。既存のファイルは改行も元のまま。
- 暗号化した辞書（`kawari_encode2` で作った `.kaw` など）は**直接編集しない**。元の辞書を直して暗号化し直す（元の辞書が手元に無いなら、作者に確かめる）。

## トーク（さくらスクリプト）の書き方

間の取り方、改行の入れ方、話し手の交代などの決まりと例は、`GHOST.md` の「トークの書き方」にある。どのゴーストにも共通すること:

- 華和梨は、さくらスクリプトを書いたとおりに返す（里々のような自動の改行や待ちは入らない）。`\0` `\1` で話し手を、`\s[番号]` で表情を切り替え、`\n` で改行、`\w9` などで間を入れ、`\e` で終える。サーフェス番号は `GHOST.md` の表にあるものだけを使う。
- 1 つのトークに複数の言い方を用意するときは、`,` で単語を並べる（呼ぶたびに 1 つが選ばれる）。台詞の中の `,` は単語の区切りになるので、文字として出すときは `"..."` で囲むか、全角の `、` を使う。

## 華和梨でやりがちな失敗

共通の失敗（長すぎる台詞、存在しないサーフェス番号、口調の混在、`\\`、危険なタグなど）は `references/ai-guidelines.md`。華和梨では次にも気をつける。

- 辞書定義ゾーンに KIS の文（`setstr a 1;` など）を書く。K-E0006 `':' not found.` や K-E0004 `no entry names.` になる。`=kis` 〜 `=end` の中に書く。
- 括弧の閉じ忘れ・取り違え（`${名前)` は K-E0025、`$(` の閉じ忘れは K-E0013）。エラーは誤りより後ろの行で出て、後ろに偽のエラーが続く。**最初のエラーから直す。**
- 台詞の中の `,` `(` `)` `"` `$` をそのまま書く。`,` は単語の区切りに、`( )` はブロックになって消える。`"..."` で囲む。
- 行末にコメントを書く（単語の一部になる）。
- `${E}` と `$(get E)` の取り違え。`get` は全単語をつなげて返す。
- `$([ ... ])`（Phase 7 の書き方。K-W2002 `unknown command "["`）。Phase 8 以降は `$[ ... ]`。
- コマンドの綴りの誤り（`serstr`）。未定義のコマンドは K-E0028 だが、辞書を読み込むだけでは実行されない単語の中のものは出ない。`scripts/lint.ps1` が K-W2002 で全部見つける。
- `function` を辞書定義ゾーンのエントリの中に書く（そのエントリが呼ばれるまで定義されない）。`=kis` の中に書く。
- 正規表現のパターンの括弧を囲まない（K-W2003）、`regex_replace` の置換文字列の `${1}` を囲まない（K-W2004）。
- Phase 9 で増えたコマンド（`regex_*`、`lambda`（9.1.0）、`textload_charset` など（9.1.1）、`getproperty` / `setproperty` / `executesstp`）を、それより古い `shiori.dll` のゴーストで使う。`scripts/check-dic.ps1` は最新の華和梨（kosui.exe）で調べるので、通っても SSP では動かない。`scripts/doctor.ps1` の `KAWARI up to date` を見る。
- 配布するゴーストに、デバッグ用の `loglevel` / `logfile` や `debugger on` を残す。

## 関連

- コマンド: `references/kawari/commands.md`、チェックの読み方: `references/kawari/check.md`、更新: `references/kawari/update.md`
- 診断コードの意味: `references/kawari/check.md`、華和梨のエラーメッセージ: https://ukatech.shillest.net/kawari-docs/other/error-messages/
