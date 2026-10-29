# 里々（satori.dll）の更新

## 使うとき

作者が「里々を更新して」「里々を新しくして」「satori.dll を更新して」「SHIORI を最新に」「里々のバージョンを教えて」と言ったとき。

**作者にはっきり頼まれたときだけ行う（バージョンを聞かれただけなら、`-DryRun` で確認して答える）。自分から始めない。** GitHub からのダウンロードと、`satori.dll` などのファイルの置き換えを伴う。

## 里々のバージョンと 2 つの系統

- バージョン記号は `McXYY-Z`（例: `Mc206-2`）。`X` が 2 なら **Unicode 版**（`Mc2XX`。里々 2。内部を Unicode で扱い、UTF-8 の辞書を読める。現行の系統で、このスキルが前提にしている）、1 なら **ACP 版**（`Mc1XX`。里々 1。システムのコードページで辞書を読む古い系統）。機能を足すと `YY` が上がり、バグ修正で `Z` が上がる。
- 配布は [ukatech/satoriya-shiori](https://github.com/ukatech/satoriya-shiori/releases) のリリースで、`satori.zip` に `satori.dll`、`satorite.exe`、`saori\ssu.dll` が入っている。
- 版は DLL の中の `phase McXYY-Z` という文字列で分かる（`scripts/doctor.ps1` と `scripts/update-shiori.ps1` が表示する）。`scripts/shiori.ps1 -Event version` でも、`phase McXYY-Z` が返る。
- 現行の `satori.dll` は ssu（同梱 SAORI）を内蔵している。`saori/ssu.dll` が無く、`satori_conf.txt` の `＠SAORI` に ssu の行が無くても、`calc` や `if` などの ssu の関数は使える。古いゴーストには `saori/ssu.dll` が残っていることがある。
- 仕様は https://ukatech.shillest.net/satori-docs/ 。里々 2 の紹介は `other/satori2-launch`、Unicode 版と ACP 版の違いと、リリースごとの修正は `other/unicode-changes` にある。

## ACP 版（里々 1）のゴーストでは、里々 2 への更新を強く推奨する

里々の開発チームが更新しているのは Mc2XX だけで、ACP 版（`Mc1XX`）は、致命的な問題があるときに限りバックポートが検討される程度のサポート対象外になっている。`scripts/doctor.ps1` の `ghost files` や `SATORI build` に `phase Mc172-3 (ACP build)` のように出て、`satori.dll` の版が `Mc1XX` と分かったら、作者に里々 2（Unicode 版）への更新を強く推奨する。推奨するだけで、作者が頼むまで更新は始めない。伝えること:

- `satori.dll` を置き換えるだけ（drop-in）で、辞書もセーブデータも、そのまま動く（Shift_JIS の辞書もそのまま読める）。書き直しは要らない。互換性についての報告も、些細なものしか来ていない。
- トークの組み立てが速くなる（大きな辞書では数倍から十数倍）。正規表現（`regex_` 関数）、選択肢の引数、絵文字や UTF-8 の辞書、静的検査 ShioriLint（Mc206-1 以降）が使える。
- 里々 1 の挙動に頼った書き方は、結果が変わる（式の `^` がべき乗になる、`=~` が部分文字列の判定になる、計算が 64 ビットになる、など。`references/satori/dictionary.md` の「里々のバージョン」）。
- 一度里々 2 で起動すると、セーブデータが UTF-8 になり、`satori.dll` の差し替えだけでは戻せない。更新の前に、`satori_savedata.txt` と `satori_savebackup.txt`（暗号化していれば `.sat`）、できればゴースト全体のバックアップを取ってもらう。
- 里々 1 から里々 2 へは、手順の `-Variant Unicode` を付けて更新する（付けないと、手元と同じ ACP 版の最新に更新される）。
- 作者が見送ったら、そのゴーストでは里々 2 の機能（正規表現など）を使わずに作業する。ACP 版に不具合が見つかっても、修正は Mc2XX にだけ入るのが通常であることを伝える。

## scripts/update-shiori.ps1 がすること（里々）

- `satori.zip` を、リリースから取る（または `-Tag` で指定した版）。ダウンロードは GitHub が公開している SHA256 と照合する。
- どのリリースを取るか: **手元の `satori.dll` と同じ系統**（`Mc2XX` なら Unicode 版、`Mc1XX` なら ACP 版）で、いちばん新しい版。プレリリースも対象にする（`-StableOnly` で除く）。`satori.dll` が無いときは Unicode 版。`-Variant Unicode` / `-Variant Acp` で系統を切り替える。
- 置き換えるファイル: **ゴーストにあるものだけ**。`satori.dll`、`satorite.exe`、`saori/ssu.dll`（無ければ足さない）。`satori.dll` が無いゴーストに入れるときだけ `-Force` が要る。
- 手元が ACP 版のときは、`NOTICE` の行で Unicode 版への更新を強く推奨する旨を表示する（挙動は変わらない。`-Variant Unicode` を付けたときは出ない）。作者への推奨に使う。
- 更新前後の版（`current` / `new`、各ファイルの `Mc201-5 -> Mc201-5`）を表示する。手元より古いリリースは、`-Tag`、`-Variant`、`-Force` のどれかを付けないかぎり入れない。
- 置き換えたあとに `scripts/check-dic.ps1` を実行する。失敗したら、置き換えたファイルを元に戻す。
- 終了コード: 0 更新した・最新だった・確認のみ / 1 失敗。

## 手順

1. 確認だけを行う（GitHub からダウンロードすることを一言伝える。作者が版を指定したときだけ `-Tag <タグ>` を付ける。系統の切り替えを望んだときだけ `-Variant` を付ける）:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -DryRun`
   次を短くまとめて伝える。
   - 今の版（`current`）と更新先（`release`、`new`）。
   - 各ファイルの動作（`same` / `replace`）。
   - `-Variant` で系統を変えるとき: `this switches from the … build` の注意が出る（下の「系統を切り替えるとき」）。
2. `already up to date` なら、そのことを伝えて終わる。
3. SSP でこのゴーストを起動していると、`satori.dll` が使用中で置き換えられない。ゴーストを終了してもらう。
4. 了承を得てから、`-DryRun` を外して実行する。
5. 変わったことを伝える。
   - 出力の `notes` のリリースノートと、`satori-docs` の `other/unicode-changes`（`McXYY-Z での修正`）を読み、挙動が変わる修正があれば要約する。
6. 確かめる。
   - `scripts/check-dic.ps1 -Run` は、名前が単純な文を全部実行するので、版が上がって展開の挙動が変わっていないかを見つけやすい。
   - `scripts/shiori.ps1 -Event OnBoot` と `-Event OnTalk` が応答を返すこと。
   - 作者が SSP で試したいと言えば、`references/workflows/try-in-ssp.md` の手順で起動する。
7. git の作業コピーなら、変更をコミットするか聞く（勝手にコミットしない）。`satori.dll` などのバイナリなので、コミットメッセージにバージョン（`satori.dll を Mc201-5 に更新` など）を書くと後で追える。
8. ネットワーク更新で配布しているゴーストなら、`scripts/build-nar.ps1 -UpdateOnly` で更新ファイルを作り直すことを提案する（`references/workflows/build-nar.md`）。

## 系統を切り替えるとき（ACP 版 ↔ Unicode 版）

- Unicode 版は、辞書・`replace.txt`・セーブデータを、UTF-8（BOM の有無を問わない）か Shift_JIS のどちらでも読み、セーブデータは常に UTF-8 で書く。ACP 版は、システムのコードページ（日本語 Windows なら Shift_JIS）で読み書きする。一度 Unicode 版で保存したセーブデータを ACP 版に戻すと、文字化けする可能性がある。
- このゴーストの `descript.txt` が `charset,UTF-8` なら、Unicode 版が前提（`scripts/doctor.ps1` の `SATORI build` がそれを見ている）。ACP 版へ戻すことを頼まれたら、辞書と `descript.txt` の文字コードも Shift_JIS に戻す必要があることを、先に伝える。
- 文字数とバイト数の扱いなど、動作の違いは `satori-docs` の `other/unicode-changes` にまとまっている。

## 関連

- コマンドと終了コードの一覧: `references/commands.md`
- 辞書のチェック: `references/workflows/check.md`
- 里々のリリース手順とバージョン記号: https://github.com/ukatech/satoriya-shiori （`CLAUDE.md` の「リリース」）
