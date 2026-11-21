# Pages 配布（build-site.ps1 と auto_deploy.yml）

`scripts/build-site.ps1` と `templates/github/auto_deploy.yml` の作りと、そうした理由。使い方は `references/workflows/pages.md`。

- **由来**: ponyaduma と claudia が、それぞれゴーストの中に持っていた `.github/scripts/build-site.ps1`（350 行ほど。SSP と同じ除外規則の自前実装を含む）を、スキルの共通部品に寄せたもの。ponyaduma の `build-site.ps1` と出力（ファイルの一覧とサイズ）が一致することを確かめた。ゴーストごとに 350 行をコピーすると、除外規則の修正が届かないので、ワークフローがスキルを clone して使う（`auto_check.yml` と同じ）。
- **除外規則は `lib/ignore.ps1`**、nar は `build-nar.ps1 -Builtin`（子プロセスで動かす。git が追跡しているファイルだけ）と同じ選び方。更新ファイルは、同じ追跡ファイルから `.updateignore` で選ぶ。SSP の `--offline-tool updatedata` と同じ書式（`updates2.dau`: 項目の区切りはバイト値 1、`path・MD5・size=・date=（UTC）`、先頭の項目に `charset=UTF-8`。`updates.txt`: 先頭に `charset,UTF-8`、各行は `file,` + 同じ内容）。SSP のものと日付の取り方が同じかは確かめていない（ファイルの更新日時を UTC で書く）。Actions の checkout では更新日時が checkout の時刻になるので、中身が同じでも日付は毎回変わる（SSP がこの日付をどう使うかは確かめていない）。
- **バルーン**: `install.txt` の `balloon*.directory` が、更新ファイルを別に持つ。ゴーストの `.updateignore` がバルーンのフォルダを除外していなければ、`build-site.ps1` は止まる（ゴーストの更新に入ると、バルーンがゴーストの中のフォルダに置かれてしまうため）。バルーンのフォルダの中の `updates2.dau` / `updates.txt` は、旧 homeurl 用の凍結版なので、バルーンのファイルに数えない。
- **凍結版**（`-OnlyUpdateFiles`、`-NamePrefix`）: 旧 homeurl の利用者に新しい `homeurl` を運ぶだけの更新ファイルを、同じ書式で作る。ponyaduma の凍結版と同じバイト列になることを確かめた（日付は元のファイルの更新日時）。
- **`upload-pages-artifact` は v3**: v4 は先頭が `.` のフォルダ（`.ukagaka/`）を除外する。v5 以降は確かめていない。上げるときは、`.ukagaka/` が公開されるかを確かめる。
- **Releases**: タグ `latest` を毎回消して作り直す。nar の URL（`releases/latest/download/<名前>.nar`）を変えないため。旧キットの `auto_release.yml` は、すべてのリリースを消していたので、そうではなく `latest` だけを扱う。
- `workflow_run` は既定ブランチのワークフローしか起動しない。`auto_check.yml` の `name`（`auto check`）と、`auto_deploy.yml` の `workflows:` が一致していること。
