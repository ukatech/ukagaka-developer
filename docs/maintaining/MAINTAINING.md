# このスキル自身を直す・育てる人へ

`ukagaka-developer`（スキルの本体、スクリプト、資料）を直すときの注意です。ゴーストを作るときの指示は `skills/ukagaka-developer/SKILL.md` と `references/`、利用者向けの案内は `README.md` にあります。このフォルダ（`docs/maintaining/`）は、リポジトリにだけあり、スキルの一部としては配られません（プラグインにも、フォルダのコピーにも入りません）。

## 由来と方針

konnoyayame（YAYA）と POST_and_KOMAINU（里々）のそれぞれにあった「AI 開発キット」（ゴーストの中の `tools/`、`docs/agents/`、`AGENTS.md`）を、1 つのスキルに統合したものです。

- **ゴーストの外に置く。** ゴーストのフォルダには何もコピーしない。ゴーストに置くのは、ゴーストのものである `GHOST.md`、短い `AGENTS.md` / `CLAUDE.md`、`.narignore` などだけ（`templates/`）。
- **SHIORI に依存しない部分は 1 つにする。** SSP、シェル、nar、画像、SSTP は共通（`scripts/` 直下と `scripts/lib/`、共通の `references/`）。SHIORI に依存する部分は `scripts/shiori/<yaya|satori|kawari>/` と `references/<yaya|satori|kawari>/` に分ける。
- **公式情報にリンクする。** 仕様の詳細（さくらスクリプト、YAYA の関数、里々の関数）は、複製せず、`ukagaka-doc` MCP と公式サイトに誘導する。複製した情報は古くなる。スキルに書くのは、手順、落とし穴、そして「どの資料を読むか」。
- **更新を追える形にする。** `plugin.json` と `marketplace.json` に `version` を書かない（下の「更新」）。変わりやすい事実（dll の版、SSP の最新版）は文書に書かず、スクリプトが実行時に GitHub から調べる。

## 構成

```
.claude-plugin/plugin.json, marketplace.json   version を書かない
.mcp.json                                       ukagaka-doc（仕様検索 MCP）
agents/ukagaka-researcher.md                    仕様調査（haiku）。プラグインでは名前空間付き（ukagaka-developer:ukagaka-researcher）
skills/ukagaka-developer/                       ← コピー導入では、このフォルダだけが配られる。自己完結させる
  SKILL.md                                      入口。500 行以下。allowed-tools に読み取り専用のスクリプトを許可
  scripts/                                      共通のスクリプト。shiori/<id>/ に SHIORI 固有のもの
  references/                                   引く資料。workflows/ と、共通、yaya/、satori/
  templates/                                    ゴーストに足すファイルの元（GHOST.md、narignore など）
docs/maintaining/                               この文書と実装メモ
tests/check-repo.ps1                            リポジトリの検査（CI でも走る）
```

- **`skills/ukagaka-developer/` の外のファイルを、スクリプトや資料から参照しない。** コピー導入では外が無い。
- **スキルのフォルダには書き込まない。** プラグインの更新で置き換わり（`${CLAUDE_PLUGIN_ROOT}` は版ごとに変わる）、コピー導入でも `update-skill.ps1` が置き換える。書き込む先はホームフォルダ（`Get-DevkitHome`）。

## ゴーストのルートとホームフォルダ

- すべてのスクリプトは `lib/common.ps1` を読み、`Initialize-DevkitConsole` を呼ぶ。これがゴーストのルート（`$DevkitRoot`）を決める: `-GhostRoot`、環境変数 `UKADEV_GHOST_ROOT`、作業フォルダとその親の順に `ghost/master/descript.txt` を探す。スクリプトは `[string]$GhostRoot` のパラメーターを持つ（`Initialize-DevkitConsole` が呼び出し元のスコープから読む）。ゴーストの無い場所でも動くスクリプトは `-NoGhost`。
- `SHIORI` ごとに分かれるスクリプト（`check-dic`、`shiori`、`lint`、`update-shiori`）は、`scripts/` 直下の窓口が `Resolve-DevkitShioriScript` で `scripts/shiori/<id>/` の同名のスクリプトを探し、`& $target.Path @args` で引数をそのまま渡す。**`@args` でなければならない**: `$args` だけが、`-Run` のようなスイッチを名前付きの引数として保つ。配列を別の変数に入れて渡すと、`-Run` が位置引数の文字列になる。
- ホームフォルダは `UKADEV_HOME`、なければ `%LOCALAPPDATA%\ukagaka-developer`。ビルドした exe（`bin/`）、`local.json`（SSP の場所）、移行のバックアップ（`backups/`）。ゴーストのフォルダに何も増やさないので、nar とネットワーク更新に混ざらない。
- 一時ファイルは OS の一時フォルダの `ukagaka-developer/`（SSP の試験用セッション、画像の出力）。

## `scripts/*.ps1` の書き方

- Windows PowerShell 5.1 と PowerShell 7 の両方で動かす。`??`、`?.`、三項演算子、パイプラインの `&&` など、7 だけの構文は使わない。GitHub Actions では pwsh（Windows と Ubuntu）でも動く。
- **ASCII 文字だけで書く**（BOM のないファイルに日本語を書くと、5.1 で文字化けする）。日本語の文字列が要るときは、UTF-8 の JSON に置く（`shiori/satori/satori.json`）か、`[char]0x...` で組み立てる。`tests/check-repo.ps1` が確かめる。
- 冒頭で `. (Join-Path $PSScriptRoot 'lib/common.ps1')`（`shiori/<id>/` では `'../../lib/common.ps1'`）を読み、`Initialize-DevkitConsole` を呼ぶ。パスは `$DevkitRoot` から組み立て、`ghost/master` と `shell/master` を前提にしてよい。
- 終了コードをそろえる: 0 OK / 1 失敗・エラー / 2 注意が要る（SSP のエラーログの Error、手作業が残る、など）/ 3 ツールや SSP が無くて確かめられない。
- 冒頭のコメントヘルプ（`.SYNOPSIS`、`.DESCRIPTION`、終了コード、`.EXAMPLE`）を書き、`references/commands.md`（と、SHIORI のコマンド表）も直す。
- 使い方の例は `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/<名前>.ps1` の形にそろえる。`SKILL.md` の `allowed-tools` は、この形で許可している（Claude Code の仕様では、許可はスキルを読み込んだターンの間だけで、次のメッセージで切れる。また、パスの置き換えは `Bash(...)` の規則に書かれていて、`PowerShell(...)` の規則に効くかは確かめていない。なので、文書に「確認が出ない」とは書かない。読み取り専用のスクリプトだけ。`run-ssp`、`sstp`、`build-nar`、`update-*`、`migrate-*`、`init-ghost` は、作者の PC に影響するので許可しない）。
- スクリプトを足したら、`SKILL.md` の表、`references/commands.md`、必要なら `allowed-tools` を直す。

## 新しい SHIORI を足す

YAYA、里々、華和梨の 3 つに対応している。足すときは、次の形をそろえる（`tests/check-repo.ps1` が一部を確かめる）。

1. `scripts/lib/common.ps1` の `$DevkitShioriTable` に `Id`、`Dll`、`Name`、`Marker` を足す（`Marker` は、華和梨の `shiori.dll` のように、ほかの SHIORI と同じ dll の名前を使うときに、横にあるはずのファイル。`kawarirc.kis`）。`$DevkitShioriSupported` の文も直す。
2. `scripts/shiori/<id>/` に、`lib.ps1`（`Invoke-DevkitTamacs`、`Add-DevkitShioriDoctorItems`、`Invoke-DevkitShioriSetup`、`$DevkitTamacsPurpose`）、`check-dic.ps1`、`shiori.ps1`、`update.ps1`（あれば `lint.ps1`）。
3. `templates/<id>/`（`GHOST.md`、`narignore`、`gitattributes`、`editorconfig`）。`scripts/lib/ghost-files.ps1` の `Get-DevkitStarterFiles` が使う。
4. `references/<id>/`（`dictionary.md`、`check.md`、`commands.md`、`update.md`）。`SKILL.md` の「こう頼まれたら」と「資料」に行を足す。
5. `agents/ukagaka-researcher.md` と `SKILL.md` の「仕様を調べる」に、そのSHIORIの公式資料を足す。

## 資料の書き方

- `SKILL.md` は 500 行以下にし、詳しいことは `references/` に置く。`references/` から別の資料を指すときは、スキルのフォルダからの相対パス（`references/yaya/check.md`）で書く。
- `references/workflows/` に手順書を足したら、`SKILL.md` の「こう頼まれたら」の表にも行を足す。作者の言い回しは、その文書の「使うとき」とそろえる。想定している作者は、コーディングエージェントに不慣れで、自然な言葉で頼む。スラッシュコマンドは前提にしない。
- 特定のゴースト（konnoyayame の「ややめ」、POST_and_KOMAINU の「ポスト」など）に固有のことを書かない。固有のことは、そのゴーストの `GHOST.md` に書く。
- 公式情報は変わる。例: 里々の仕様書は `ukatech.github.io/satori-docs/` から `ukatech.shillest.net/satori-docs/` に移った。URL は `SKILL.md`、`agents/ukagaka-researcher.md`、`references/satori/` にあるので、変わったら `tests/check-repo.ps1` の URL 一覧（`$ExpectedUrls`）と合わせて直す。

## 旧 AI 開発キットとの互換

- `scripts/lib/legacy-devkit.ps1` と `scripts/migrate-from-devkit.ps1` は、旧キットの `tools/devkit.json`（`files`、`exclude`、`seed`）と `tools/devkit.lock.json`（ファイルごとの、LF にそろえた SHA256）の形式を読む。**旧キットのゴーストが残っている間は、この形式の読み取りを変えない。** ハッシュの計算（`Get-DevkitFileHash`）を変えると、変えていないファイルまで「変更あり」に見える。
- 旧キットの配布元（konnoyayame と POST_and_KOMAINU のリポジトリ）が、キットをスキルに切り替えるまで、既存のゴーストの `tools/update-devkit.ps1` は、旧キットを取り続ける。切り替えたリポジトリの `DEVKIT-MAINTAINING.md` は、`migrate-from-devkit.ps1` が「キットの配布元」と判定して止まる目印でもある。
- 移行を直したときは、必ず**コピー**の上で試す（下の「確認」）。

## 更新（プラグイン）

- `plugin.json` と `marketplace.json` に **`version` を書かない**。書くと、書き換えない限り、利用者は更新を受け取れない（Claude Code は、マニフェストの `version`、マーケットプレイスの `version`、なければ git のコミット SHA の順で版を決め、版が同じなら更新しない）。書かなければ、コミットのたびに新しい版になり、`claude plugin update` と自動更新で届く。
- コピー導入の利用者は、`scripts/update-skill.ps1`（GitHub の既定ブランチの最新コミットを取る。取ったコミットは、スキルのフォルダの `.installed-from` に書かれる）で更新する。
- したがって、**既定ブランチの先頭は、いつでも利用者に届く**。壊れたまま push しない。大きな変更は、ブランチで確かめてから入れる。
- `claude plugin validate .` で、マニフェストと同梱物（`.mcp.json`、`agents/`、`skills/`）を確かめる（Claude Code v2.1.281 以降の検査）。
  - 「No version specified」の警告は、意図したもの（上の理由）。アイコンとプライバシーポリシー URL の警告は、Anthropic のディレクトリに登録するときのもので、いまは対象外。

## 実装メモ

スクリプトが頼っている外部のプログラムの挙動と、そう実装した理由は、話題ごとに書いている。そのスクリプトを変えるときに読む。新しい話題はファイルを足し、この表に行を足す。

| ファイル | 中身 |
|---|---|
| `ssp.md` | SSTP（Owned SSTP）、SSP のログ、SSP の版の扱い、使っている機能（`GetStatus`、`Option: strict`、`dumpballoon`、`--dump-error-log`、`--offline-tool`）、試験用 SSP（`scripts/run-ssp.ps1`） |
| `dump-surface.md` | `scripts/dump-surface.ps1` と `--offline-dump` の `--dump-surface-list`、`--dump-animation`、`--dump-bind` |
| `image.md` | `scripts/image.ps1` と `scripts/lib/image.cs`、`scripts/lib/image-engine.ps1`（コンパイルとキャッシュ、自前の PNG の読み書き、SSP の透過の扱い） |
| `tamacs.md` | tamacs.exe（`scripts/lib/tamacs.cs`）のビルドと、tamac との違い、`-r` と `scripts/shiori.ps1`、ログ受信ウインドウ tamacsw.exe |
| `update-yaya.md` | `scripts/shiori/yaya/update.ps1` のシステム辞書（yaya-dic）の取得と置き換え、yaya.dll の版の選び方 |
| `update-satori.md` | `scripts/shiori/satori/update.ps1` の satori.zip の取得と、版の選び方 |
| `satori-check.md` | 里々の `check-dic` と `shiori` の実装（一時コピー、ShioriEcho、ログの読み方） |
| `kawari.md` | 華和梨の実装（kosui `--check` と tamacs.exe `--no-loghandler` の使い分け、一時コピーに足すログとフック、`shiori.dll` の版、文字コード、`update.ps1`） |
| `ignore.md` | `.narignore` / `.updateignore` の解釈（`scripts/lib/ignore.ps1`） |

## 確認

スキルを変えたら、次を確かめる。

1. `powershell -NoProfile -ExecutionPolicy Bypass -File tests/check-repo.ps1`: 構文（5.1 でも）、ASCII、`SKILL.md` と文書が指すパスの実在、`allowed-tools` のパス、SHIORI の部品の形。
2. YAYA のゴースト（konnoyayame）と、里々のゴースト（POST_and_KOMAINU）と、華和梨のゴースト（Shift_JIS の辞書のもの、Phase 8 の `shiori.dll` のものも）の**コピー**で、`scripts/doctor.ps1`、`scripts/check.ps1`、`scripts/shiori.ps1 -Eval`、`scripts/update-shiori.ps1 -DryRun`、`scripts/build-nar.ps1 -ListOnly` が動く。Windows PowerShell 5.1 と `pwsh` の両方で。環境変数 `UKADEV_HOME` を一時フォルダにして、利用者のホームフォルダを汚さない。
3. 移行のシナリオ（コピーの上で）:
   - 旧キットの入ったゴーストに `migrate-from-devkit.ps1`（ドライラン）→ `-Apply`。旧キットのファイルが消え、`AGENTS.md` / `CLAUDE.md` がスタブになり、`.narignore` が書き換わり、`doctor.ps1` の `old development kit` が ok になる。
   - `AGENTS.md` を手で変えたもの、`tools/` に作者のスクリプトがあるもの、`.claude/settings.json` に作者の許可があるもの、`tools/local.json` があるものでは、変えたファイルが残り、`settings.json` は編集に留まり、SSP の場所が `local.json` に移る。
   - `.git` の無いフォルダ（nar をインストールしたもの）でも動く。
   - `DEVKIT-MAINTAINING.md` のあるフォルダで止まる。
   - バックアップから元に戻せる。
4. `scripts/update-skill.ps1 -Source <このリポジトリ> -Target <コピー>` で、コピー導入の更新が動く。
5. `scripts/build-nar.ps1 -ListOnly` で、開発用のファイル（`GHOST.md`、`AGENTS.md`、`.claude/`、`.agents/`、`build/`）が入っていない。
