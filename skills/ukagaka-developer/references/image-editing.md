# 画像の編集（`scripts/image.ps1`）

シェルの画像を調べる・編集する・比べる・拡大して見るための `scripts/image.ps1` の使い方。手順は `references/workflows/edit-shell-image.md`。`<ps>` は `powershell -NoProfile -ExecutionPolicy Bypass -File` の略。

```
<ps> scripts/image.ps1 info <ファイル>... [-At x,y,x,y...] [-Base <下の画像> [-Offset x,y]]
<ps> scripts/image.ps1 edit <入力> -Out <出力.png> '<操作>' '<操作>' ...
<ps> scripts/image.ps1 view <ファイル>... [-Rect x,y,w,h] [-Zoom 8] [-Grid 10] [-Background checker[,black,...]] [-Out <出力.png>]
<ps> scripts/image.ps1 diff <A> <B> [-Part <出力.png>] [-View] [-Tolerance 0]
```

- 書き出す画像は、元の形式（パレット、RGB、グレースケール、16bit など）にかかわらず、すべて 8bit×4ch の RGBA PNG（カラータイプ 6）になる。完全に透明な画素の色は `#00000000` にそろえる。
- **SSP は、シェルの `descript.txt` に `seriko.use_self_alpha,1`（または `full`）が無いと、PNG のアルファを無視して左上の画素の色を透過色にする**（完全に透明な画素は黒く出る）。`1` にしても、アルファの無い画像は今までどおり左上の色で抜かれる。`edit` の出力先がそういうシェルの中なら、注意を出して終了コード 2 になる。同じ名前の `.pna` が隣にあるときも同じ（アルファと `.pna` のどちらが使われるかは資料に書かれていないので、どちらか一方にする）。
- 入力は PNG（すべてのカラータイプとビット深度、インターレース、tRNS）、BMP、JPEG、GIF。`new:幅x高さ` または `new:幅x高さ:#色` で空の画像から始められる。
- `view` と `diff -View` の出力先は、`-Out` を省くと一時フォルダの `ukagaka-developer/image/`（`view.png`、`diff.png`。毎回上書き）。画像を読めるエージェントが目で確かめるためのもので、目盛りの数字は元の画像の座標。`-Zoom` を省くと 480 ピクセルほどに収まる倍率、`-Grid` を省くと倍率に合った間隔になる。`-Background` は `checker`（市松模様）、`white`、`black`、`#rrggbb`、`alpha`（アルファをグレーで）、`opaque`（アルファを無視した色）、`faint`（市松模様の上に、ほとんど見えない画素（アルファ 1〜15）を赤紫で塗る）。`-Background white,black,checker` のようにカンマで並べると、ファイルごとに 1 行、背景ごとに 1 枚を並べる（白い縁、透けた穴、散った画素は、背景によって見えたり見えなかったりする）。
- `info` は、アルファの内訳（1〜15 のほとんど見えない画素、240〜254 のほとんど不透明な画素など）と、アルファを持つ画像なら見えている画素の島（隣り合う画素のまとまり。2 つ以上あれば小さい順に位置と画素数とアルファの最大）も表示する。差分から切り出したパーツに残った、離れた 1 ドットを見つけるのに使う。`-Base <下の画像>` を付けると、その画像の `-Offset x,y`（既定 0,0。`element` や `animation` に書く座標）に重ねたときに、何画素がどれだけ変わるか、下と同じ色で何も変えない画素、下の画像の透明な所にはみ出す画素、下と大きく違う色を半透明（アルファ 16〜239）で混ぜている画素（縁の継ぎ目になりやすい）を表示する。
- `diff` は同じ大きさの 2 枚を比べ、違う画素の数と範囲（x,y,w,h）、そのうち差が 32 を超える画素の数、最大の差を表示する。`-View` の違いの図では、差が 32 を超える画素を赤、それ以下を黄で塗る。完全に透明な画素どうしは色が違っても同じとみなす。`-Part` は B のうち A と違う画素だけを、その範囲で切り出して書き、貼る位置を表示する（A に `paste` すると B になる。`element` や `animation` のパーツ作りに使う）。
- 引数は PowerShell の外から渡すことを前提にしている（`<ps>` の形）。`-At` と `-Rect` はカンマ区切りの 1 つの値で渡す。

## 操作

1 つの操作を 1 つの引数にする（空白を含むので `'...'` で囲む）。名前、位置で決まる値、`キー=値` のオプションを空白で区切る。空白を含む値は `'...'` か `"..."` で囲む（PowerShell の外からなら `"text 'こんにちは' 5,5"` のように）。座標は左上が 0,0 のピクセル、矩形は `x,y,w,h`、色は `#rgb`、`#rrggbb`、`#rrggbbaa`、`black`、`white`、`transparent`。割合は `0.5` でも `50%` でもよい。未知のオプションや余った値はエラーになる。

| 操作 | 内容 |
|---|---|
| `crop x,y,w,h` | 切り抜く。はみ出した部分は透明 |
| `trim [pad=N] [alpha=N]` | 見えている範囲（アルファが `alpha` より大きい画素）に切り詰める。元の画像のどこを残したかを表示する |
| `canvas WxH [x,y｜center] [color=]` | キャンバスの大きさを変え、今の画像を x,y（既定 0,0）に置く |
| `pad N` / `pad 左,上,右,下 [color=]` | 周りを広げる（負の値で削る） |
| `offset dx,dy` | 大きさはそのままで中身をずらす |
| `resize WxH [filter=]` | 拡大縮小。`200x` や `x100` なら縦横比を保つ。`filter` は `bicubic`（既定）、`lanczos`、`bilinear`、`box`（縮小向き）、`nearest`（ドット絵向き） |
| `scale 倍率 [filter=]` | 倍率で拡大縮小（`0.5`、`200%`） |
| `flip h｜v` | 左右（h）・上下（v）反転 |
| `rotate 角度 [expand=0]` | 時計回りに回す。90 の倍数は劣化しない。それ以外はキャンバスが広がる（`expand=0` で元の大きさ） |
| `paste ファイル [x,y] [mode=] [opacity=]` | 別の画像を重ねる。`mode` は `over`（既定。普通に重ねる）、`under`（下に敷く）、`replace`（アルファごと置き換える）、`erase`（重ねた画像の形に消す）、`clip`（重ねた画像の形だけ残す）、`multiply`（乗算） |
| `colorkey [色｜topleft] [tolerance=N]` | その色（既定は左上の画素の色）を透明にする。アルファの無いシェル画像を 32bit にするときに使う |
| `pna [ファイル]` | `.pna`（グレースケール。白が不透明）を読んでアルファにする。省くと入力と同じ名前の `.pna` |
| `mask ファイル [at=x,y] [channel=alpha｜gray] [invert]` | 別の画像のアルファ（`gray` なら明るさ）をかけて、形を切り抜く |
| `opacity 割合` | 不透明度をかける |
| `threshold N` | アルファを N 以上は不透明、未満は透明の 2 値にする（既定 128） |
| `flatten [色]` | その色（既定は白）の上に重ねて不透明にする |
| `fill 色` / `clear` | 塗りつぶす / 透明にする（`rect=` などで範囲を絞る） |
| `floodfill x,y 色 [tolerance=N]` | x,y とつながった似た色の範囲を塗る（`transparent` で消す） |
| `replace 色 新しい色 [tolerance=N]` | 色を置き換える |
| `adjust [hue=度] [sat=%] [light=%] [bright=%] [contrast=%] [gamma=]` | 色相を回す、彩度・明度・明るさ・コントラストを ±% で変える、ガンマ補正 |
| `colorize 色 [amount=]` | 明暗を保ったままその色に染める |
| `grayscale` / `invert` | グレースケール / 色の反転 |
| `blur 半径` / `sharpen [半径] [amount=]` | ぼかす（ガウス）/ くっきりさせる（アンシャープマスク） |
| `outline 太さ [color=]` | 輪郭の外側に縁取りを付ける |
| `shadow dx,dy [blur=] [color=] [opacity=]` | 影を付ける（キャンバスは広げないので、先に `pad` する） |
| `rect x,y,w,h` / `ellipse x,y,w,h` | 矩形・楕円を描く。`width=` を付けると枠線（矩形の内側に収まる）、付けなければ塗りつぶし |
| `line x1,y1,x2,y2,...` / `polygon x1,y1,x2,y2,x3,y3,...` | 折れ線 / 多角形。座標は画素の中心 |
| `text '文字' x,y [size=] [font=] [bold] [italic] [align=left｜center｜right]` | 文字を描く（`\n` で改行。既定のフォントは Meiryo） |

- 色を変える操作（`fill`、`clear`、`replace`、`adjust`、`colorize`、`grayscale`、`invert`、`opacity`、`blur`、`sharpen`）は、`rect=x,y,w,h` と `mask=ファイル`（そのアルファを重みにする。同じ大きさの画像）で範囲を絞れる。
- 描く操作（`rect`、`ellipse`、`line`、`polygon`、`text`）は、`color=`（既定は黒）、`mode=over｜replace｜erase`（`erase` は描いた形に消す）、`aa=0`（アンチエイリアスなし）を付けられる。
- 半透明の境目がにじまないよう、拡大縮小、回転、ぼかしはアルファを考慮して計算する。
