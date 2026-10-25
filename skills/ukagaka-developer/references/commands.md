# コマンド

スキルのスクリプト（`scripts/`）の一覧と、終了コードの意味。

- 以下の `<ps>` は `powershell -NoProfile -ExecutionPolicy Bypass -File` の略。Windows PowerShell 5.1 でも PowerShell 7 でも動く。
- `scripts/` は、このスキルのフォルダ（`SKILL.md` のあるフォルダ）の中。実行するときは、`${CLAUDE_SKILL_DIR}/scripts/doctor.ps1` のようにフルパスにする（`${CLAUDE_SKILL_DIR}` が展開されないエージェントでは、`SKILL.md` のあるフォルダのパスに読み替える）。
- **作業フォルダはゴーストのルート**（`ghost/` と `shell/` が並んでいるフォルダ）にする。別の場所から呼ぶときは `-GhostRoot <フォルダ>`（環境変数 `UKADEV_GHOST_ROOT` でも指定できる）。ゴーストのルートは、作業フォルダとその親をさかのぼって `ghost/master/descript.txt` を探して決める。
- SHIORI（YAYA / 里々）は、`ghost/master/descript.txt` の `shiori` と、`ghost/master` の dll から自動で判別する。`check-dic` `shiori` `lint` `update-shiori` は、判別した SHIORI のスクリプト（`scripts/shiori/yaya/` か `scripts/shiori/satori/`）に引数をそのまま渡す。オプションが SHIORI で違うので、詳しくは `references/yaya/commands.md` と `references/satori/commands.md`。

| コマンド | 内容 | 終了コード |
|---|---|---|
| `<ps> scripts/doctor.ps1` | 開発環境を診断し、足りないもの（Git、SSP、チェック用ツール、`GHOST.md`、旧キットの残りなど）の用途と入手方法を表示する。ゴーストのルートと SHIORI、ホームフォルダも表示する。何も変更しない（`-Json` で機械向けの出力） | 0 必須はそろっている / 1 必須が足りない |
| `<ps> scripts/setup.ps1` | tamacs.exe をホームフォルダにビルドする（Windows に入っている .NET Framework のコンパイラを使う。使うときにも自動でビルドされる）。YAYA で git clone したフォルダなら、システム辞書の submodule も取得する。`scripts/tools.json` にダウンロードするツールがあれば取得する（今は無い）。最後に doctor の結果を表示する | 0 成功 / 1 失敗、または必須が足りない |
| `<ps> scripts/init-ghost.ps1` | ゴーストに無い入門用のファイル（`GHOST.md`、`AGENTS.md`、`CLAUDE.md`、`.narignore`、`.updateignore`、`.gitattributes`、`.editorconfig`）を、スキルの `templates/` から作る。あるファイルは変えない。`-NarignoreDevBlock` で既存の `.narignore` に開発用ファイルの除外（nar に入れない）を足し、`-Workflow` で `.github/workflows/auto_check.yml` も作る。`-DryRun` で確認のみ | 0 / 1 |
| `<ps> scripts/check-dic.ps1` | tamacs.exe でこのゴーストの SHIORI（yaya.dll / satori.dll）に辞書を実際に読み込ませ、エラーを表示する（SSP は要らない）。YAYA と里々でオプションと、拾うエラーが違う | 0 OK / 1 エラー / 3 確かめられない（tamacs.exe をビルドできない、dll が古くて `Set_loghandler` が無い） |
| `<ps> scripts/check.ps1` | check-dic、check-shell、（YAYA のみ）lint を順に実行する（里々では `-Run` を check-dic に渡す） | 0 / 1 |
| `<ps> scripts/shiori.ps1 ...` | SSP を使わずに、tamacs.exe でこのゴーストの SHIORI に SHIORI リクエストを 1 回送って、結果を表示する（`-Eval` は YAYA のコードや里々の文を評価する。`-Event <ID>` はイベントを送る）。呼ぶたびに辞書を読み込み直し、本物のフォルダのセーブデータや変数は変わらない | 0 / 1 失敗 / 2 処理中に SHIORI がエラーを出した / 3 tamacs.exe をビルドできない、dll が古い |
| `<ps> scripts/lint.ps1` | （YAYA のみ）未定義・未使用の変数と関数、条件式の中の代入を探す（参考情報）。里々には無く、終了コード 3 | 0 / 1 / 3 |
| `<ps> scripts/update-shiori.ps1` | このゴーストの SHIORI を最新に更新する（YAYA: yaya.dll とシステム辞書 yaya-dic、里々: satori.dll と satorite.exe）。更新の後で辞書チェックを行い、失敗したら元に戻す。`-DryRun` で確認のみ。オプションは SHIORI ごとに違う | 0 / 1 失敗 / 2（YAYA）システム辞書に手作業が要る |
| `<ps> scripts/check-shell.ps1` | `ssp.exe --offline-dump` でシェルを検査する（Error / Warning / Notice）。問題の定義位置（`shell/master/surfaces.txt:Line=123`）も表示する | 0 OK / 1 Error あり / 3 SSP が見つからない |
| `<ps> scripts/dump-surface.ps1 -Surface 0,5,10` | `ssp.exe --offline-dump` で、サーフェスを surfaces.txt の定義どおりに重ね合わせた PNG を作り、そのパスを表示する（ゴーストは起動しない）。画像を読めるエージェントが表情や重ね合わせを目で確かめるためのもの。`-Surface` は番号のほか `0-7` のような surfaces.txt の拡張形式も使える。`-Backlog` で顔のまわり（約 80×80）だけを切り抜き、`-Collision` で当たり判定（`collision` の形と名前）を描き込み、`-Sheet` で全部を番号付きで 1 枚に並べた `sheet.png` も作る。`-Animation <ID>`（番号か、surfaces.txt でアニメーションに付けた名前。1 つだけ）で、そのアニメーションを `\i[ID]` と同じように再生し、パターンが進むたびの姿を `surface0_0000.png`、`surface0_0001.png`… と連番で書く（まばたきや口パクをコマごとに見る。`-Sheet` と合わせると 1 枚に並ぶ）。`-Bind 'カテゴリ,パーツ;カテゴリ,パーツ,0'` で着せ替えの状態を指定する（パーツを空か `__ALL__` にするとカテゴリ全体。基準はシェルの descript.txt の既定値で、ユーザーが最後に着せ替えた状態ではない）。`-Animation` と `-Bind` は SSP 2.9.05 以降。無いアニメーションやパーツは SSP の Warning として表示され、`-Bind` のカテゴリやパーツが見つからなかったときは、その指定を `bind part not found` として表示する（その指定だけ着せ替えずに画像を作るので、着せ替えた姿と取り違えない）。`-Compare HEAD`（コミットやタグ、または別のフォルダにあるこのゴースト）で、同じサーフェスをそちらからも作り、1 枚ずつ画素単位で比べる。違う画素の数と範囲、そのうち差が 32 を超える（目で見て分かる）画素の数、最大の差を表示し、変わったサーフェスは `compare-<名前>.png` に、変わった範囲を拡大した前・後・違い（差が 32 を超える画素は赤、それ以下は黄）を書く。相手側の画像は出力先の `compare/` に置く。直した場所以外が 1 ドットも変わっていないことを確かめるのに使う。`-Scope` / `-Shell` で対象を変える。出力先は既定で一時フォルダの `ukagaka-developer/surfaces-<ハッシュ>/`（実行のたびに中の PNG を消す）。シェルのライセンスによっては改変した画像を配布できないので、ゴーストのフォルダやリポジトリには置かない | 0 全部出た / 1 1 枚も出ない、引数の誤り / 2 見つからない番号があった、`-Animation` のコマが 1 枚も出なかった、`-Bind` のカテゴリやパーツが見つからなかった、または SSP がエラーを記録した / 3 SSP が見つからない |
| `<ps> scripts/image.ps1 <サブコマンド> ...` | 画像を調べる・編集する・比べる・拡大して見る（主にシェルの画像）。書き出す画像は必ず 32bit RGBA PNG。`info` は大きさ、ファイルの透過の持ち方、見えている範囲、`-At x,y,...` の画素の値と、シェルのフォルダにある画像なら SSP で何が透過になるか（`seriko.use_self_alpha`）を表示する。`edit <入力> -Out <出力> '<操作>' ...` は操作を順に当てて書き出す。`view` は拡大図（座標の目盛り付き、複数なら横に並べる）を書き、`diff` は 2 枚の違う範囲を表示し、`-Part` で違う画素だけをパーツとして切り出す。操作と使い方は下の「画像の編集」 | 0 / 1 失敗（引数の誤り、読めないファイル、未知の操作）/ 2 `edit` は書いたが、そのままでは SSP がアルファを使わない（隣に `.pna` がある、シェルに `seriko.use_self_alpha,1` が無い） |
| `<ps> scripts/run-ssp.ps1` | このフォルダのゴーストを SSP で直接起動し（`ssp.exe --ghost <フォルダ>`。インストール不要）、応答するまで待つ。作者の SSP とは別の試験用 SSP を `--option readonly --sstp-listen <ポート>` で立てる（設定や起動履歴を保存せず、vanish してもフォルダを消さない。ポートは 9822〜10999 の空いている最初のもの）。すでに動いていればそのままにする。`-Stop` で閉じ、`-Shared` なら今までどおり作者の SSP（9801）で動かす。起動中に SSP のエラーログに増えた警告・エラーを、起動時のトークが終わるのを待ってから表示する | 0 起動した（`-Stop` は閉じた、または動いていなかった）/ 1 応答なし、起動できない / 2 起動したが、エラーログに Error か Critical が増えた / 3 SSP が見つからない |
| `<ps> scripts/sstp.ps1 -Reload ghost` | 起動中の SSP にゴーストを再読み込みさせ、その間に SSP のエラーログに増えた警告・エラー（YAYA の辞書エラーなど）を表示する | 0 / 1 エラー応答 / 2 エラーログに Error か Critical が増えた / 3 SSP に接続できない |
| `<ps> scripts/sstp.ps1 -Script '\0\s[0]テスト\e'` | さくらスクリプトを実際のゴーストで再生する。SSP が解釈できなかったタグ（存在しないサーフェス、閉じていない `[` など）が `[GHOST/Script]` のエラーとして表示され（`Option: strict`）、ログはゴーストが話し終わるのを待ってから読む | 同上 |
| `<ps> scripts/sstp.ps1 -Event OnAiTalk` | イベントを発生させる（この例はランダムトーク）。応答の `Script:` に、ゴーストが実際に返したスクリプトが入る。そのスクリプトも `-Script` と同じように検査する | 同上 |
| `<ps> scripts/sstp.ps1 -Script '...' -Balloon` | `-Script` か `-Event` に付けると、話し終わった後の吹き出しを `\![execute,dumpballoon]` で PNG にし（`\0` なら `balloon0.png`、`\1` なら `balloon1.png`）、そのパスを表示する。画像を読めるエージェントが、吹き出しに収まっているか、どこで折り返したか、改行や空行の見た目を自分で確かめるためのもの。`-BalloonScope 0,1,2` で撮るスコープを変える（既定は 0,1。吹き出しの無いスコープは撮れない）。出力先は一時フォルダの `ukagaka-developer/balloons-<ハッシュ>/`（実行のたびに中の PNG を消す）。SSTP で送ったときに SSP が付ける `from ukagaka-developer (local)` の行と、`\![set,balloonnum]` の表示は、`--hide` で画像から除く（SSP 2.9.08 以降）。`-AnyGhost` とは使えない | 上と同じ。ほかに、1 枚も撮れなかったら 2 |
| `<ps> scripts/sstp.ps1 -Execute GetStatus` | ゴーストの今の状態（`talking`、`choosing`、`online`、`opening(...)` などのカンマ区切り。当てはまるものが無ければ空）を表示する | 0 / 1 / 3 |
| `<ps> scripts/ssp-log.ps1` | 起動中の SSP のログを表示する。読み取りのみ。既定はこのゴーストのエラーログで、`-Kind script` で再生されたスクリプト（ほかに `network` / `update`）、`-All` で発信元を問わず全部、`-Json` で機械向けの出力。`-Type 文字列` で種類（スクリプトのログならイベント名）がそれを含むものだけ、`-Wait 秒` で新しい項目が来るまで待って、新しいものだけを表示する（タイマーやランダムトークなど、ゴーストが自分から話すのを待つ。例: `-Kind script -Type OnSecondChange -Wait 90`） | 0 / 1 ログを読めない、`-Wait` の間に新しい項目が来なかった / 2 Error か Critical がある / 3 SSP に接続できない |
| `<ps> scripts/build-nar.ps1` | SSP で、`build/<directory>.nar` と、ネットワーク更新ファイル `build/updates2.dau`・`build/updates.txt` を作る（`ssp.exe --offline-tool` を使う。ゴーストは起動せず、SSP が動いていても関係なく作れる）。SSP はフォルダの中身をそのまま固めるので、git に追加していないファイルも入る。`-UpdateOnly` で更新ファイルだけ、`-OutFile` で nar の出力先（更新ファイルはその横）、`-ListOnly` で `.narignore` から見た中身の一覧だけを表示する。`-Builtin` と GitHub Actions では SSP を使わず、git が追跡しているファイルからスクリプト自身が nar だけを作る | 0 / 1 失敗 / 3 SSP が見つからない |
| `<ps> scripts/log-window.ps1` | 里々のログ受信ウインドウ（tamacsw.exe）を開く。SSP で動いているゴーストの里々が出すログを、リアルタイムに表示する（Esc でクリア、F5 で一時停止、Ctrl+S で保存。赤がエラー、橙が警告）。**ゴーストより先に開く**（里々は、読み込まれたあと最初にログを出すときに一度だけ受信ウインドウを探す）。tama（YAYA のログ受信ツール）と同じ仕組みなので、同時には開けない。旧キットの `receiver.bat` の後継 | 0 開いた / 1 ビルドか起動に失敗 |
| `<ps> scripts/migrate-from-devkit.ps1` | 旧 AI 開発キット（`tools/`、`docs/agents/`、`AGENTS.md` など）をゴーストから取り除く。既定は計画の表示だけ（ドライラン）。`-Apply` で実行し、消す・書き換えるファイルを先にホームフォルダの `backups/` へ退避する。キットが入れたまま変えていないファイルだけを消し、作者が変えたファイルは残して知らせる（`-Force` で消す）。旧キットの配布元のリポジトリ（`DEVKIT-MAINTAINING.md` がある）では、`-AllowKitSource` を付けないと止まる。手順は `references/workflows/migrate-from-devkit.md` | 0 / 1 失敗 / 2 手作業が残る |
| `<ps> scripts/update-skill.ps1` | コピーで入れたスキル（Codex など）を GitHub の最新に更新する。Claude Code のプラグインは `claude plugin update ukagaka-developer`。`-DryRun` で確認のみ、`-Ref` で版を指定、`-Source` でローカルのフォルダか zip から。手順は `references/workflows/update-skill.md` | 0 / 1 失敗 |

`scripts/sstp.ps1` と `scripts/ssp-log.ps1` は、`run-ssp.ps1` が立てた試験用 SSP が動いている間は、そのポートに送る（ポートは一時フォルダの `ukagaka-developer/` に記録される）。それ以外は 9801（作者がふだん使っている SSP）。`-Port` で指定もできる。さくらスクリプトやイベントを試すときは、**先に `run-ssp.ps1` で試験用 SSP を立ててから送る**。作者の SSP には、作者に頼まれたとき（`run-ssp.ps1 -Shared`）以外は送らない。

SSP の場所は次の順に探す: `-SspPath` 引数 → 環境変数 `SSP_PATH` → ホームフォルダの `local.json` の `sspPath` → （旧キットから移したゴーストでは）`tools/local.json` の `sspPath` → SSP にインストールされたフォルダなら `../../ssp.exe` → `.nar` のファイル関連付け。

## ホームフォルダ

スクリプトが作るもの（ビルドした tamacs.exe、ダウンロードしたツール、`local.json`、移行のバックアップ）は、スキルのフォルダでもゴーストのフォルダでもなく、**ホームフォルダ**に置く。スキルのフォルダはプラグインの更新で置き換わるので、書き込まない。ゴーストのフォルダには何も増えないので、nar やネットワーク更新に混ざらない。

- 既定は `%LOCALAPPDATA%\ukagaka-developer`（環境変数 `UKADEV_HOME` で変えられる）。場所は `doctor.ps1` が表示する。
- `bin/`: ビルドした `tamacs-<ハッシュ>.exe` など（ソースが変わると作り直す。消してよい）。
- `local.json`: 各自の設定。今は SSP の場所だけ: `{"sspPath": "C:\\ssp\\ssp.exe"}`（JSON なので `\` を重ねる）。
- `backups/`: `migrate-from-devkit.ps1 -Apply` が退避したファイル。

## 関連

- 画像の編集（`image.ps1` の操作の一覧）: `references/image-editing.md`
- YAYA のコマンド: `references/yaya/commands.md`、里々のコマンド: `references/satori/commands.md`
- ディレクトリ構成: `references/layout.md`
