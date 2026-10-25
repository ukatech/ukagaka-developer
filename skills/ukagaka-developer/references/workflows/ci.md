# GitHub Actions（辞書チェックと自動リリース）

ゴーストを GitHub で管理しているときの、push ごとの辞書チェックと、nar の自動リリースの作り方。スキルはゴーストのフォルダに入っていないので、ワークフローが**スキルのリポジトリを取得して**、そのスクリプトを実行する。

## 辞書チェック（`auto_check.yml`）

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/init-ghost.ps1 -Workflow` で、`.github/workflows/auto_check.yml`（元は `templates/github/auto_check.yml`）ができる（無いときだけ）。やることは次のとおり。

1. `actions/checkout`（YAYA のシステム辞書は submodule なので `submodules: recursive`）。
2. `git clone --depth 1 https://github.com/ukatech/ukagaka-developer.git $RUNNER_TEMP/ukagaka-developer`。
3. `scripts/check-dic.ps1 -Ci -GhostRoot $GITHUB_WORKSPACE`。`-Ci` で、エラーが GitHub Actions の注釈（アノテーション）になる。

- **Windows のランナー（`windows-latest`）で動かす**。tamacs.exe を、ランナーに入っている .NET Framework の `csc.exe` でビルドして、`yaya.dll` / `satori.dll`（32 ビット）を読み込むため。
- スキルは `main` の最新を取るので、スキルが更新されると、ゴーストを変えなくてもチェックの内容が変わる。固定したいときは、clone に `--branch <タグまたはブランチ>` を付ける（今のところ、リポジトリにタグは無いので、コミットを固定するなら `git clone` のあとに `git -C ... checkout <SHA>`）。
- `scripts/check-dic.ps1` は GitHub の API を使わない。`update-shiori.ps1` などを CI で動かすときは、API の回数制限を避けるため `GITHUB_TOKEN` を環境変数に渡す（スクリプトが使う）。

## nar の自動リリース

旧キットの `auto_release.yml` は、push のたびに**既存のリリースとタグをすべて消して**作り直す作りだった。残したいリリースがあるゴーストでは、そのまま使わない。作り直すなら、nar を作る手順を次のようにする。

```yaml
      - name: get ukagaka-developer
        shell: pwsh
        run: git clone --depth 1 https://github.com/ukatech/ukagaka-developer.git "$env:RUNNER_TEMP/ukagaka-developer"
      - name: build nar
        # On GitHub Actions the nar is written by the script itself (git ls-files), not by SSP. .narignore decides what is left out.
        shell: pwsh
        run: '& "$env:RUNNER_TEMP/ukagaka-developer/skills/ukagaka-developer/scripts/build-nar.ps1" -OutFile $env:NAR_NAME -GhostRoot $env:GITHUB_WORKSPACE'
```

- GitHub Actions（`GITHUB_ACTIONS=true`）では、SSP が無いので、`build-nar.ps1` は自分で nar を作る（git が追跡しているファイルだけ。ネットワーク更新ファイル `updates2.dau` は作れない）。ubuntu のランナーでも動く（`pwsh`）。
- 開発用のファイル（`GHOST.md`、`AGENTS.md`、`.claude/` など）は、`.narignore` の開発用ブロックが除外する。ブロックが無ければ `scripts/init-ghost.ps1 -NarignoreDevBlock`。
- 旧キットの「キットあり版の nar」（`auto_release_devkit.yaml`）は、スキルに移したら要らない。消す。

## 旧キットのワークフローを移す

旧キットの `tools/check-dic.ps1 -Ci` や `tools/build-nar.ps1` を呼ぶワークフローは、`tools/` が無くなると失敗する。`scripts/migrate-from-devkit.ps1` が `auto_check.yml` を替え、それ以外のワークフローは `STALE` として知らせる。上の例に沿って手で直す。
