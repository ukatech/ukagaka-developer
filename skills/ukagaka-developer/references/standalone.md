# テンプレートから独立させるとき

テンプレートやサンプルゴーストとして配られているゴーストを改造して、自分のゴーストとして配布するときは、少なくとも次を変える。そのゴースト固有の項目は、`GHOST.md` に書かれている（「テンプレートから独立させるときの追加項目」の節）。作者に何を聞き、どの順で進めるかは `references/workflows/new-ghost.md` にある。

- [ ] `ghost/master/descript.txt`: `name`、`sakura.name`、`kero.name`、`craftman`（半角英数）、`craftmanw`、`craftmanurl`、`id`（あるとき）
- [ ] `install.txt`: `name`、`directory`（インストール先のフォルダ名。半角英数で、他のゴーストと重ならないもの）
- [ ] ネットワーク更新の URL（YAYA は `On_homeurl`、里々は `＠homeurl`、華和梨は `homeurl` を返すエントリ（`resource.homeurl` など）。ゴーストによって場所が違う）。自分の URL に変えるか、更新しないなら消す。**元の URL のまま配布すると、元のゴーストの更新で、改造した内容が上書きされてしまう。**
- [ ] シェル: 元のシェルの利用条件を `GHOST.md` で確かめる。改変した画像の配布が許されていなければ、自作のシェルか利用許可のあるシェルに差し替え、シェルの `descript.txt`（`name`、`craftman` など）も変える。
- [ ] `readme.txt`、`README.md`、`thumbnail.png`（または `.pnr`）、`delete.txt`（元のゴーストの更新用なので、自分のゴーストに合わせて見直す）。原作者の readme は、謝辞やクレジットを残して書き直す。
- [ ] 名前やキャラクター設定に関わる台詞（初回起動の自己紹介、ランダムトーク、マウスへの反応など）
- [ ] 使わない実験用の辞書や SAORI（里々のサンプルゴーストにある）
- [ ] SHIORI のライセンス文書: 里々は `satori_license.txt` を、`satori.dll` を同梱する限り残す（里々のライセンスは変えてはならない。辞書などは対象外）
- [ ] `GHOST.md` を、自分のゴーストの内容に書き直す
- [ ] GitHub の自動リリースなど、元のゴーストから引き継いだワークフロー（`references/workflows/ci.md`）
- [ ] 元にしたテンプレートと SHIORI のクレジット（義務ではないが、慣習としておすすめ）
