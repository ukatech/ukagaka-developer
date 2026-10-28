# 華和梨のコマンド

華和梨のゴーストで、`check-dic` `shiori` `lint` `update-shiori` が実行する `scripts/shiori/kawari/` の使い方。共通のコマンドは `references/commands.md`。`<ps>` は `powershell -NoProfile -ExecutionPolicy Bypass -File` の略。

対象は `shiori.dll` が **華和梨 Phase 9** のゴースト（`ghost/master/shiori.dll` と `kawarirc.kis` がある）。Phase 8 のゴーストは、`shiori.dll` を Phase 9 に差し替えれば辞書はそのまま動く（`references/kawari/update.md`）。Phase 7 以前（`kawari.ini` だけで `kawarirc.kis` が無い）は対象外。

辞書の検査には **kosui.exe**（華和梨のコンソール版。`--check` は Phase 9.2.0 から）を使う。`<ps> scripts/setup.ps1` が、[ukatech/kawari](https://github.com/ukatech/kawari/releases) の最新リリースからホームフォルダの `bin/kawari/` に入れる（作者に一言断ってから実行する）。

| コマンド | 内容 | 終了コード |
|---|---|---|
| `<ps> scripts/check-dic.ps1` | `kosui --check` で `ghost/master/kawarirc.kis` と、そこから読む辞書を**安全モード**で読み込み（ファイルを書かない、SAORI を読まない、SSP に送らない。`=kis` は実行する）、エラーと警告を `ghost/master/dict.txt(12): error K-E0013: 内容` の形（呼び出しの連鎖つき）で表示する。静的検査（K-W2xxx）は `lint.ps1` に任せる。`-Event OnBoot,OnClose` で、読み込みの後にイベントを SSP と同じ形で実行して、実行時のエラーも探す（安全モードのまま。`-Reference '0,0,0,0,Head'`）。`-Decl` で空のエントリの読み出し（K-W0003）も、`-Strict` で警告も失敗にし、`-Ci` で GitHub Actions の注釈を出す | 0 OK / 1 エラー / 3 確かめられない（kosui.exe が無い、古い） |
| `<ps> scripts/lint.ps1` | 辞書を**実行せずに**調べる。`kosui --check` の静的検査で、どこにも定義されていないエントリの参照（K-W2001）、未知のコマンド名（K-W2002）、`regex_*` の引用符の無い括弧と `${N}`（K-W2003 / K-W2004）を、イベントでしか呼ばれない単語も含めて全部探す。誤りでない指摘は、その行の上に `# lint:disable-next-line=K-W2001` と書いて抑える。`-Strict` で指摘を失敗にする。`check.ps1` の最後の手順でもある。読み方は `references/kawari/check.md` | 0 OK（`-Strict` なら指摘が無い）/ 1 `-Strict` で指摘があった、kosui.exe が調べられなかった / 3 kosui.exe が無い、古い |
| `<ps> scripts/shiori.ps1 -Eval '${sentence}'` | SSP を使わずに、tamacs.exe でこのゴーストの `shiori.dll` に SHIORI リクエストを 1 回送る。`-Eval` は華和梨の文字列（辞書の単語と同じ書き方: `${エントリ}`、`$(コマンド ...)`、`$[ 式 ]`）を評価して結果を表示する（下の「華和梨の文字列を試す」）。`-Event <ID> -Reference '0,0,0,0,Head'` は SSP と同じ形の GET（`-Notify` で NOTIFY）、`-Request` は生のリクエスト。呼ぶたびに `ghost/master` の一時コピーで辞書を読み込み直す（`OnBoot` などは先に送らない）ので、セーブファイルなどは変わらない。応答のあとに、その処理で華和梨が出したエラー・警告を表示する（`-Decl` で K-W0003 も） | 0 / 1 失敗（応答が無い、エラー応答など）/ 2 処理中に華和梨がエラーか警告を出した / 3 tamacs.exe をビルドできない、`shiori.dll` が Phase 9 でない |
| `<ps> scripts/update-shiori.ps1` | `ghost/master/shiori.dll` を、[ukatech/kawari](https://github.com/ukatech/kawari/releases) の最新リリース（`kawari-X.Y.Z.zip`）のものに更新する（`-Tag v9.2.0` で版を指定）。更新の前後の版（ファイルのバージョン情報。8.2.8 以前には無い）を表示し、置き換える前に、新しい `shiori.dll` を空の一時フォルダで読み込ませて応答を確かめ（ゴーストの辞書や SAORI は動かさない）、だめなら何も変えない。置き換えた後に辞書チェックの結果を見せる。`-DryRun`（`-WhatIf`）で確認のみ、手元より古い版は `-Tag` か `-Force` が無ければ入れない。手順は `references/kawari/update.md` | 0 / 1 失敗 |
| `<ps> scripts/shiori/kawari/convert-utf8.ps1` | Shift_JIS の辞書（`kawarirc.kis` と、そこから名前を書いて `load` しているファイル、ほかの `*.kis`）を、BOM なしの UTF-8 に変換する。既定は確認のみで、`-Apply` で変換する（元のファイルはホームフォルダの `backups/` に退避）。文字と改行は変えない。`shiori.dll` が Phase 9 でなければ止まる。**作者の了承を得てから**行う。理由は `references/kawari/dictionary.md` の「文字コード」 | 0 / 1 失敗、変換できないファイルがあった |

## 華和梨の文字列を試す（`scripts/shiori.ps1`）

`-Eval` は、渡した文字列を、辞書の単語と同じように評価させる（`$(eval ...)`）。SSP もゴーストの起動も要らない。

```
<ps> scripts/shiori.ps1 -Eval '$[ 1 + 2 ]'                          → 3
<ps> scripts/shiori.ps1 -Eval '${sentence}'                         → エントリ sentence の単語を 1 つ選んで評価する
<ps> scripts/shiori.ps1 -Eval '$(get event.OnBoot)'                 → 全部の単語を評価してつなげる
<ps> scripts/shiori.ps1 -Eval '$(size user) $(date %Y/%m/%d)'       → KIS のコマンド
<ps> scripts/shiori.ps1 -Event OnBoot                               → イベントとして実行する（System.Callback.OnGET を通る）
<ps> scripts/shiori.ps1 -Event OnSecondChange -Reference '0,0,0,1'  → Reference を付ける
<ps> scripts/shiori.ps1 -Event version                              → On で始まらない ID はリソースとして送る
```

- `-Eval` は 1 行（改行は空白にする）。一時コピーの `kawarirc.kis` の最後で `System.Callback.OnGET` を包み、ID `devkit.eval` のときだけ文字列を `eval` で評価し、それ以外は元の `OnGET` に渡す。ほかの要求の動きは変わらない。
- 評価は、辞書の読み込みが終わった直後の状態で行われる（`OnBoot` などのイベントは送っていない。イベントで値を入れるエントリは空のまま）。`setstr` などで変えた値は次の呼び出しに残らない（一時コピーで動かすため）。
- 結果は、華和梨が返した文字列そのまま（さくらスクリプト）。`urllist` などが使うバイト値 1・2 は `<01>` `<02>` と表示する。
- 辞書が `System.Response.Charset` を Shift_JIS にしているゴーストでは、応答の日本語が化けて表示される（tamacs.exe は応答を UTF-8 として読む）。
- `-Event` の ID がどのエントリに届くかは、ゴーストの `System.Callback.OnGET` の振り分けしだい（`references/kawari/dictionary.md`、`GHOST.md`）。
- 実行は `ghost/master` の一時コピーで行うので、セーブファイルや本物のフォルダは変わらない。ただし辞書のコードと `shiori.dll` は本物で、**安全モードではない**。`saoriregist ... preload` の SAORI は読み込まれ、`callsaori` は本当に SAORI を呼ぶ。

`-Eval` と `-Event` は任意の華和梨のコードを実行できる。SKILL.md の `allowed-tools` で、スキルを使っているターンの間は確認なしで実行できる（許可は次のメッセージで切れる。ずっと許可するには、README.md の「許可の確認を減らす」）。SAORI の呼び出しや本体との通信（`executesstp` など）を含むものは、中身を読んでから呼ぶこと。安全に実行時のエラーだけを見るなら、`scripts/check-dic.ps1 -Event <ID>`（安全モード）を使う。
