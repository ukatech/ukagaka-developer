# GitHub Pages でネットワーク更新と nar を配る

## 使うとき

作者が「GitHub Pages で配りたい」「ネットワーク更新を GitHub で自動にしたい」「homeurl を移したい」「配布先を変えたい」「更新ファイルを自動で出したい」と言ったとき。`references/workflows/ci.md` の「nar の自動リリース」は nar だけを Releases に置く簡単な形で、こちらは、**nar と更新ファイル一式（`updates2.dau`、`updates.txt`、そこに載せたファイル）を Pages に出し、`homeurl` をその Pages に向ける**形。

**作者にはっきり頼まれたときだけ行う。** リポジトリの設定（Pages）、`homeurl` の変更、push は作者の確認を取ってから。`homeurl` は利用者の手元のゴーストが更新を取りに行く先なので、間違えると更新が届かなくなる。

## 仕組み

1. push → `auto check`（`auto_check.yml`。辞書チェック）が通る → `auto deploy`（`auto_deploy.yml`）が始まる。
2. `auto deploy` は、スキルを clone して `scripts/build-site.ps1` を動かし、`build/site/` に次を作る。
   - `<install.txt の directory>.nar`
   - `updates2.dau`、`updates.txt`（`.updateignore` が除外しないファイルの一覧。MD5、サイズ、日付）と、載せたファイル
   - `install.txt` がバルーンを同梱している（`balloon.directory`）ときは、バルーンごとのフォルダに、そのバルーンの `updates2.dau` と `updates.txt` とファイル
   - `.ukagaka/`（metainfo。あれば）、`site/`（紹介ページ。あれば）、`.nojekyll`、`index.html`
3. 出力を Pages に出し、同じ nar を Releases（タグ `latest`。常に 1 つだけ）にも置く。nar の URL は `https://github.com/<owner>/<repo>/releases/latest/download/<名前>.nar` で変わらない。

`build-site.ps1` は、git が追跡しているファイル（submodule を含む）だけを使う。追跡していないファイルは載らない。SSP は要らない。ローカルでは `scripts/build-site.ps1 -ListOnly` で一覧を、`scripts/build-site.ps1`（出力は `build/site/`。`.narignore` の開発用ブロックが `build/` を除外する）でファイルを作って確かめられる。

## 手順

1. **前提を確かめる。** ゴーストが GitHub のリポジトリにあり、`.github/workflows/auto_check.yml` がある（無ければ `scripts/init-ghost.ps1 -Workflow`）。`install.txt` に `directory` がある。
2. **ワークフローを作る。** `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/init-ghost.ps1 -Deploy`（`.github/workflows/auto_deploy.yml` が無いときだけ作る。元は `templates/github/auto_deploy.yml`）。ワークフローの名前は `auto check` に続けて動くよう、`auto_check.yml` の `name` と同じにしてある。ブランチが `main` / `master` 以外なら、`branches` を直す。
3. **配布先の URL を決める。** 既定は `https://<owner>.github.io/<repo>/`。自分のドメインを Pages に向けているなら、そちら。**URL は後から変えにくい**（下の「homeurl を移す」）。metainfo も同じ URL の下に置くなら（`<URL>.ukagaka/`）、metainfo の UUID も URL から決まる（`references/workflows/metainfo.md`）。
4. **`homeurl` を新しい URL にする。** 次のすべてを、`https://.../`（末尾の `/`）の形でそろえる。
   - ゴーストの `ghost/master/descript.txt` の `homeurl`
   - 同梱のバルーンの `descript.txt` の `homeurl`（`<URL>/<バルーンのフォルダ名>/`）
   - SHIORI が返す `homeurl` の resource（YAYA / 里々 / 華和梨で書き方が違う。`GHOST.md` に場所が書いてある。resource は `homeurl` を返すエントリ。ゴーストの起動中はこちらが優先され、エクスプローラからの更新などでは `descript.txt` の値が使われるので、両方そろえる）
5. **`.narignore` と `.updateignore` を整える。**
   - nar にも更新ファイルにも入れないもの: `/site/`（紹介ページ）、`/.ukagaka/`（metainfo。入れてもよい）、`/build/`（開発用ブロックにある）、`updates2.dau`、`updates.txt`（テンプレートの `.narignore` にある）。
   - **バルーンのフォルダは `.updateignore` で除外する**（例: `/<バルーンのフォルダ名>/`）。ゴーストの更新ファイルに入っていると、`build-site.ps1` が止まる。バルーンは自分の更新ファイルを持つ。
   - `.narignore` と `.updateignore` 自身は配布しない。以前の配布に入っていたなら、`delete.txt` に足して、利用者の手元から消す（`delete.txt` は更新で取得され、書かれたファイルが消される。仕様は https://ukatech.shillest.net/ukadoc-spec/dev_update.html ）。
   - 確かめる: `scripts/build-site.ps1 -ListOnly`（`only in nar` / `only in update files` に意図しないものが無いか）。
6. **`.gitignore` に `updates2.dau`、`updates.txt`、`*.nar`、`/build/` を足す**（生成物をコミットしない。旧 homeurl 用に凍結したものは `git add -f`）。
7. **作者に、リポジトリの設定を頼む。** Settings > Pages > Build and deployment > Source を **GitHub Actions** にする（エージェントが `gh api` で行うときは、先に確認を取る）。
8. 作者が了承したら commit、push。`auto check` → `auto deploy` が通ることを、Actions の画面か `gh run list` で確かめる。通ったら、`<URL>updates2.dau` と nar が取れることを確かめる（`curl -I`）。

- **`actions/upload-pages-artifact` は v3 のまま**。v4 は、先頭が `.` のフォルダ（`.ukagaka/`）を隠しファイルとして除外する。Dependabot などで上がらないよう、ワークフローに注釈がある。
- Pages の更新は、`auto check` が成功した push だけで走る。手動なら Actions の `auto deploy` を `Run workflow`（`workflow_dispatch`）。
- `windows-latest` で動く `auto_check.yml` と違い、`auto_deploy.yml` は `ubuntu-latest`。`build-site.ps1` は git と PowerShell（pwsh）しか要らない。
- スキルは `main` の最新を取る（`ci.md` と同じ。固定する方法も同じ）。

## homeurl を移す（すでに別の場所で配っているとき）

これまで `homeurl` が別の場所（例: `raw.githubusercontent.com`）のゴーストを Pages に移すときの手順。**旧 homeurl を使っている利用者は、新しい `homeurl` を知らない。** 旧 homeurl から更新できる状態を、利用者が新しい版に移るまで残す。

1. 上の手順で、新しい URL への `homeurl` の変更を含む版を作る。
2. **旧 homeurl に置いてある `updates2.dau` / `updates.txt` を、凍結する**。旧 homeurl から更新した利用者の手元に、新しい `homeurl` を運ぶだけの内容にする。
   - 載せるのは、新しい `homeurl` を持つファイル（`descript.txt`、SHIORI の `homeurl` を書いたファイル。バルーンなら、バルーンの `descript.txt`）と、`delete.txt` だけ。
   - 作る: `scripts/build-site.ps1 -OutDir <一時フォルダ> -OnlyUpdateFiles delete.txt,ghost/master/descript.txt,<homeurl を書いたファイル>`。バルーンは `-OnlyUpdateFiles <フォルダ名>/descript.txt -NamePrefix <フォルダ名>`（一覧の名前からフォルダ名を除く）。できた `updates2.dau` と `updates.txt` を、旧 homeurl が配っている場所（`raw.githubusercontent.com` なら、リポジトリのルート。バルーンはそのフォルダ）に置き、`git add -f` でコミットする（`.gitignore` が除外しているため）。
   - **載せたファイルを、利用者が移るまで変えない**。一覧の MD5 と中身が合わなくなり、旧 homeurl の利用者が更新に失敗する。載せたファイルを後で変える必要が出たら、凍結版を作り直す。
3. 凍結した `updates2.dau` / `updates.txt` は、`.narignore` が除外しているので、nar と新しい更新ファイルには入らない（`build-site.ps1` は、バルーンのフォルダの中の `updates2.dau` / `updates.txt` も除外する）。
4. 旧 homeurl の利用者が十分に新しい版へ移ったら、凍結版を外してよい（外すときは作者に確かめる。取り残された利用者は、更新を手で取り直すことになる）。

## 関連

- 自動チェックと nar だけのリリース: `references/workflows/ci.md`
- nar と更新ファイルをローカルで作る（SSP）: `references/workflows/build-nar.md`
- metainfo（`.ukagaka/`）: `references/workflows/metainfo.md`
- ネットワーク更新の仕様: https://ukatech.shillest.net/ukadoc-spec/dev_update.html
