---
name: ukagaka-developer
description: 伺か（ukagaka）のゴーストを作る・直す。SHIORI は YAYA、里々（SATORI）、華和梨（KAWARI Phase 9。Phase 8 のゴーストも shiori.dll を 9 に差し替えて扱う）。辞書（トーク、ランダムトーク、メニュー、マウス反応など。華和梨は kawarirc.kis と、そこから読む辞書）を書く、シェル（サーフェス、画像）を直す、辞書やシェルのエラーを調べて直す、SSP で動かして試す、nar やネットワーク更新ファイルを作る、yaya.dll や satori.dll、華和梨の shiori.dll を更新する、旧 AI 開発キット（tools/ と AGENTS.md）から移行する、といったとき。ghost/master/descript.txt のあるフォルダが対象。さくらスクリプト、SHIORI イベント、SSP、SSTP、surfaces.txt の扱いも含む。
allowed-tools:
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/doctor.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/check.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/check-dic.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/check-shell.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/lint.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/shiori.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/dump-surface.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/ssp-log.ps1*)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/image.ps1 info *)'
  - 'Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/image.ps1 view *)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/doctor.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/check.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/check-dic.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/check-shell.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/lint.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/shiori.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/dump-surface.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/ssp-log.ps1*)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/image.ps1 info *)'
  - 'PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/image.ps1 view *)'
  - 'WebFetch(domain:ssp.shillest.net)'
  - 'WebFetch(domain:ukatech.shillest.net)'
  - 'WebFetch(domain:yaya-shiori.github.io)'
---

# ukagaka-developer

伺か（ukagaka）のゴーストを、AI と一緒に作る・直すためのスキル。対応する SHIORI は **YAYA**、**里々（SATORI）**、**華和梨（KAWARI）Phase 9**（Phase 8 の辞書はそのまま Phase 9 で動くので、`shiori.dll` を差し替えて扱う。Phase 7 以前は対象外）。作者（ユーザー）は創作に集中し、決まった作業（環境の準備、チェック、動作確認、nar の作成、SHIORI の更新）はこちらで引き受ける。

作者は、スキルの名前もコマンドも知らない。「〜して」という普通の言葉で頼まれる。何ができるかを聞かれたときや、準備を終えたときは、「〜と頼んでください」の形で例を示す。

## このスキルのフォルダ

この文書（`SKILL.md`）のあるフォルダを「スキルのフォルダ」と呼ぶ。以降の `scripts/`、`references/`、`templates/` は、すべてそこからの相対パス。

```
SKILL.md
scripts/       実行する。ゴースト（YAYA/里々/華和梨）に共通のものは直下、SHIORI 固有のものは shiori/yaya/、shiori/satori/、shiori/kawari/
references/    引く。必要な文書だけを読む（下の「こう頼まれたら」と「資料」）
  workflows/   作業ごとの手順書
  yaya/        YAYA の辞書の書き方、チェック、更新、コマンド
  satori/      里々の辞書の書き方、チェック、更新、コマンド
  kawari/      華和梨の辞書の書き方、チェック、更新、コマンド
templates/     ゴーストに足す入門用ファイル（GHOST.md など）の元
```

- スクリプトは `powershell -NoProfile -ExecutionPolicy Bypass -File <スキルのフォルダ>/scripts/<名前>.ps1 ...` で呼ぶ。Claude Code では `${CLAUDE_SKILL_DIR}/scripts/doctor.ps1` のように書ける（展開されないエージェントでは、スキルのフォルダのフルパスに読み替える）。**作業フォルダはゴーストのルート**（`ghost/` と `shell/` が並んでいるフォルダ）。別の場所からは `-GhostRoot <フォルダ>`。
- スキルのフォルダには**書き込まない**（プラグインの更新で置き換わる）。ビルドした tamacs.exe や SSP の場所の設定は、ホームフォルダ（`%LOCALAPPDATA%\ukagaka-developer`）に置かれる。ゴーストのフォルダにも、スクリプトは何も増やさない。

## 作業を始める前に

1. **ゴーストのルートの `GHOST.md` を読む。** ゴーストの名前、キャラクターと使えるサーフェス、ライセンス、辞書の構成、トークの書き方など、このゴースト固有の情報はそこにある。無い、または先頭に `<!-- devkit:ghost-template -->` が残っている（まだ書かれていない）ときは、`references/workflows/setup.md` に沿って、辞書とシェルを読んで下書きすることを作者に提案する。
2. **`scripts/doctor.ps1` を実行する**（何も変更しない）。ゴーストのルートと SHIORI（YAYA、里々、華和梨）、足りないもの、直し方が出る。`required` が足りなければ、ほかの作業の前に `references/workflows/setup.md` を提案する。
3. **SHIORI を確かめる。** doctor が表示する。以降、辞書を書く・直すときは、SHIORI に合わせて **`references/yaya/dictionary.md`、`references/satori/dictionary.md`、`references/kawari/dictionary.md` のどれかを先に読む**。3 つは、文法も、トークの書き方も、拾えるエラーも別物。華和梨で `KAWARI Phase 9` が missing なら、`shiori.dll` が Phase 8 以前なので、ほかの作業の前に `references/kawari/update.md` による更新を提案する。`UTF-8 dictionaries` が missing なら、辞書が Shift_JIS なので、編集の前に `references/kawari/dictionary.md` の「文字コード」を読む。
4. doctor の `old development kit` が missing なら、ゴーストに**旧 AI 開発キット**（`tools/`、`docs/agents/`、`DEVKIT-GUIDE.md` など）が残っている。このスキルと同時に使うと、エージェントに 2 組の指示が届いてしまうので、`references/workflows/migrate-from-devkit.md` による移行を提案する（作者の確認を取ってから）。

## こう頼まれたら

対応する手順書を**読んでから**作業する。

| 作者の言い方（例） | 読むもの |
|---|---|
| 「セットアップして」「始めたい」「足りないものを入れて」「GHOST.md を書いて」 | `references/workflows/setup.md` |
| 「チェックして」「エラーが出ていないか見て」「辞書のエラーを直して」「lint かけて」 | `references/workflows/check.md`（と、SHIORI の `check.md`） |
| 「トークを書いて」「ランダムトークを足して」「メニューを作って」「反応を直して」 | `references/yaya/dictionary.md`、`references/satori/dictionary.md`、`references/kawari/dictionary.md`（SHIORI に合わせて） |
| 「SSP で試して」「動かして見せて」「このトークを再生して」 | `references/workflows/try-in-ssp.md` |
| 「シェルの画像を直して」「画像を編集して」「表情のパーツを作って」「32bit PNG にして」 | `references/workflows/edit-shell-image.md` |
| 「nar を作って」「配布用のファイルを作って」「リリースしたい」「更新ファイルを作って」 | `references/workflows/build-nar.md`（GitHub Actions は `ci.md`） |
| 「YAYA を更新して」「yaya.dll を更新して」「システム辞書を更新して」「YAYA 6（600 系）にして」 | `references/yaya/update.md` |
| 「里々を更新して」「satori.dll を更新して」「里々のバージョンを教えて」 | `references/satori/update.md` |
| 「華和梨を更新して」「shiori.dll を更新して」「華和梨 9 にして」「華和梨のバージョンを教えて」 | `references/kawari/update.md` |
| 「辞書を UTF-8 にして」「Shift_JIS の辞書を直したい」（華和梨） | `references/kawari/dictionary.md` の「文字コード」 |
| 「SHIORI を最新にして」 | `references/workflows/update-shiori.md` |
| 「自分のゴーストを作りたい」「テンプレート（サンプル）から独立させたい」 | `references/workflows/new-ghost.md` |
| 「旧キットを外して」「tools フォルダを片付けたい」「開発キットからスキルに移したい」 | `references/workflows/migrate-from-devkit.md` |
| 「里々のログを見たい」「ログ受信ウインドウを開いて」 | `references/commands.md`（`scripts/log-window.ps1`） |
| 「スキルを更新して」「ukagaka-developer を最新にして」 | `references/workflows/update-skill.md` |

## 作業のルール

1. **辞書や `ghost/master/` の設定を変更したら、必ず `scripts/check-dic.ps1` を通す**（`scripts/check.ps1` は、シェルのチェックと `scripts/lint.ps1` も続けて行う。里々は Mc206-1 以降なら、`lint.ps1` が辞書を実行せずに書き方の誤りや飛び先・名前の書き間違いを全部探すので、`check-dic.ps1` が通った後に行う）。エラーが残ったゴーストは、YAYA では緊急モードで起動してほとんど話さなくなり、里々と華和梨では辞書が正しく読み込まれない。華和梨の `check-dic.ps1` と `lint.ps1` は、kosui.exe（`scripts/setup.ps1` が入れる）の安全モードで調べる。`shell/` を変更したら `scripts/check-shell.ps1` も通す。
2. **辞書の関数やトークを書いたり直したりしたら、`scripts/shiori.ps1` で実際に呼び出して**、返すスクリプトと実行時のエラー（存在しない関数の呼び出しなど。読み込みのチェックでは見つからない）を確かめる。ファイルの書き込み、外部プログラムの実行、**SAORI の呼び出し**をする関数やトークは、本当に動く（SAORI の中には、画面を塗りつぶすものもある）。中身を読んで、作者に断ってから呼ぶ。
3. **SSP で動かして確かめるときは、先に `scripts/run-ssp.ps1` で試験用の SSP（readonly）を立ててから** `scripts/sstp.ps1` で送る。立てていないと、作者がふだん使っている SSP（9801）に送ってしまう。`scripts/sstp.ps1` と `scripts/run-ssp.ps1` が表示する SSP のエラーログ（終了コード 2）も見る。再生したトークで解釈できなかったタグは `[GHOST/Script]` のエラーとして出るので、それも直す（`references/workflows/try-in-ssp.md`）。
4. 仕様（さくらスクリプトのタグ、SHIORI イベントの名前と Reference、YAYA の関数、里々の関数、`descript.txt` や `surfaces.txt` の項目）を**推測で書かない**。確かでないときは、下の「仕様を調べる」で確かめる。
5. 文字コードは UTF-8（BOM なし）、改行は LF、辞書のインデントは YAYA がタブ、里々は行頭の指定の位置にタブ（`.editorconfig` と、SHIORI の `dictionary.md`）。元からある文書（`readme.txt` など）の文字コードは変えない。**Shift_JIS の辞書（古い華和梨のゴーストに多い）は、UTF-8 前提の道具で編集しない**（`references/kawari/dictionary.md` の「文字コード」）。
6. **編集しないもの**: SHIORI 本体（`yaya.dll`、`satori.dll`、`satorite.exe`、華和梨の `shiori.dll`）、華和梨の暗号化した辞書（`.kaw` など。元の辞書を直して暗号化し直す）、YAYA のシステム辞書（`ghost/master/dic/system/` または `ghost/master/system/`。変更が必要なら上流の yaya-dic に提案する）、実行時に作られるファイル（`yaya_variable.cfg`、`satori_savedata.*`、`profile/` など）。SHIORI 本体とシステム辞書の更新は、`references/workflows/update-shiori.md` の手順で行う。
7. 既存のトークや作者が書いた台詞を、頼まれていないのに大量に書き換えたり消したりしない。未使用の関数、変数、単語群が見つかっても、報告するだけにする。
8. シェルの画像は、`GHOST.md` でライセンスを確かめるまで編集しない（改変を禁じているシェルがある）。画像の編集には `scripts/image.ps1` を使う（書き出すのは 32bit RGBA PNG）。
9. **作者の確認を取ってから行うこと**: アプリのインストール、SSP へのゴーストのインストール、SHIORI やスキルの更新、旧キットの除去、リリース、ネットワーク更新ファイルのアップロードなど、手元のファイル編集を超える操作。upstream（親リポジトリ）への PR は、作者が明示的に許可するまで一切しない。
10. `scripts/` の外から ukagaka-developer のスクリプトを書き換えない。足したい機能は、ゴーストの側に自分のスクリプトとして置くか、https://github.com/ukatech/ukagaka-developer に提案する。ゴーストの側に PowerShell のスクリプトを置くときは、Windows PowerShell 5.1 でも動くように書き、**ASCII 文字だけで書く**（BOM のないファイルに日本語を書くと 5.1 で文字化けする）。

## 仕様を調べる

さくらスクリプトのタグ、SHIORI イベントの名前と Reference、YAYA の関数、里々の関数、華和梨の文法と KIS コマンド、各種設定ファイルの項目は、推測で書かず、次の順で確かめる。

1. **MCP サーバー `ukagaka-doc`**（UKADOC、SSP ヘルプ、YAYA docs、里々 docs、華和梨 docs などを検索できるオンラインのサーバー。URL は `https://ssp.shillest.net/ukadoc/mcp`）。Claude Code ではプラグインに入っている（初回に承認が要る）。ほかのエージェントでは、そのツールの MCP 設定に HTTP（Streamable HTTP）のサーバーとして登録する。
   - `search_docs` は、クエリ全体を 1 つの部分文字列として探す。**スペースを含まない単語 1 つ**を投げる（`OnSurfaceRestore`、`\q`、`選択肢`、`REPLACE` のように。さくらスクリプトは `\q` とバックスラッシュ付きで）。「文字列 置換」のような複数語や自然文は 0 件になる。
   - 絞り込みは語を足さず、`source`（`ukadoc` / `ssp_help` / `yaya_docs` / `satori_docs` / `kawari_docs` など）と `category` で行う。0 件は「存在しない」ではなく「引き方が違う」ことが多い。短い語に分解し、日本語の説明語、英語のタグ名、上位概念の 3 方向から引く。
   - 本文は `get_doc` で読む（`search_docs` の summary は冒頭だけ）。MCP の内容は定期的なスナップショットで、各ソースの最新の更新が反映されていないことがある。
2. **一次資料を読む。**
   - さくらスクリプト一覧: https://ssp.shillest.net/ukadoc/manual/list_sakura_script.html
   - SHIORI イベント一覧: https://ssp.shillest.net/ukadoc/manual/list_shiori_event.html
   - SHIORI リソース一覧: https://ssp.shillest.net/ukadoc/manual/list_shiori_resource.html
   - ゴーストの descript.txt: https://ssp.shillest.net/ukadoc/manual/descript_ghost.html
   - シェルの descript.txt: https://ssp.shillest.net/ukadoc/manual/descript_shell.html
   - surfaces.txt: https://ssp.shillest.net/ukadoc/manual/descript_shell_surfaces.html
   - SSTP: https://ssp.shillest.net/ukadoc/manual/spec_sstp.html
   - install.txt / .narignore / .updateignore / delete.txt: https://ssp.shillest.net/ukadoc/manual/descript_install.html
   - ネットワーク更新: https://ssp.shillest.net/ukadoc/manual/dev_update.html
   - YAYA: yaya-docs https://yaya-shiori.github.io/yaya-docs/ （文法、システム関数、ハッシュと入れ子 `grammar/12-hash`・`13-nesting`、正規表現 `grammar/14-regular-expressions`、600 系の変更点）、本体 https://github.com/YAYA-shiori/yaya-shiori 、システム辞書 https://github.com/YAYA-shiori/yaya-dic
   - 里々: satori-docs https://ukatech.shillest.net/satori-docs/ （文法、イベントと動作、内蔵関数、システム変数、ssu と正規表現 `ssu/regex`、エラーメッセージ、里々 2 の紹介 `other/satori2-launch`。`ukatech.github.io/satori-docs/` はここに転送される）、本体 https://github.com/ukatech/satoriya-shiori
   - 華和梨: kawari-docs https://ukatech.shillest.net/kawari-docs/ （文法、SHIORI としての動作、KIS コマンド、幸水と `kosui --check`、移行ガイド、更新履歴。生の Markdown は `kis/set.md` のようにリポジトリと同じパスで読める。AI 向けの案内は `llms.txt`）、本体 https://github.com/ukatech/kawari
3. それでもわからなければ Web 検索する。

YAYA の関数の戻り値や、里々・華和梨の関数の細かい挙動は、調べたうえで、`scripts/shiori.ps1 -Eval` でこのゴーストの dll に実際に評価させて確かめられる（`references/yaya/commands.md`、`references/satori/commands.md`、`references/kawari/commands.md`）。

調べものは、小さく速いモデルのサブエージェントに任せるとよい（Claude Code のプラグインには `ukagaka-researcher` が入っている）。

## 資料

必要になったときに読む。

| 資料 | 中身 |
|---|---|
| `references/commands.md` | スクリプトの一覧、終了コード、ゴーストのルートと SSP の探し方、ホームフォルダ |
| `references/yaya/commands.md`、`references/satori/commands.md`、`references/kawari/commands.md` | SHIORI ごとの `check-dic` `shiori` `lint` `update-shiori` の使い方 |
| `references/image-editing.md` | `scripts/image.ps1` の操作の一覧 |
| `references/layout.md` | ゴーストのディレクトリ構成。どのファイルが何をするか、実行時に作られるもの |
| `references/standalone.md` | テンプレートから独立させるとき、配布する前に変えるものの一覧 |
| `references/ai-guidelines.md` | AI を使ったゴースト制作のガイドラインと、AI がやりがちな失敗 |

## AI を使ったゴースト制作の約束

伺かは、作者が手作りしたゴーストを配り合う文化の上に成り立っている。詳しくは `references/ai-guidelines.md`。要点:

- 他のゴーストの台詞、シェル画像、辞書を、コピーしたり言い換えたりして持ち込まない。参考にしてよいのは、公開されている仕様と、このゴースト自身の辞書だけ。
- 実在の人物を模したキャラクターを作らない。AI の側から既存のキャラクターを持ち込まない。
- 生成したトークは、作者が読んで確かめてから公開するものとして書く。数を増やすための大量生成はしない。
- 頼まれていないのに、ユーザーの PC に影響する処理（`\![open,...]`、`\![execute,...]`、`\-`、外部プログラムの実行、ファイルの書き込み、SAORI の読み込みなど）を書かない。

## 里々で発展的な処理をするとき

選択肢やメニュー、一覧表示などの画面づくり、好感度のような仕組みが里々で実現できるかの判断、動作の検証といった、このスキルの資料だけでは足りない発展的な処理には、第三者のスキル **ukagaka-satori-helper**（MIT License、https://github.com/earlduant/ukagaka-satori-helper ）が役に立つ。このスキルには同梱されていない。入っていないときは、使うかどうかと導入を作者に提案し、了承を得てから入れる（Claude Code: `claude plugin marketplace add earlduant/ukagaka-satori-helper` のあと `claude plugin install ukagaka-satori-helper --scope project`。Codex など: GitHub から ZIP を取得し、`skills/ukagaka-satori-helper/` を `.agents/skills/` に置く）。どちらも入れたときも、上の「作業のルール」は変わらない。
