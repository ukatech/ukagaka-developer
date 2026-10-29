# 里々の更新

- `scripts/shiori/satori/update.ps1` の `satori.zip`（[ukatech/satoriya-shiori](https://github.com/ukatech/satoriya-shiori/releases)）:
  - 中身は `satori.dll`、`satorite.exe`、`saori\ssu.dll`。里々の `CLAUDE.md`（リリース）の手順で、`satoriya\make_satori.ps1` が作る。ssu は `satori.dll` に内蔵されたので、ゴーストに `saori/ssu.dll` が無ければ足さない（Mc201-5 で、ゴースト側の `ssu.dll` と `satori_conf.txt` の ssu の行は不要になった）。
  - バージョン記号は `McXYY-Z`。X = 1 が ACP 版（master ブランチ、`Mc1XX`）、X = 2 が Unicode 版（unicode ブランチ、`Mc2XX`）。タグ名がそのまま記号（`Mc201-5`）で、リリースのタイトルは同じか `Mc172-1A` のような名前になることがある（タグを見る）。**系統（X）で選ぶ。** Unicode 版（Mc2XX）が現行の正式版で、ACP 版（最後は `Mc172-3`）は古い系統。
  - 一覧（`releases?per_page=100`）から `satori.zip` があるものを集め、手元の `satori.dll` と同じ系統で、`(XYY, Z)` がいちばん大きいもの（同じなら日付の新しいもの）を取る。`releases/latest` は系統を見ないので、ACP 版のゴーストにも Unicode 版を選んでしまう。`-StableOnly` は、念のための pre-release 除外で、系統は変えない。
  - 更新されているのは Mc2XX だけ（Mc1XX は致命的な問題のバックポートのみ）。手元が ACP 版で `-Variant Unicode` が無いときは、選ぶ版は変えずに、`current` の後に `NOTICE` の行（Unicode 版への更新の強い推奨）を出す。系統が変わるのは `-Variant` を付けたときだけ。
  - 版は DLL の中の UTF-16 の `phase McXYY-Z`（`gSatoriVersion`）と、ファイルバージョン `X, XYY, Z, 1` の両方から読める（`Get-DevkitSatoriVersion`）。`ssu.dll` には `phase` の文字列が無いので、ファイルバージョンから作る。比べるのは `(XYY, Z)`。
  - ダウンロードは、GitHub がアセットに付ける `digest`（`sha256:…`）と照合する。
  - ghost/master にあるファイルだけを置き換える。`satori.dll` が無いときは `-Force` を要求する（誤って別のフォルダに入れないため）。
  - 置き換えたあとに `check-dic.ps1` を実行し、失敗したら、置き換えたファイルをまとめて戻す（`satori.dll` と `satorite.exe` は一組で更新するので、片方だけ戻さない）。`satori.dll` が使用中（SSP でゴーストが動いている）だと、コピーが失敗する。
  - `-ZipPath` は、ダウンロードの代わりにローカルの `satori.zip` を使う（オフラインの確認用。テストは、一時フォルダにゴーストのコピーを作って `-GhostDir` で向ける）。
  - Windows PowerShell 5.1 の `Invoke-RestMethod` は JSON の配列を 1 つのオブジェクトとして返すので、`foreach` で展開してから見る。
