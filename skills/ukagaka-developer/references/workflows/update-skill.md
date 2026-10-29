# スキル（ukagaka-developer）の更新

スキルは、ゴーストとは別に更新する。ゴーストのフォルダは変わらない（`GHOST.md` も、辞書も、`.narignore` も）。更新で変わるのは、スクリプトと資料だけ。

## 使うとき

作者が「スキルを更新して」「ukagaka-developer を最新にして」「新しいバージョンはある？」と言ったとき。

**作者にはっきり頼まれたときだけ行う。** スキルの更新は、このスキル自身を置き換える。

## 入れ方で更新の方法が違う

| 入れ方 | 更新 |
|---|---|
| Claude Code のプラグイン | `claude plugin update ukagaka-developer`（`--scope` は入れたときと同じ）。マーケットプレイスの最新を取るには、先に `claude plugin marketplace update ukagaka-developer`。更新したら Claude Code を再起動するか `/reload-plugins`。マーケットプレイスの自動更新を有効にしていれば、起動後にバックグラウンドで更新される |
| フォルダのコピー（`.agents/skills/ukagaka-developer/` など） | `scripts/update-skill.ps1`。GitHub の最新を取って、そのフォルダを置き換える |

プラグインを自動で更新する設定は、作者の Claude Code の画面でしかできない（エージェントは設定を変えない）。作者に聞かれたら、次を伝える: `/plugin` を開き、**Marketplaces** タブで `ukagaka-developer` を選び、**Enable auto-update** を選ぶ（外部のマーケットプレイスは、初期状態ではオフ）。次の起動から、バックグラウンドで GitHub の最新に更新される。動いているセッションは読み込み済みの版のままで、`Plugin updated: ukagaka-developer · Run /reload-plugins to apply` と出たら `/reload-plugins` か再起動で反映する。

どちらで入れたか分からなければ、スキルのフォルダのパスで判断する。`.claude/plugins/cache/` の下ならプラグイン、`.agents/skills/` や `.claude/skills/` の下ならコピー。

## コピーで入れたスキルの更新

1. 確認だけを行う（GitHub に問い合わせることを一言伝える）:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-skill.ps1 -DryRun`
   `installed` と `latest` のコミットを見て、新しい版があるかを伝える。
2. 了承を得てから、`-DryRun` を外して実行する。更新するフォルダは、既定ではこのスクリプトのあるスキルのフォルダ。別のフォルダを更新するときは `-Target <スキルのフォルダ>`。特定の版は `-Ref <タグ・ブランチ・コミット>`。
3. 実行中のスクリプトのフォルダを置き換えるので、終わったら、エージェントを再起動して `SKILL.md` を読み直させる。
4. Claude Code のプラグインのキャッシュの中は更新できない（`update-skill.ps1` が止まる）。プラグインは上の方法で更新する。

## 更新の前後で確かめる

- `scripts/doctor.ps1` が通る。
- 更新の内容は https://github.com/ukatech/ukagaka-developer のコミット履歴で見られる。ホームフォルダの `bin/` は、スクリプトのソースが変わると自動で作り直される。

## 関連

- 導入と更新の案内: `README.md`
