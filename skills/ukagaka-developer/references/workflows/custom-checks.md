# ゴースト固有の点検（`.github/ghost-checks.json`）

スキルが調べるのは、辞書の読み込み、シェル、書き方の誤り（lint）まで。「トークの書き方の決まり」「使わない言葉」「ファイル同士の対応」のような、そのゴーストだけの決まりは、ゴーストの側にスクリプトを置いて、`.github/ghost-checks.json` に登録する。登録すると、ローカルの点検（`scripts/check.ps1`）でも、GitHub Actions の辞書チェック（`auto check`）でも、同じ点検が回る。

## 使うとき

作者が「このゴーストの決まりを自動で確かめたい」「同じ間違いを繰り返さないように、点検を足したい」「トークの書き方のチェックを CI に入れたい」と言ったとき。決まりが `GHOST.md` に書いてあり、機械で判定できる（正規表現で数えられる、ファイルの有無で決まる、など）なら、提案してよい。

## 登録の書き方

ゴーストのルートの `.github/ghost-checks.json`（`.github/` は `.narignore` で nar から除かれる）。

```json
{
  "checks": [
    {
      "name": "half",
      "description": "最初に話すスコープに \\n\\n[half] を付けない",
      "command": "python -I -X utf8 work/check/check-half.py"
    }
  ]
}
```

| 項目 | 内容 |
|---|---|
| `name` | 点検の名前。必須。重複させない |
| `command` | 実行する 1 行のコマンド。必須。**ゴーストのルートで**実行される |
| `description` | 一覧に出す説明。省略できる |
| `ci` | `false` にすると GitHub Actions では実行しない（SSP や手元のツールが要る点検に使う）。省略は `true` |

- コマンドは PowerShell の 1 行。PC では Windows PowerShell 5.1、GitHub Actions では pwsh で動くので、**どちらでも動く書き方**にする。複雑なものは、スクリプトに書いて 1 行で呼ぶ。
- 結果は終了コードで返す: `0` = 問題なし、`3` = 確かめられない（必要なツールが無い。飛ばす）、それ以外 = 失敗。
- コマンドには環境変数 `DEVKIT_GHOST_ROOT`（ゴーストのルート）と、`-Ci` のとき `DEVKIT_CI=1` が渡る。GitHub Actions では `GITHUB_ACTIONS=true` なので、スクリプトが `::error file=...,line=...::メッセージ` を出すと、注釈になる。
- 標準出力の文字コードは UTF-8 で受ける（Python は `-X utf8`。`-I` は `PYTHONUTF8` などの環境変数を無視するので、環境変数に頼らない）。
- ファイルが無い、`checks` が空なら、何もしない（従来どおり）。JSON が壊れている、`name` か `command` が無い、`name` が重複している場合は失敗（終了コード 1）。

## 実行と許可

登録されたコマンドは**そのゴーストのプログラム**なので、置いてあるだけでは PC で実行されない。

- `scripts/check.ps1` は、登録があると最後に `check-custom` を呼ぶが、**コマンドの一覧を表示するだけ**（終了コード 3、`skipped` と出る）。
- 実行するのは `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-custom.ps1 -AllowCustom`。**先に `.github/ghost-checks.json` と、コマンドが呼ぶスクリプトを読み**、読み取りだけで PC に影響しない（ファイルを書き換えない、外部プログラムを動かさない、ネットワークに出ない）と確かめてから付ける。迷うときは作者に確かめる。他人のゴーストを預かったときは特に。
- `-AllowCustom` を付けた `check.ps1` は無い。`check.ps1` は一覧だけで、実行は必ず `check-custom.ps1` で行う。
- GitHub Actions（`GITHUB_ACTIONS=true`）では、自分のリポジトリの CI なので、`-AllowCustom` なしで実行される。`-Ci` は注釈を出すだけで、許可の代わりにはならない。

## GitHub Actions に入れる

`templates/github/auto_check.yml` には、辞書チェックのあとに `check-custom.ps1 -Ci` の step がある（登録が無いゴーストでは 1 行出して終わる）。この step が入る前に作ったゴーストの `auto_check.yml` には自動では入らないので、`references/workflows/ci.md` の「ゴースト固有の点検」に沿って足す。

## 点検を足す手順

1. 決まりを機械で判定できる形にする（何を誤りとするか、誤検出しない条件）。
2. ゴーストの側に、`work/check/` のような場所へスクリプトを置く。**開発用のファイルは nar に入れない**（`.narignore` の `/work/` など）。ASCII 以外を書くなら UTF-8（BOM なし）にし、PowerShell なら 5.1 で文字化けしないように ASCII だけで書く。
3. 現状のゴーストで 0 件になること（既存の誤りは、先に直すか、点検に例外を持たせる）、わざと誤りを入れたサンプルで失敗することを、両方確かめる。
4. `.github/ghost-checks.json` に登録し、`scripts/check-custom.ps1 -AllowCustom` を実行する。
5. 決まりを `GHOST.md` にも書き、点検の使い方を 1 行添える。

## 関連

- `references/workflows/check.md`: 一括チェックの手順
- `references/workflows/ci.md`: GitHub Actions
- コマンドと終了コード: `references/commands.md`
