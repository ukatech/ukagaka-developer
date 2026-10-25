# 旧 AI 開発キットからの移行

konnoyayame（YAYA）と POST_and_KOMAINU（里々）の「AI 開発キット」は、`tools/`、`docs/agents/`、`AGENTS.md`、`CLAUDE.md`、`DEVKIT-GUIDE.md`、`.claude/`、`.mcp.json`、`.github/workflows/auto_check.yml` をゴーストの中にコピーする方式だった。このスキルは、同じ機能を**ゴーストの外**に置く。ゴーストに残すのは、ゴーストのものである `GHOST.md` と、短い `AGENTS.md` / `CLAUDE.md` だけ。

## 使うとき

作者が「旧キットを外して」「tools フォルダを片付けたい」「開発キットからスキルに移したい」と言ったとき。`scripts/doctor.ps1` の `old development kit` が missing のとき（`tools/devkit.json` が残っている）にも、作者に提案する。

**旧キットが残っていると、スキルと旧キットが 2 組の指示（`AGENTS.md` と `SKILL.md`）と 2 組のスクリプトをエージェントに見せる。移行する前に、旧キットの `tools/update-devkit.ps1` を実行しない**（旧キットを更新するだけで、移行にならない）。

## 何が起こるか

`scripts/migrate-from-devkit.ps1` は、旧キットが `tools/devkit.json`（キットのファイルの一覧）と `tools/devkit.lock.json`（入れたときの内容のハッシュ）に記録した情報を使って、作者が変えていないファイルだけを消す。

| 対象 | 動作 |
|---|---|
| キットが入れて、変えていないファイル（`tools/`、`docs/agents/`、`DEVKIT-GUIDE.md`、`.claude/agents/`、`.mcp.json` など） | 消す |
| `AGENTS.md`、`CLAUDE.md`（変えていないもの） | 短いスタブに置き換える（`GHOST.md` を読むこと、スキルを使うこと） |
| `.github/workflows/auto_check.yml`（変えていないもの） | スキルを取得して辞書チェックする新しいワークフローに置き換える |
| `.claude/settings.json` | 変えていなければ消す。作者が変えていれば、旧キットの SessionStart hook と `tools/*.ps1` の許可だけを取り除く |
| `.narignore` | `include:tools/devkit.narignore` の行を、開発用ファイルの除外ブロックに置き換える |
| `tools/local.json` | SSP のパスを、ホームフォルダの `local.json` に写す |
| 作者が変えたキットのファイル、`tools/` の中の作者のスクリプト | **残して知らせる**（`KEPT`） |
| `.github/workflows/` の、`tools/*.ps1` を呼ぶほかのワークフロー（`auto_release.yml` など）、キット付きの nar を作る `auto_release_devkit.yaml` | **変えず、知らせる**（`STALE`） |
| `*.devkit-new`、`*.yaya-dic-new` | 変えず、知らせる（`LEFTOVER`） |
| `GHOST.md`、辞書、シェル、`README.md` | 一切触らない |

消す・書き換えるファイルは、先に**ゴーストの外**（ホームフォルダの `backups/<ゴースト名>-<日時>/`）に退避される。git の無い（nar をインストールした）フォルダでも元に戻せる。

## 手順

1. 作者に何が起こるかを伝え、了承を得る。作業の前に、git の作業コピーなら未コミットの変更がないか確かめる（あれば、先にコミットか退避を勧める）。
2. 計画を見る（何も変更しない）: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/migrate-from-devkit.ps1`
   - `delete`、`replace with a short stub`、`edit`、`kept by hand`、`workflows that still call tools/*.ps1` に分かれて出る。作者に要点を伝える。
   - `DEVKIT-MAINTAINING.md` があるフォルダ（旧キットを配っているリポジトリそのもの）では、止まる。そのリポジトリがキットをやめるときだけ、`-Force` で進める。
3. 了承を得てから実行する: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/migrate-from-devkit.ps1 -Apply`
   - 終了コード 2 は「済んだが、手作業が残っている」。出力の `KEPT` / `STALE` / `LEFTOVER` を片付ける。
   - 作者が変えたキットのファイルも消したいときだけ `-Force`（退避される）。
4. 残ったものを片付ける。
   - **`AGENTS.md` を作者が変えていたとき（`KEPT`）**: 中身は旧キットの指示（`tools/*.ps1` を指している）が混ざっている。作者が足した決まりだけを `GHOST.md` の「独自のルール」に移し、`AGENTS.md` を `templates/AGENTS.md` の内容に置き換える。`CLAUDE.md` も `templates/CLAUDE.md`（`@AGENTS.md` と `@GHOST.md` の 2 行）にする。
   - **`tools/` の中の作者のスクリプト**: そのまま残してよい。旧キットの `tools/lib/common.ps1` を読み込んでいるものは動かなくなるので、作者と相談する。
   - **ワークフロー（`STALE`）**: `references/workflows/ci.md`。旧キットの `tools/build-nar.ps1` を呼んでいたリリースのワークフローを、スキルのスクリプトに替える。`auto_release_devkit.yaml`（キットあり版の nar）は、キットが無くなるので消す。
   - **`*.devkit-new`**: 旧キットの更新でできた、マージ待ちの新しい版。旧キットは外すので、要るところだけ手元のファイルに取り込んで、消す。
5. スキルを使える状態にする。
   - Claude Code: `claude plugin marketplace add ukatech/ukagaka-developer` のあと `claude plugin install ukagaka-developer --scope project`（そのゴーストだけ）か `--scope user`。入れたら Claude Code を終了して開き直す。
   - Codex、Antigravity など: スキルのフォルダ（`skills/ukagaka-developer/`）を `.agents/skills/ukagaka-developer/` にコピーする（`README.md`）。コピーした場所は `.narignore` の開発用ブロックが nar から除外する。
6. 確かめる。
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`: `old development kit` が ok になり、`required` がそろっている。
   - `scripts/check.ps1`: 移行の前と同じ結果になる。
   - `scripts/build-nar.ps1 -ListOnly`: 開発用のファイル（`GHOST.md`、`AGENTS.md`、`.claude/`、`.agents/` など）が入っていない。`note: ... development file(s) are included` と出たら、`scripts/init-ghost.ps1 -NarignoreDevBlock`。
7. 変更を見せる（`git status`）。コミットは、作者に聞いてから行う（勝手にコミットしない）。

## 元に戻す

退避先（実行の最後に表示される）の `migration-report.txt` に、何をしたかが書かれている。退避したファイルを元のパスに戻せば、旧キットの状態に戻る。

## 関連

- スキルの導入と更新: `README.md`、`references/workflows/update-skill.md`
- ゴーストのフォルダの構成: `references/layout.md`
