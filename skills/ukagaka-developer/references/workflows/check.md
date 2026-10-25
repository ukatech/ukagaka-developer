# ゴーストの一括チェック

## 使うとき

作者が「チェックして」「エラーが出ていないか見て」「おかしくない？」「辞書のエラーを直して」「lint かけて」「コミットする前に確認して」と言ったとき。辞書やシェルをまとめて変更した後、コミットや nar 作成の前にも、自分から行ってよい。

## 手順

1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1` を実行する（里々は、名前のある文を 1 回ずつ実行して実行時のエラーも探す `-Run` を付けるとよい）。check-dic、check-shell、（YAYA のみ）lint を順に行う。
   - `skipped (tool not available)` と出た項目は、ツールが入っていないか SSP が見つからない。`scripts/setup.ps1` は作者に一言断ってから実行する。SSP の場所は、ホームフォルダの `local.json` か環境変数 `SSP_PATH` で指定してもらう（`references/commands.md`）。
2. 結果は次の優先順で扱う。
   1. **check-dic の error**: 辞書が正しく読み込まれていない（YAYA は緊急モードで起動してしまう）。最優先で直す。エラーの読み方と直し方は SHIORI ごとに違う: YAYA は `references/yaya/check.md`、里々は `references/satori/check.md`。
   2. **check-shell の Error / Warning**: 直す。`[SERIKO] shell/master/surfaces.txt:Line=123:Surface=10 ...` のように定義位置が出るので、そのファイルと行を直す。二重定義のエラーには、先に定義された側の位置も ` (ファイル名:Line=n)` として付く。位置が出ない（位置の無い種類の Notice）ときは、`Surface=` の番号から探す。Notice（使われていないサーフェスなど）は報告だけにする。シェルの画像そのものは、`GHOST.md` でライセンスを確かめるまで編集しない（改変を禁じているシェルがある。編集の手順は `references/workflows/edit-shell-image.md`）。`surfaces.txt` の重ね合わせ（`element` など）を直したときは、チェックが通っても位置のずれやパーツの抜けは見つからないので、画像を読めるなら `scripts/dump-surface.ps1 -Surface <番号>` で仕上がりを見る。当たり判定（`collision` など）を直したときは `-Collision` を付けて、枠の位置と名前を見る。
   3. **YAYA の lint**: 参考情報。読み方は `references/yaya/check.md`。里々には lint が無い。
3. 直したら 1 をもう一度実行し、error がなくなるまで繰り返す。
   - 辞書の関数やトークを直したときは、`scripts/shiori.ps1` で実際に呼び出す（YAYA: `-Eval '関数名'`、里々: `-Eval '（トークの名前）' -Plain` や `-Event <イベントID>`）。実行時のエラーは、辞書の読み込みのチェックだけでは見つからない。終了コード 2 なら、表示された位置や内容を直す。ファイルの書き込み、外部プログラムの実行、SAORI の呼び出しをするものは本当に動くので、中身を読んで、作者に断ってから呼ぶ。
4. SSP でこのゴーストを動かしている場合は、`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ssp-log.ps1` で実行時のエラーログも見る（終了コード 3 なら SSP が起動していないので飛ばす）。古いエラーも残っているので、直したものは `scripts/sstp.ps1 -Reload ghost` で読み込ませ、新しいエラーが出ないことを確かめる。
5. 最後に、直したことと残っている警告を短くまとめて報告する。

## 関連

- コマンドと終了コードの一覧: `references/commands.md`
- 実機で確かめる: `references/workflows/try-in-ssp.md`
