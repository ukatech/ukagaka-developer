# 華和梨（KAWARI）の実装

`scripts/shiori/kawari/` の作りと、そうした理由。華和梨本体は https://github.com/ukatech/kawari 、仕様は https://ukatech.shillest.net/kawari-docs/ 。

## 対象は Phase 9

- スクリプトは `shiori.dll` が Phase 9 のゴーストだけを扱う。Phase 9 は Phase 8 の辞書をそのまま動かせるので、Phase 8 のゴーストは `update-shiori.ps1` で `shiori.dll` を差し替えて対象にする（doctor の `KAWARI Phase 9` が required）。Phase 8.2.x の dll を直接扱わない理由: 応答が常に Shift_JIS、診断の書式が違う（9.2.0 で `ファイル(行): error K-E0028: 本文` にそろった）、UTF-8 の辞書を読まない。
- Phase 7 以前（`kawari.ini` だけで `kawarirc.kis` が無い）は辞書の書き方が違い、差し替えでは動かないので対象外。`Get-DevkitUnsupportedShioriReason`（`scripts/lib/common.ps1`）が見分けて知らせる。
- 判別: `shiori.dll` はほかの SHIORI も使う名前なので、`$DevkitShioriTable` の `Marker`（`kawarirc.kis`）があるときだけ華和梨とみなす。
- 版: Phase 9（8.2.9 から）はファイルのバージョン情報を持つ。無いものは 8.2.8 以前で、多くは UPX で圧縮されていて中の `KAWARI.kdt/x.y.z` も読めない。`Get-DevkitKawariVersion` は「Phase 9 より前」とだけ言う。

## 2 つの道具

`shiori.dll` は `Set_loghandler` を持たない（ログはファイルか標準出力）。そこで、調べものに応じて道具を使い分ける。

| | kosui.exe `--check` | tamacs.exe `--no-loghandler` |
|---|---|---|
| 使うスクリプト | `check-dic.ps1`、`lint.ps1` | `shiori.ps1`、`update.ps1` の確認 |
| 動かす華和梨 | 最新（ホームフォルダの `bin/kawari/kosui.exe`） | このゴーストの `shiori.dll` |
| 副作用 | 安全モード: ファイルを書かない、SAORI の実体を作らない、Direct SSTP をしない。`=kis` は実行する | 一時コピーで動かす。SAORI は本当に動く |
| 診断 | `--format json`（常に UTF-8） | 一時コピーの `logfile` |

- kosui.exe は `scripts/tools.json` の `kosui`（`"shiori": "kawari"`、`"version": "latest"`、`"asset": "kawari-*.zip"`、`"minimumVersion": "9.2.0"`）。`setup.ps1` は、`shiori` の付いたツールを、そのゴーストのときだけ取る（`-Tool` で名前を挙げれば、どのゴーストでも取る）。アセット名に版が入るので、`Get-DevkitLatestReleaseAsset` はワイルドカードを受け付ける。zip は中身とダウンロードを比べられないので、入れた kosui.exe のファイルのバージョンと、リリースのタグ（`v9.2.0`）を比べて、古ければ入れ直す。
- kosui の `--check` の text 出力はコンソールのコードページ（CP932）なので使わない。`--format json` を使う。`file` は、引数で相対パスを渡した rcfile（`kawarirc.kis`）は相対、そこから `load` したファイルは絶対パスで来る（`ConvertTo-DevkitKawariPath` が両方をゴーストのルートからの相対にする）。終了コードは 0 なし / 1 警告のみ / 2 エラー / 3 実行できない。
- kosui は引数を ANSI のコードページで読むので、`check-dic.ps1 -Event` が組み立てる `--eval` は ASCII だけを受け付ける。`--eval` の結果は出力されない（診断だけ）。イベントは、本体と同じく `cleartree System.Request` / `System.Response` のあとで `System.Request.ID` などを入れ、`$(get System.Callback.OnGET)` を評価する（`${}` だとコールバックの単語が 1 つしか選ばれない）。
- `check-dic.ps1` は `--no-lint` で動かし、K-W2xxx は `lint.ps1` だけが出す（`check.ps1` で同じものを 2 度出さない）。
- 対話モードの kosui（`--check` なし）は使わない。安全モードではなく、稼動中のゴーストに接続しうるうえ、非 ASCII の入力が化け、エラーも出ない。

## shiori.ps1 の一時コピー

`New-DevkitKawariSandbox` が `ghost/master` を一時フォルダにコピーし（`.git` と `profile/` は除く）、コピーの `kawarirc.kis` に ASCII の行を足す（BOM があればその後ろ。改行はファイルに合わせる。ASCII なので、UTF-8 か Shift_JIS かの判定は変わらない）。

- 先頭: `=kis` / `logfile devkit-kawari-load.log;` / `loglevel error warning;` / `=end`（読み込み中の診断）。
- 末尾: `=kis` / `logfile devkit-kawari-run.log;` / `loglevel ...;` / `=end`。ゴーストが自分で `loglevel` や `logfile` を設定していても、最後のこれが勝つ。`logfile` を切り替えると前のファイルは閉じられる（同じ名前にすると読み込みのログが消えるので、名前を分けている）。
- `-Eval` のときだけ、末尾に `copy System.Callback.OnGET devkit.OnGET; clear System.Callback.OnGET;` と、新しい `System.Callback.OnGET : $(if $[ ${System.Request.ID} == "devkit.eval" ] $(eval ${System.Request.Reference0}) else $(get devkit.OnGET))` を足す。華和梨はコールバックの全単語を評価してつなげるので、元の定義は `$(get ...)` で呼ぶ（`${}` は 1 つしか選ばない）。
- 診断の行番号: 先頭に足した行の数（`HeadLines`）だけ `kawarirc.kis` の行を戻す。元の行数（`RcLines`）より後ろは末尾に足したゾーンなので、`<-Eval of scripts/shiori.ps1>` と表示する。呼び出しの連鎖の中の位置も同じように直す。
- 要求は `Charset: UTF-8`（華和梨は要求の文字コードで応答する。無ければ Shift_JIS）。辞書が `System.Response.Charset` を Shift_JIS にすると応答は Shift_JIS になるが、tamacs.exe は UTF-8 として読むので化ける（`commands.md` に注記だけしてある）。

## tamacs.exe の `--no-loghandler`

`scripts/lib/tamacs.cs` は、`Set_loghandler` の無い dll を終了コード 3 で断る（YAYA と里々の古い dll を見分けるため）。華和梨のためだけに `--no-loghandler` を足し、付けたときだけ `Set_loghandler` なしで動かす。付けないときの動きは変えていない。

## 文字コード

- Phase 9 は、辞書を「BOM があるか、全体が UTF-8 として正しければ UTF-8、そうでなければ Shift_JIS」として読む。古いゴーストの辞書はほとんど Shift_JIS（CRLF）。エージェントのファイル編集は UTF-8 前提なので、Shift_JIS のファイルに UTF-8 の行を足すと、ファイル全体が Shift_JIS として読まれて足した行が化ける。
- doctor の `UTF-8 dictionaries` は、`Get-DevkitKawariDictionaryFiles`（`kawarirc.kis`、ほかの `*.kis`、そこからリテラルの名前で `load` されるファイルを再帰的に。コメント行は除く。`${}` で組み立てた名前は追えない）の中の Shift_JIS のファイルを挙げる。
- `convert-utf8.ps1` は、Shift_JIS → UTF-8 → Shift_JIS で元のバイト列に戻ることを確かめてから、BOM なしの UTF-8 で書く。BOM を付けないのは、暗号化した行（`!KAWA0000` / `!KAWA0001`）が、BOM の無いファイルでは Shift_JIS として復号されるため（付けると壊れる）。変換の前後で `check-dic.ps1` と `lint.ps1` の出力が同じになることを、CLDSP2+（Shift_JIS の辞書 9 個）で確かめた。
- `templates/kawari/editorconfig` は、辞書（`*.kis`、`*.txt`）に `charset` を指定しない（エディタに Shift_JIS のファイルを UTF-8 で保存させないため）。

## update.ps1

- リリースの `kawari-X.Y.Z.zip` から `shiori.dll` だけを取る（zip に辞書は無い）。
- 置き換える前に、新しい dll だけを空の一時フォルダ（何も定義しない `kawarirc.kis`）で読み込ませ、`version`（`OnGET` が空なので華和梨が自分で答える）に応答するかを見る。ゴーストの一時コピーで試さないのは、辞書の `=kis` と `preload` の SAORI が動くから（実在のゴーストには、SAORI 経由で exe を起動するものがある）。
- 辞書の検査（`check-dic.ps1`）は kosui.exe で行い、ゴーストの dll に依存しないので、更新の可否には使わない。置き換えた後に、辞書の状態を見せるために行うだけ。
- Phase 8 から上げるときは、`save` / `savecrypt` が UTF-8（BOM あり）で書くようになり、8.2.9 以前に戻すと読めないことを知らせる。
