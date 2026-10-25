# ディレクトリ構成

伺かのゴースト（ゴーストのルート。`ghost/` と `shell/` が並んでいる）の標準的な構成。ゴーストごとに違うところは `GHOST.md` に書かれている。

## 共通

| パス | 内容 |
|---|---|
| `GHOST.md` | **このゴーストに固有の情報**（キャラクター、サーフェス、ライセンス、辞書の構成）。ゴーストのもの。スキルの更新で変わらない |
| `AGENTS.md`、`CLAUDE.md` | AI エージェント向けの短い案内（`GHOST.md` を読むこと、スキルを使うこと）。`scripts/init-ghost.ps1` が作る。`CLAUDE.md` は `@AGENTS.md` と `@GHOST.md` を読み込む |
| `ghost/master/descript.txt` | ゴーストの基本情報（名前、作者、使う SHIORI の `shiori` など）。スキルはこの `shiori` と dll で YAYA / 里々を見分ける |
| `shell/master/surfaces.txt` | サーフェス（表情、アニメーション、当たり判定）の定義 |
| `shell/master/surfacetable.txt` | サーフェス番号と表情名の一覧（あるとき） |
| `shell/master/descript.txt` | シェルの情報、メニューや吹き出し位置の設定 |
| `install.txt` | インストール設定（名前、インストール先のフォルダ名、`refreshundeletemask` など） |
| `.narignore` / `.updateignore` | nar / ネットワーク更新から除外するファイル。書き方は `.gitignore` と同じで、`include:ファイル名` で別のファイルを取り込める（パスはその行を書いたファイルのフォルダからの相対。取り込んだ先でも `include:` を書け、3 段まで）。SSP が使い（`scripts/build-nar.ps1` も SSP に作らせる。`-ListOnly` と `-Builtin` では `.narignore` を SSP と同じように自分で解釈する）、どちらもルートに置いたものだけを読む。`.narignore` の `# files for developing the ghost with ukagaka-developer` から始まるブロックが、開発用のファイル（`GHOST.md`、`AGENTS.md`、`CLAUDE.md`、`.mcp.json`、`.claude/`、`.agents/`、`build/`）を nar に入れないようにする |
| `delete.txt` | ネットワーク更新のときに削除するファイル（あるとき） |
| `updates2.dau`、`updates.txt` | ネットワーク更新ファイル（`scripts/build-nar.ps1` が作る。ゴーストのルートに置いて配るもの。git には入れない） |
| `.gitignore`、`.gitattributes`、`.editorconfig` | git と、エディタの設定（文字コード UTF-8、改行 LF、辞書のインデント）。`.gitattributes` は SHIORI によって `*.sat` の扱いが違う |
| `.github/workflows/auto_check.yml` | push ごとに辞書チェックする（`templates/github/auto_check.yml`。`references/workflows/ci.md`） |
| `.claude/`、`.agents/` | AI エージェントの設定と、コピーで入れたスキル（`.agents/skills/ukagaka-developer/`）。nar には入れない |
| `build/` | `scripts/build-nar.ps1` の出力（nar と更新ファイル）。`build/.gitignore` が自分を git から外す |

スキルのスクリプトが作るもの（ビルドした tamacs.exe、SSP の場所の設定、移行のバックアップ）は、ゴーストのフォルダではなく、ホームフォルダ（`%LOCALAPPDATA%\ukagaka-developer`）に置かれる（`references/commands.md`）。

## YAYA のゴースト

| パス | 内容 |
|---|---|
| `ghost/master/yaya.txt` | YAYA の基本設定。文字コードと、読み込む辞書フォルダ（`dicdir, dic/normal` など） |
| `ghost/master/yaya_emerg.txt` | 辞書エラー時の緊急モードの設定（`dic/emerg` などを読む） |
| `ghost/master/system_config.txt` | システム辞書の読み込みとログの設定（テンプレートのゴーストにある） |
| `ghost/master/dic/normal/*.dic` | **ゴーストの辞書本体。主に編集するのはここ** |
| `ghost/master/dic/emerg/*.dic` | 緊急モード用の最小限の辞書 |
| `ghost/master/dic/system/` | システム辞書（[yaya-dic](https://github.com/YAYA-shiori/yaya-dic)。git clone したフォルダでは submodule）。ゴーストによっては `ghost/master/system/` にあり、スクリプトはどちらにも対応している。古いゴーストでは `ghost/master/` の直下などに古い名前（`yaya_shiori3.dic` など）で置かれていることもある（`references/yaya/update.md`）。**編集しない**。更新は `scripts/update-shiori.ps1` で行う |
| `ghost/master/yaya.dll` | SHIORI 本体。`scripts/update-shiori.ps1` 以外で差し替えない |

実行時に作られるもの（編集もコミットもしない）: `ghost/master/yaya_variable.cfg`（グローバル変数の保存先）、`ghost/master/profile/`、`shell/master/profile/`。

## 里々のゴースト

| パス | 内容 |
|---|---|
| `ghost/master/satori_conf.txt` | 里々の初期設定。**`＊初期化`（システム変数の初期値）と `＠SAORI`（SAORI の登録）だけが有効** |
| `ghost/master/dic*.txt` | **ゴーストの辞書本体。主に編集するのはここ**。`dic` で始まり `.txt` で終わるファイルがファイル名の順にすべて読まれる（サブフォルダは `＄辞書フォルダ` で指定したときだけ） |
| `ghost/master/replace.txt` / `replace_after.txt` | 辞書の読み込み時の置換 / 応答を返す直前の置換（`置換前<タブ>置換後`） |
| `ghost/master/satori.dll` | SHIORI 本体（Unicode 版は ssu を内蔵している）。`scripts/update-shiori.ps1` 以外で差し替えない。旧版のゴーストには `saori/ssu.dll` が残っていることもある（`references/satori/update.md`） |
| `ghost/master/satori_license.txt` | `satori.dll` のライセンス。`satori.dll` を同梱する限り残す |
| `ghost/master/satorite.exe` ほか | 里々の補助ツール（さとりて）と説明文書。**編集しない**。更新は `scripts/update-shiori.ps1` |
| `ghost/master/saori/` | SAORI の DLL（`＠SAORI` で登録する）。ssu は内蔵なので要らない |

実行時に作られるもの（編集もコミットもしない）: `ghost/master/satori_savedata.txt` と `satori_savebackup.txt`（変数の保存先。ゴーストの終了時に里々が書く。暗号化を有効にしたときは `.sat`）、`ghost/master/profile/`、`shell/master/profile/`。

`scripts/check-dic.ps1` と `scripts/shiori.ps1` は、`ghost/master` の一時コピーで里々を動かすので、実行してもこのフォルダに `satori_savedata.txt` などは残らない。
