# 華和梨（shiori.dll）の更新

## 使うとき

作者が「華和梨を更新して」「shiori.dll を更新して」「華和梨 9 にして」「SHIORI を最新に」「華和梨のバージョンを教えて」と言ったとき。`scripts/doctor.ps1` の `KAWARI Phase 9` や `KAWARI up to date` が missing のときに、作者に提案するのもここ。

**作者にはっきり頼まれたときだけ行う（バージョンを聞かれただけなら、`-DryRun` で確認して答える）。自分から始めない。** GitHub からのダウンロードと、`shiori.dll` の置き換えを伴う。

## 華和梨の版

- 現行は **Phase 9**（9.2.0 など）。Phase 9 は Phase 8（8.2.x）の置き換えで、辞書・SAORI・本体との連携を書き換えずに、`shiori.dll` を差し替えるだけで動く。このスキルのスクリプトは Phase 9 を前提にしている。
- 版は `shiori.dll` のファイルのバージョン情報（8.2.9 から付いた）で分かる（`scripts/doctor.ps1` と `scripts/update-shiori.ps1` が表示する）。バージョン情報の無い `shiori.dll` は 8.2.8 以前。辞書からは `$(ver)`（`KAWARI.kdt/9.2.0`）、`scripts/shiori.ps1 -Event version`（辞書が `version` に答えていなければ `9.2.0`）でも分かる。
- **Phase 7 以前**（`kawari.ini` に `dict :` などが並び、`kawarirc.kis` が無い。版の文字列が `KAWARI.kpcg/7.3.1` など）は、Phase 8 以降と辞書の書き方が違い、差し替えでは動かない。移行は辞書の書き直しになる（https://ukatech.shillest.net/kawari-docs/migration/ ）。このスキルは対象にしていない。作者に伝えて、どうするか決めてもらう。
- 配布は [ukatech/kawari](https://github.com/ukatech/kawari/releases) のリリースで、`kawari-X.Y.Z.zip` に `shiori.dll`、`kosui.exe`、`kawari_encode.exe`、`kawari_encode2.exe`、`kawari_decode2.exe`、`license.txt`、`readme.1st` が入っている。辞書やミドルウェアは入っていない。更新履歴は https://ukatech.shillest.net/kawari-docs/other/changelog/ 。

## Phase 8 から 9 に上げるときに伝えること

`-DryRun` の結果と合わせて、作者に伝えてから進める。

- `save` / `savecrypt` が書くセーブファイルが UTF-8（BOM あり）になる。Phase 9 は Phase 8 のセーブを読めるが、**Phase 9 が書いたセーブを Phase 8.2.9 以前に戻すと読めない**。元に戻す可能性があるなら、セーブファイル（辞書が `save` で書いているファイル。`GHOST.md`）を先にバックアップしてもらう。
- `textsave` / `textappend` / `logfile` は UTF-8（BOM なし）で書く。
- SHIORI の応答に `Charset` が付く。文字列の大小比較とエントリの列挙順が Unicode の順になる（ASCII だけなら変わらない）。
- 不具合の修正で、偶然動いていた異常な書き方の結果が変わることがある。

## scripts/update-shiori.ps1 がすること（華和梨）

- 最新のリリース（または `-Tag v9.2.0` で指定した版）の `kawari-X.Y.Z.zip` を取り、GitHub が公開している SHA256 と照合する。`-ZipPath` で手元の zip も使える。
- **`ghost/master/shiori.dll` だけ**を置き換える。kosui.exe（辞書の検査）は `scripts/setup.ps1` が更新する（`-Tool kosui -Force`）。
- 更新前後の版を表示する。手元より古いリリースは、`-Tag` か `-Force` が無ければ入れない。
- 置き換える前に、新しい `shiori.dll` を空の一時フォルダ（何も定義しない `kawarirc.kis` だけ）で読み込ませて `version` を問い合わせる。ゴーストの辞書や SAORI は動かさない。応答しなければ何も変えない。
- 置き換えた後に `scripts/check-dic.ps1` を行い、辞書の状態を見せる。この検査は kosui.exe（最新の華和梨）で行うので、新しい `shiori.dll` の良し悪しは決めない（エラーが出たら、更新の前からあったもの）。
- 終了コード: 0 更新した・最新だった・確認のみ / 1 失敗。

## 手順

1. 確認だけを行う（GitHub からダウンロードすることを一言伝える。作者が版を指定したときだけ `-Tag` を付ける）:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -DryRun`
   今の版（`current`）と更新先（`release`、`new`）を伝える。Phase 8 からなら、上の「Phase 8 から 9 に上げるときに伝えること」も。
2. `already up to date` なら、そのことを伝えて終わる。
3. SSP でこのゴーストを起動していると、`shiori.dll` が使用中で置き換えられない。ゴーストを終了してもらう。
4. 了承を得てから、`-DryRun` を外して実行する。
5. 変わったことを伝える。出力の `notes` のリリースノートと、kawari-docs の `other/changelog.md` を読み、挙動が変わる修正があれば要約する。
6. 確かめる。
   - `scripts/check.ps1`。
   - `scripts/shiori.ps1 -Event OnBoot` が応答を返すこと（SAORI を使うゴーストは、中身を確かめてから）。
   - 作者が SSP で試したいと言えば、`references/workflows/try-in-ssp.md` の手順で起動する。
7. git の作業コピーなら、変更をコミットするか聞く（勝手にコミットしない）。バイナリなので、コミットメッセージに版（`shiori.dll を華和梨 9.2.0 に更新` など）を書くと後で追える。
8. ネットワーク更新で配布しているゴーストなら、`scripts/build-nar.ps1 -UpdateOnly` で更新ファイルを作り直すことを提案する（`references/workflows/build-nar.md`）。
9. Shift_JIS の辞書が残っていれば（`scripts/doctor.ps1` の `UTF-8 dictionaries`）、UTF-8 への変換を提案してよい（`references/kawari/dictionary.md` の「文字コード」）。Phase 9 にしてからでないと変換できない。

## 関連

- コマンドと終了コードの一覧: `references/kawari/commands.md`
- 辞書のチェック: `references/workflows/check.md`
- 華和梨 8 からの乗り換え: https://github.com/ukatech/kawari の README.md
