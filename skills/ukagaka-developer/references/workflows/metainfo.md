# metainfo（Web アプリ向けのゴースト情報）を付ける

## 使うとき

作者が「metainfo を付けたい」「`.ukagaka` フォルダを作って」「ゴーストキャプターさくらに載せたい」「GitHub に公開したい（公開した）」と言ったとき。GitHub でゴーストを公開する話になったときも、この文書の「勧め方」に沿って、作者に**一言提案する**（押しつけない。断られたら、それ以上は勧めない）。

metainfo を作る・ゴーストの `descript.txt` に書き足すのは、作者がやりたいと答えてから行う。

## metainfo とは

metainfo standard は、Web アプリケーション（ゴーストキャプターさくらなど、ゴーストの一覧や検索を作るサービス）が必要とする、ゴーストの基本情報を表す拡張可能な規格。仕様: https://ukatech.shillest.net/metainfo-standard/ （GitHub: https://github.com/ukatech/metainfo-standard 。英語・中国語・日本語の README がある）。

- **Web アプリのためのもの**で、ゴーストの動作には関係しない。metainfo フォルダの中身は、SSP も SHIORI も読まない。
- ただし SSP 2.9.35 以降は、ゴーストの `descript.txt` の `metainfo`、`githubrepo`、`uuid_base` を保持し、プロパティシステム（`metainfo`、`githubrepo`、`uuid_base`、`uuid`）で返す。`uuid` は、ネットワークに出ずに手元の情報だけから計算する（計算は下の「UUID」と同じ。`homeurl` は `descript.txt` に書かれたものだけを使い、`var.txt` や SHIORI が返す値は使わない）。名前の代わりに UUID を書ける場面もある（`ghostlist(UUID)`、`\![change,ghost,UUID]`、SSTP の `ReceiverGhostUUID` など。UKADOC のプロパティシステムの `uuid`）。
- 例えば、ゴーストのプレビュー画像を `shell/master/` に置かなくてよくなる（プロジェクトが散らからない）。更新の置き場所が作者のページに限られない。
- 仕様にはバージョン番号の記載がない。迷ったら、上の仕様ページで確かめる（`SKILL.md` の「仕様を調べる」）。

## 勧め方

| ゴーストの置き場所 | 扱い |
|---|---|
| **GitHub にリポジトリがある** | **付けることを推奨する。** 規格の推奨は、デフォルトブランチのルートに `.ukagaka` フォルダを置くこと。あわせてリポジトリに Topics を付けると、Web アプリがゴーストと認識しやすくなる（下の「GitHub の Topics」） |
| GitHub 以外（自分のサーバー、GitLab、クラウドストレージなど） | 付けられるなら付けるとよい、と**ほのめかす**。metainfo フォルダは URL で読めればよく、GitHub に限らない。規格は、ローカルのゴーストフォルダの外、クラウドストレージのフォルダに置くと、最新の状態を保ちやすく、ユーザーの容量も使わない、と述べている |
| リポジトリもサーバーも使わない | 勧めない。聞かれたら説明する |

- ほのめかしの例:「GitHub に置くなら、Web アプリ向けの情報（metainfo）を `.ukagaka` に置いておくと、ゴーストの一覧サービスに載りやすくなります。必要なら作りますよ」。1 回言えば足りる。
- ほのめかす場面: ゴーストを公開する話（nar を作る、GitHub Actions を設定する、リリースする、テンプレートから独立させる）になったとき。ゴーストのルートに `.git` があり、リモートが GitHub なら、いっそう勧めやすい。すでに `.ukagaka/descript.txt` があれば、勧めない。
- **ゴーストの配布物（nar）には、含めても含めなくてもよい。** 規格に決まりはない。作者の好みで決めてよく、決まらなければ、今の `.narignore` のままにする（`.ukagaka/` は除外されず、nar に入る）。入れたくなければ `.narignore` と `.updateignore` に `.ukagaka/` を足す（`.updateignore` は `include:.narignore` で共通部分を取り込んでいるので、`.narignore` だけでも足りる。`references/layout.md`）。

## metainfo フォルダの置き場所（URL）を選ぶ

metainfo フォルダは、URL で読めればどこでもよい。**この URL の文字列から UUID が決まる**ので、あとから変えにくい。作者に聞いて決める。

| 置き場所 | URL の例 | 向くとき |
|---|---|---|
| リポジトリのデフォルトブランチのルート（規格の推奨） | `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/.ukagaka/` | 手間が少ない。push すれば読める。ブランチ名・オーナー名が UUID に入る |
| GitHub Pages・自分のドメインなど | `https://example.com/<ghost>/.ukagaka/` | すでにネットワーク更新を Pages などで配っているとき。UUID が GitHub のアカウントやブランチ名から切り離される。デプロイを通して配るので、手順が増える（下） |

- **`githubrepo` だけでは足りないことがある。** SSP は既定ブランチを調べにいかず、`master` とみなして UUID を計算する。既定ブランチが `main` などのリポジトリでは、`metainfo` を明示する。
- **Pages などのデプロイで配るとき**:
  - リポジトリには、規格どおり `.ukagaka/` を置く（ゴーストの `descript.txt` の `metainfo` が、デプロイ先の URL を指す）。nar と更新ファイルに入れたくなければ、`.narignore` に `/.ukagaka/` を足す。
  - デプロイの処理は、`.ukagaka/` を出力に別に載せる必要がある。ゴーストごとの処理なので、そのゴーストのデプロイ用スクリプトに足す（このスキルには、そのスクリプトは入っていない）。更新ファイルの一覧（`updates2.dau`）には載せない。
  - **先頭が `.` のフォルダは、`actions/upload-pages-artifact` v4 では隠しファイルとして除外される**（v4.0.0 のリリースノートに明記。v3 は含める）。v4 を使うなら、artifact を自前で作るか、フォルダ名を `.` で始めない名前にする（`metainfo` の URL はフォルダの名前を問わない）。Dependabot などで v4 に上がると、黙って公開されなくなるので、ワークフローに注釈を残す。
  - ブランチから配る Pages（Jekyll が走る形）では、`.nojekyll` がないと `.` で始まるフォルダが隠れる。Actions の artifact で配る形では Jekyll は走らないが、`.nojekyll` を置いておけば、どちらでも同じに動く。

## GitHub の Topics

リポジトリの About の Topics（トピック）に、種類ごとに次のものを付けることが推奨されている。metainfo 規格の `ukagaka-ghost` も、この Topics のこと。

| 種類 | 推奨する Topics |
|---|---|
| ゴースト | `ukagaka`、`ukagaka-ghost`、`sirefaso`、`sosiremi` |
| バルーン | `ukagaka`、`ukagaka-balloon`、`sirefaso`、`sosiremi`（ほかはゴーストと同じ） |

- 出典: https://changelog.de10.moe/entry/2023/01/04/081731 （作者の言による。metainfo 規格の仕様ページには、`ukagaka-ghost` を付けることだけが書かれている）。
- 設定の変更は、作者に任せる。エージェントが `gh repo edit --add-topic ...` で行うときは、先に確認を取る。
- ゴーストとバルーンが同じリポジトリにあるときは、両方の Topics を付けてよいか、作者に聞く。

## フォルダの構成

ゴーストのリポジトリの**デフォルトブランチのルート**に `.ukagaka/` を置く（別プロジェクトとして GitHub にあるゴーストの場合）。例: `https://github.com/<owner>/<repo>/tree/master/.ukagaka`

```
.ukagaka/
  descript.txt      必須。ゴーストの基本情報
  preview/          任意。プレビュー画像（フォルダも中身も任意）
    sakura.png        sakura と kero の 2 枚を推奨（動くなら sakura.apng / kero.apng）。kero1.png、kero2.png なども可
    kero.png
  icon.png          任意。アイコン
  links/            任意。関連リンクの情報（txt を任意の数）
  infos/            任意。Web アプリ向けの追加情報（txt を任意の数）
  jump_to.txt       別の metainfo フォルダへ移すとき（このフォルダが非推奨のときだけ）
```

## `.ukagaka/descript.txt`

UTF-8。**1 行目は `//meta info`**。`キー,値` の行を並べる。行末までの `//` はコメント（`://` は URL なのでコメントではない）。

```
//meta info
type,ghost
name,<ゴーストの名前>
uuid,<UUID。下の「UUID」>
sakura.name,<\0 のキャラクター名>
kero.name,<\1 のキャラクター名>
has_terms,0
craftman,<作者名>
craftmanurl,<作者の URL>
languages,ja
```

| キー | 必須 | 内容 |
|---|---|---|
| `type` | 必須 | `ghost` 固定 |
| `name` | 必須 | ゴーストの名前 |
| `craftman` | 必須 | 作者 |
| `craftmanurl` | 必須 | 作者へのリンク |
| `uuid` | 必須 | 一意な識別子（下の「UUID」） |
| `languages` | 必須 | ゴーストが対応する言語。複数は `,` で区切る |
| `sakura.name` | `type` が `ghost` のとき必須 | メインキャラクターの名前 |
| `kero.name` | 任意 | 相方の名前。複数いれば `kero1.name`、`kero2.name` のように区別する |
| `has_terms` | 任意 | `terms.txt` があれば 1、なければ 0（省略は 0。`terms.txt` は https://ssp.shillest.net/ukadoc/manual/manual_directory.html ） |
| `icon` | 任意 | アイコンのリンク。省略すると、`.ukagaka/icon.png` があればそれ |
| `uuid_base` | 任意 | UUID の衝突を避けるための追加の文字列 |

- `icon.png` は、ゴーストの `icon.ico` に 256px の PNG が入っているなら、そのまま取り出せる（`scripts/image.ps1` では ICO を扱わない）。確かめたやり方:

  ```powershell
  $b = [IO.File]::ReadAllBytes('ghost/master/icon.ico')
  $n = [BitConverter]::ToUInt16($b, 4)
  for ($i = 0; $i -lt $n; $i++) {
      $e = 6 + 16 * $i
      if ($b[$e] -eq 0) {   # 幅 0 は 256px
          $size = [BitConverter]::ToUInt32($b, $e + 8)
          $off = [BitConverter]::ToUInt32($b, $e + 12)
          if ($b[$off] -eq 0x89 -and $b[$off + 1] -eq 0x50) {   # PNG の署名
              [IO.File]::WriteAllBytes('.ukagaka/icon.png', $b[$off..($off + $size - 1)])
          }
      }
  }
  ```

  256px が BMP 形式の ICO なら、この方法は使えない。
- `preview/` は、シェルの立ち絵（`surface0.png` など）を複製するのが手早い。シェルのライセンスが許すかは、先に確かめる（`GHOST.md`）。立ち絵を作り直したら、複製も入れ替える。
- 仕様ページのサンプルには `homeurl` の行もある。表の項目には定義がないが、UUID の元になる値として出てくる（下の「UUID」）。ゴーストが持つ `homeurl`（ネットワーク更新の URL）をそのまま写すとよい。
- 項目の意味や値が確かでないときは、推測で書かず、仕様ページ（https://ukatech.shillest.net/metainfo-standard/ ）を読む。

## `.ukagaka/links/`

任意。規格で決まっているのは次の 2 つ。どちらも、書き方は 2 通り。

| ファイル | 使うとき |
|---|---|
| `mirror_repo.txt` | ゴーストのファイルがこのリポジトリでは更新されず、ミラーのリポジトリがあるとき。GitHub リポジトリの URL |
| `nar_release_repo.txt` | nar がこのリポジトリでリリースされず、別のリポジトリでリリースされるとき。GitHub リポジトリの URL |

- 単純: URL を 1 行だけ書く。
- 複雑: UTF-8、`//` でコメントを書ける。`link,<URL>` が必須。`nar_file_name,<nar のファイル名>` は任意（リリースのリポジトリでの nar の名前を Web アプリに伝える）。
- 規格にないファイルは、ファイル名に Web アプリの名前か略称を含める（例: `GCS_link.txt`）。

`.ukagaka/infos/` は、Web アプリ向けの追加情報を置く txt の置き場。形式は Web アプリごとに決まるので、頼まれたときだけ、そのアプリの仕様を調べる。

## ゴーストの `descript.txt` に書き足す

ゴーストの `ghost/master/descript.txt` に、次のどちらか（両方でもよい）を書くことが推奨されている。アプリが、ゴーストから metainfo フォルダにたどり着けるようになる。

```
metainfo,https://raw.githubusercontent.com/<owner>/<repo>/<branch>/.ukagaka/
githubrepo,https://github.com/<owner>/<repo>
```

- `metainfo` は metainfo フォルダの URL、`githubrepo` は GitHub プロジェクトの URL。効果は同じ。
- `ghost/master/descript.txt` は、ゴーストの本体の設定なので、**書き足す前に作者に確かめる**。書き足したら `scripts/check-dic.ps1` を通す（`SKILL.md` の「作業のルール」1）。文字コードと改行は今のままにする。
- metainfo を持たない既存のゴーストに、あとから metainfo と UUID を付けるときも、この書き足しで足りる。
- 既定ブランチが `master` でないリポジトリでは、`githubrepo` だけだと SSP が計算する UUID と合わない。`metainfo` も書く（上の「metainfo フォルダの置き場所」）。
- ゴーストの `descript.txt` に `homeurl` が無いときは、UUID は `metainfo` の URL から決まる（`homeurl` は metainfo が無いときにだけ使われる）。

## UUID

同じゴーストの別のバージョンや別のブランチを区別するための値。**metainfo の URL から決まる。**

1. `uuidvalue` を決める: metainfo フォルダの URL（なければ `homeurl`、それもなければゴーストの名前）。
2. `.ukagaka/descript.txt` に `uuid_base` があれば、`uuidvalue` の後ろに**区切りなしでつなぐ**。
3. `uuidvalue` を UTF-8 にして MD5 を取り、**そのバイト列**（16 進文字列ではない）を base64 にしたものが `uuid`。

公式の生成ツール（https://ukatech.github.io/metainfo-standard/uuid-genner/ 。入力欄は metainfo の URL（または homeurl か名前）と `uuid_base`）と同じ計算になる。作者がブラウザで使ってもよいし、PowerShell で計算してもよい（計算したら、公式ツールの結果とも照らすとよい）。

```powershell
$value = 'https://raw.githubusercontent.com/<owner>/<repo>/<branch>/.ukagaka/' + ''   # 後ろに uuid_base をつなぐ
$md5 = [System.Security.Cryptography.MD5]::Create()
[Convert]::ToBase64String($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($value)))
```

- **URL の文字が 1 つ違えば UUID も変わる。** 最後の `/` の有無、ブランチ名（`master` か `main` か）を、ゴーストの `descript.txt` の `metainfo` と合わせる。
- ローカルの完全性のため、metainfo の URL を `ghost/master/descript.txt` の `metainfo`（または `homeurl`）に書き、metainfo に `uuid_base` があれば、ゴーストの `descript.txt` にも `uuid_base` を書く。
- **他のゴーストの metainfo や UUID を写さない。** テンプレートから独立させるときは、`.ukagaka/` も、`uuid` も、`metainfo` の URL も、自分のものに変える（`references/standalone.md`）。URL を持たないゴーストは、同じ名前の metainfo を持つゴーストと同一とはみなされない。

## 手順

1. 作者に確かめる（推測で決めない）。
   - ゴーストを公開する場所（GitHub のリポジトリの URL、デフォルトブランチの名前）。
   - 作者名、作者の URL、対応する言語。名前、キャラクター名、`homeurl` は、`ghost/master/descript.txt` と `GHOST.md` から読み取れる。
   - nar に `.ukagaka/` を入れるか（決まらなければ今のまま）。
   - プレビュー画像とアイコンの扱い。シェルの画像を使うなら、`GHOST.md` のシェルのライセンスを確かめる（改変や再配布を禁じているシェルがある。`SKILL.md` の「作業のルール」8）。画像は、作者が用意したもの、または、作者が了承した SSP のスクリーンショット（`scripts/dump-surface.ps1`）を使う。**他のゴーストの画像を持ち込まない。**
2. `.ukagaka/descript.txt` を作り、UUID を計算して入れる。`preview/`、`icon.png`、`links/` は、作者が望むものだけ作る。
3. `ghost/master/descript.txt` に `metainfo`（と `githubrepo`）を書き足す。書く前に作者に見せる。
4. `scripts/check.ps1` を通す。`.narignore` を変えたときは、`scripts/build-nar.ps1 -ListOnly` で、`.ukagaka/` が思ったとおり入る・外れるかを確かめる。
5. GitHub のリポジトリには、Topics（ゴーストなら `ukagaka`、`ukagaka-ghost`、`sirefaso`、`sosiremi`）を付けることを勧める。「GitHub の Topics」のとおり、変更は作者に任せる。
6. コミットしても、push は作者が望んだときだけ。metainfo の URL は、push してデフォルトブランチに入る（Pages などのデプロイで配るなら、デプロイが終わる）まで読めないことを伝える。
7. push のあと、デプロイを待って、`.ukagaka/descript.txt` と `preview/sakura.png` の URL が実際に読めるか確かめる（`curl -sI <URL>` で 200 か）。デプロイ経由のときは、ここで初めて確かめられる。

## 関連

- ゴーストの公開: `references/workflows/build-nar.md`、`references/workflows/ci.md`
- テンプレートから独立させる: `references/workflows/new-ghost.md`、`references/standalone.md`
