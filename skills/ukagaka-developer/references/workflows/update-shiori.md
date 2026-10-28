# SHIORI（yaya.dll、satori.dll、華和梨の shiori.dll）の更新

## 使うとき

作者が「SHIORI を最新にして」「SHIORI を更新して」と言ったとき。YAYA、里々、華和梨と名指しされたときは、それぞれの手順書を読む。

- YAYA（`yaya.dll` と、システム辞書 yaya-dic。「YAYA を更新して」「システム辞書を更新して」「YAYA 6（600 系）にして」）: `references/yaya/update.md`
- 里々（`satori.dll` と `satorite.exe`。「里々を更新して」「里々のバージョンを教えて」）: `references/satori/update.md`
- 華和梨（`shiori.dll`。「華和梨を更新して」「華和梨 9 にして」「華和梨のバージョンを教えて」）: `references/kawari/update.md`

## 共通のこと

- **作者にはっきり頼まれたときだけ行う（バージョンを聞かれただけなら、`-DryRun` で確認して答える）。自分から始めない。** GitHub からのダウンロードと、dll などのファイルの置き換えを伴う。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -DryRun` で、ゴーストの SHIORI に合わせた確認ができる。`-DryRun` を外して実行すると、置き換えた後に辞書チェック（`check-dic`）を行い、失敗したら元に戻す。オプションは SHIORI ごとに違う（`references/yaya/commands.md`、`references/satori/commands.md`、`references/kawari/commands.md`）。
- SSP でそのゴーストが動いていると dll が使用中で置き換えられない。ゴーストを終了してもらう。
- 更新の後は、辞書チェックのほか、作者に SSP で起動して確かめてもらう（`references/workflows/try-in-ssp.md`）。git の作業コピーなら、変更をコミットするか聞く（勝手にコミットしない）。
