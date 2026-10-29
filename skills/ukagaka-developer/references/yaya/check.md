# YAYA のチェック結果の読み方

`scripts/check.ps1`（`check-dic.ps1`、`lint.ps1`）と `scripts/shiori.ps1` の出力の扱い。全体の手順は `references/workflows/check.md`。

## check-dic

tamacs.exe で `yaya.dll` に辞書を実際に読み込ませ、YAYA が出す `[FATAL]` / `[ERROR]`（読み込みエラーと文法エラー）を表示する。`-Level warning` や `note` で警告も見られる。エラーがあると、ゴーストは緊急モードで起動し（イベントに `204 No Content` しか返さなくなる）、ほとんど話さなくなる。最優先で直す。

- 表示は `ファイル:行` の形で位置が出る。そのファイルと行を直す。
- yaya.dll が古くて `Set_loghandler` が無いと、`SKIPPED`（終了コード 3）になる。更新するかは作者に確かめる（`references/yaya/update.md`）。
- 辞書の読み込みで見つかるのは、文法などの誤りだけ。存在しない関数の呼び出し（E0071 など）のような**実行時のエラーは、関数を実行しないと見つからない**。直した関数は `scripts/shiori.ps1 -Eval '関数名'` で呼び出す。

## lint（`scripts/lint.ps1`）

システム辞書の `SHIORI3FW.Lint.Run`（yaya-dic の `yaya_base/lint.dic`）が、yaya.dll の `LINT.*` 関数で辞書を調べる。参考情報で、見つけたものは `ファイル:行: 種類 '名前' in 関数名` の形で出る。桁は出ない。

- **`read undefined variable` / `read undefined local variable`**: 打ち間違い（`did you mean:` に候補が出る）や、ブロック `{ }` の中で作ったローカル変数をブロックの外で読んでいる可能性が高い。前後を読んで確かめてから直す。
- **`assignment in condition`**: `==` の書き間違いのことが多いので確かめる。
- **`unused function / variable / local variable`**: 報告だけにして、勝手に消さない。
- 文字列の中で組み立てた名前（`EVAL('Mouse' + _part)` など）で呼ばれる関数は、未使用に見える。そういう関数は、辞書に `OnSHIORI3FW.Lint.UsedFunctions` という関数を書き、名前の正規表現の配列を返すと報告されなくなる（グローバル変数は `OnSHIORI3FW.Lint.UsedVariables`）。例: `OnSHIORI3FW.Lint.UsedFunctions { (IARRAY, '^Mouse', '^TalkTo') }`。作者に確かめてから足す。
- `lint: SKIPPED` のときは、yaya.dll かシステム辞書が古い。更新するかは作者に確かめる（`references/yaya/update.md`）。

## 600 系で増えた警告

関数を実行したときに出る警告なので、辞書を読み込むだけの `check-dic` では見つからない。`shiori.ps1 -Eval '関数名' -Level warning` のように、警告まで表示して実行する（終了コードは 2 になる）。

- **W0016 / W0017**: 正規表現の誤り（パターンの構文、`(?&名前)` の名前を解決できない。`ファイル(行) : warning W0016 : 正規表現に誤りがあります. 処理されませんでした. : RE_SEARCH` の形で出る）/ バックトラックの回数が上限を超えた。どちらもマッチしなかったものとして扱われる（`GETLASTERROR` が 16 / 17）。パターンを確かめる（`references/yaya/dictionary.md` の「正規表現」）。
- **W0024**: ハッシュを `-` `*` `/` `%` に使った。意味のある結果にならないので、書き方を見直す。
- **W0025 〜 W0027**: ファイルを開けない / JSON、XML、YAML、TOML を解析できない / それらに変換できない。

## shiori.ps1 のエラー

`-Eval` や `-Event` の後に、その処理で YAYA が出したエラーが表示され、終了コードが 2 になる。`-Eval` が失敗したときは、結果がコードそのものになる。ファイルの書き込みや外部プログラムの実行をする関数は本当に動くので、中身を読んでから呼ぶ。

## 関連

- コマンドと終了コード: `references/yaya/commands.md`
- YAYA の文法と関数: https://yaya-shiori.github.io/yaya-docs/
