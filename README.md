# ukagaka-developer

伺か（ukagaka）のゴーストを、AI と一緒に作る・直す・動かして確かめる・配布するための**スキル**です。対応する SHIORI は **YAYA** と **里々（SATORI）**。

日本語で「トークを書いて」「エラーを直して」「SSP で動かして見せて」と頼むだけで、AI が次のことをします。

| | |
|---|---|
| 辞書を書く | トーク、ランダムトーク、メニュー、マウス反応など。YAYA と里々、それぞれの書き方の要点と、よくある失敗を踏まえて書く |
| 確かめる | 辞書を SSP なしで実際に読み込ませてエラーを探す（tamacs）。里々は辞書を実行せずに調べる静的検査（ShioriLint）、YAYA は未定義・未使用の名前探し（lint）もできる。書いたトークや関数をその場で展開し、実行時のエラーも見る |
| 動かして見せる | 試験用の SSP（作者の SSP とは別）を立てて、トークを再生し、吹き出しの画像で折り返しまで確かめる |
| シェルを直す | surfaces.txt の検査、サーフェスの合成画像の確認、32bit PNG への編集 |
| 配布する | nar とネットワーク更新ファイルを作る。GitHub Actions のチェック |
| 更新する | `yaya.dll` とシステム辞書、`satori.dll` を最新にする |

シェル（絵）は既にあるものとして扱います。**絵は描けません。**

以前の「AI 開発キット」（konnoyayame / POST_and_KOMAINU の `tools/`、`AGENTS.md`、`docs/agents/`）の後継です。キットのようにゴーストのフォルダへコピーせず、ゴーストの外に置くので、ゴーストを汚さず、更新も 1 か所で済みます。旧キットが入っているゴーストからの移行手順もあります（下の「旧 AI 開発キットからの移行」）。

## 必要なもの

| | |
|---|---|
| AI と会話できる開発道具 | Claude Code、Codex、Antigravity など |
| ゴースト | `ghost/master/descript.txt` と、`yaya.dll`（YAYA）か `satori.dll`（里々）があるもの |
| Windows | チェックや SSP の操作を行うスクリプトが PowerShell で書かれています。Windows PowerShell 5.1 と PowerShell 7 の両方で動きます |
| SSP 2.9.08 以降（推奨） | 動作確認、シェルの検査、nar の作成に使います。無くても辞書のチェックはできます |

## インストール

### Claude Code の場合（プラグイン）

ゴーストのフォルダ（`ghost/` と `shell/` が並んでいる階層。`master` の中ではありません）で Claude Code を開いて、

```
claude plugin marketplace add ukatech/ukagaka-developer
claude plugin install ukagaka-developer --scope project
```

入れたら、**Claude Code をいったん終了して、開き直します**（入れた直後のセッションには読み込まれません）。`claude plugin list` に `ukagaka-developer` が出れば成功です。

| | |
|---|---|
| `--scope project` | いま開いているゴーストだけ（`.claude/settings.json` に記録され、リポジトリで共有される） |
| `--scope user` | どのゴーストでも |
| `claude plugin uninstall ukagaka-developer --scope project` | 消す。入れたときと同じ `--scope` を渡す |
| `claude plugin marketplace remove ukagaka-developer` | 配布元の登録も消す |

プラグインには、スキルのほか、仕様調査用のサブエージェント（`ukagaka-researcher`）と、仕様検索 MCP（`ukagaka-doc`。初回に承認を求められます）が入っています。

Claude Code に頼んでも入れられます。

```
github の ukatech/ukagaka-developer を、このプロジェクトに入れて
```

### Codex / Antigravity など、フォルダのコピーで入れる場合

このページの **Code** → **Download ZIP** で落として展開し、中の `skills/ukagaka-developer/` を、ゴーストのフォルダの `.agents/skills/` に置きます。

```
ゴースト\
  .agents\
    skills\
      ukagaka-developer\
        SKILL.md
        scripts\
        references\
        templates\
  ghost\
  shell\
```

`.agents` は Codex と Antigravity で共通です。どのゴーストでも使うなら、置き場所が変わります。

| | |
|---|---|
| Codex | `%USERPROFILE%\.agents\skills\` |
| Antigravity | `%USERPROFILE%\.gemini\antigravity\skills\` |

置いたら、**いったん終了して開き直します**。開き直してから、ゴーストのことを何か頼んでみてください。`references\` を読みにいく様子が見えれば、読み込まれています。

仕様検索 MCP（`https://ssp.shillest.net/ukadoc/mcp`、HTTP / Streamable HTTP）と調査用のエージェントは、プラグインでだけ自動で入ります。ほかのツールでは、使うツールの設定に登録してください（`agents/ukagaka-researcher.md` は、サブエージェントの定義として使えます）。

ゴーストのフォルダの `.agents/` や `.claude/`、`GHOST.md` などの開発用のファイルと、`.github/`、`.gitignore`、`.editorconfig` などのリポジトリ用のファイルは、nar に入りません（`.narignore` の開発用ブロックが除外します。下の「ゴーストの側に残るもの」）。

## 使いかた

日本語でそのまま頼みます。

```
セットアップして
マウスでなでたときの反応を 3 つ足して
エラーが出ていないか見て
SSP で動かして見せて
nar を作って
yaya.dll を更新して
```

必要になった資料とスクリプトを AI が自分で読んで、使います。何ができるのかは、「できる？」と聞けば答えます。

## ゴーストの側に残るもの

スキルはゴーストのフォルダに何もコピーしません。ゴーストに置くのは、ゴーストのものである次のファイルだけです。

| ファイル | 内容 |
|---|---|
| `GHOST.md` | そのゴーストに固有の情報（キャラクター、サーフェス、ライセンス、辞書の構成、トークの書き方）。AI が作業の前に読む。「セットアップして」で、辞書とシェルから下書きしてもらえる |
| `AGENTS.md`、`CLAUDE.md` | `GHOST.md` を読むこと、スキルを使うことだけを書いた短い案内 |
| `.narignore` ほか | nar から開発用のファイルを除く設定 |
| `.github/workflows/auto_check.yml` | GitHub で push ごとに辞書チェック（任意） |

ビルドした tamacs.exe と、SSP の場所の設定（`local.json`）は、スキルの更新で消えないよう、ホームフォルダ（`%LOCALAPPDATA%\ukagaka-developer`。環境変数 `UKADEV_HOME` で変えられます）に置かれます。

## 許可の確認を減らす

Claude Code は、スクリプトを実行するたびに許可を確認します。このスキルは、読み取り専用のスクリプト（`doctor`、`check`、`check-dic`、`check-shell`、`lint`、`shiori`、`dump-surface`、`ssp-log`、`image info` / `image view`）を、`SKILL.md` の `allowed-tools` で許可していますが、**許可されるのは、スキルを使っているターンの間だけ**です（次のメッセージで切れます）。毎回の確認が煩わしいときは、次のどちらかを使います。

- Claude Code に `/fewer-permission-prompts` を実行させる（よく使う読み取りだけのコマンドを、`.claude/settings.json` の許可リストに足してくれます）。
- `.claude/settings.json`（そのゴーストだけ）か `~/.claude/settings.json`（すべて）の `permissions.allow` に、規則を足す。プラグインのフォルダはバージョンごとに変わるので、`*` でパスを受けます。

```json
{
  "permissions": {
    "allow": [
      "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *ukagaka-developer*scripts/doctor.ps1*)",
      "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *ukagaka-developer*scripts/check.ps1*)",
      "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *ukagaka-developer*scripts/check-dic.ps1*)",
      "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *ukagaka-developer*scripts/check-shell.ps1*)",
      "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *ukagaka-developer*scripts/shiori.ps1*)",
      "PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File *ukagaka-developer*scripts/check-dic.ps1*)"
    ]
  }
}
```

`shiori.ps1` は、辞書の関数やトークを実際に実行します。ファイルの書き込み、外部プログラムの実行、SAORI の呼び出しをするものは、本当に動くので、許可に加えるかは、そのつもりで決めてください。旧 AI 開発キットは、`.claude/settings.json` で `tools/*.ps1` を許可していました。移行（下）でその許可は消えるので、必要ならここで足し直します。

## 更新

| 入れ方 | 更新 |
|---|---|
| Claude Code のプラグイン | `claude plugin marketplace update ukagaka-developer` のあと `claude plugin update ukagaka-developer`。マーケットプレイスの自動更新を有効にしていれば、起動後に自動で更新されます。更新したら Claude Code を再起動 |
| フォルダのコピー | AI に「スキルを更新して」と頼む（`scripts/update-skill.ps1`）。または ZIP を落とし直して置き換える |

このスキルには**バージョン番号がありません**。更新は GitHub の最新のコミットを追います。変更内容は、コミット履歴で見られます。`yaya.dll` や `satori.dll` の版は、スキルに書かれていません。「YAYA を更新して」「里々を更新して」で、そのときの最新リリースを取ります。

## 旧 AI 開発キットからの移行

konnoyayame や POST_and_KOMAINU から作ったゴーストには、`tools/`、`docs/agents/`、`AGENTS.md`、`DEVKIT-GUIDE.md` などの旧キットが入っています。このスキルと同時に置くと、AI に 2 組の指示が届いてしまうので、旧キットを取り除きます。

1. このスキルを入れる（上）。
2. AI に「旧キットを外して」と頼む。
3. または、手で: ゴーストのフォルダで、スキルの `scripts/migrate-from-devkit.ps1` を実行する。まず**計画だけ**が出ます。内容を見て、よければ `-Apply` を付けて実行します。

```
powershell -NoProfile -ExecutionPolicy Bypass -File <スキルのフォルダ>\scripts\migrate-from-devkit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File <スキルのフォルダ>\scripts\migrate-from-devkit.ps1 -Apply
```

- 旧キットが入れたまま変えていないファイルだけを消します。作者が変えたファイルは残して知らせます。
- 消す・書き換えるファイルは、先にゴーストの外（`%LOCALAPPDATA%\ukagaka-developer\backups\`）に退避します。git の無い（nar をインストールした）フォルダでも戻せます。
- `GHOST.md`、辞書、シェルには触りません。
- 旧キットの `.claude/settings.json` が許可していた `tools/*.ps1` の実行は、なくなります（上の「許可の確認を減らす」）。
- 詳しくは `skills/ukagaka-developer/references/workflows/migrate-from-devkit.md`。

## 里々で発展的な処理をするとき

選択肢やメニュー、一覧表示などの画面づくり、好感度のような仕組みが里々で作れるかの判断には、第三者のスキル [ukagaka-satori-helper](https://github.com/earlduant/ukagaka-satori-helper)（MIT License）が詳しく、併用できます。このスキルには同梱されていません。AI が必要と判断したときは、導入を提案します。

## 中身

```
.claude-plugin/        プラグインとマーケットプレイスの定義
.mcp.json              仕様検索 MCP（ukagaka-doc）
agents/                仕様調査用のサブエージェント
skills/ukagaka-developer/
  SKILL.md             最初に読まれるもの
  scripts/             実行するもの（共通: 直下と lib/、SHIORI 固有: shiori/yaya/ と shiori/satori/）
  references/          引く資料（workflows/、yaya/、satori/ と共通の資料）
  templates/           ゴーストに足す入門用ファイルの元
docs/maintaining/      このスキル自身を直す人のための資料
tests/                 リポジトリの検査（check-repo.ps1）
```

スキルを直す・育てる人は、`docs/maintaining/MAINTAINING.md` を読んでください。

## ライセンス

[Unlicense](LICENSE)（パブリックドメイン）。ゴーストの辞書やシェルのライセンスとは無関係です。同梱物に `yaya.dll` と `satori.dll` は含まれません（ゴーストに入っているものを使い、更新時に各リポジトリのリリースから取ります）。
