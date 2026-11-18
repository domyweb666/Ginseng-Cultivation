"""方案 B：AI 圖生影片（MiniMax H3，首尾幀都放煉氣男原圖，5 秒），再縮回 168×210 像素格。

做法：
  1. 影片每 0.15 秒取一張（app 播放的速度），每格取正中央那一點縮回 168×210，收回 14 張共用的色盤。
     縮放比例先用第一張對原圖找（影片是 1440×1792，跟 1008×1260 的原圖比例差一點點）。
  2. 防閃：先找出整段影片裡「曾經動過」的範圍（所有格聯集，再往外長幾格），範圍外一律用原圖，背景就不會閃。
     範圍裡整塊用影片的，不逐格挑：逐格挑會把原圖和影片拼在一起，頭會出現疊影、提起來的桶碎成幾塊（第一版踩到）。
     範圍裡再做一層「黏住」：跟上一格差很少的格子沿用上一格的顏色，靜止的衣服才不會因為影片雜訊一直跳色。
  3. 做出跟方案 A 同一段（掂桶）的對照：GIF 與特寫。

用法：python video_to_pixels.py
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, ROOT)
import animate as A          # noqa: E402
import pixelate2 as px       # noqa: E402
from rig import GH, GW, grow, shrink   # noqa: E402

FOLDER = os.path.join(ROOT, '造型風格', '動畫_新去背')
FPS = 24
STEP_S = 0.15
MOVED = 25         # 跟原圖差多少（Lab 距離）才算動了。60 太嚴：木桶深棕對淺色石階只差 50 上下，桶提走了還留在原地
REGION_GROW = 4    # 動過的範圍往外多長幾格
STICKY = 14        # 跟上一格差不到這麼多（Lab 距離）就沿用上一格的顏色


def lab(rgb):
    return px.rgb2lab(np.clip(rgb, 0, 255).reshape(-1, 3)).reshape(rgb.shape)


def sample(im, sx, sy, ox, oy):
    h, w = im.shape[:2]
    ys = np.clip(((np.arange(GH) + 0.5) * sy + oy).astype(int), 0, h - 1)
    xs = np.clip(((np.arange(GW) + 0.5) * sx + ox).astype(int), 0, w - 1)
    return im[ys][:, xs]


def main():
    base, pal = A.load(FOLDER, 'r0')
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    quant = lambda rgb: pal[px.nearest(px.rgb2lab(np.clip(rgb, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)].astype(np.float32)
    files = sorted(glob.glob(os.path.join(HERE, 'frames', 'f*.png')))
    first = np.asarray(Image.open(files[0]).convert('RGB')).astype(np.float32)
    h, w = first.shape[:2]

    # 1. 找縮放：讓第一張縮回來跟原圖最像
    best = None
    for sx in np.arange(w / GW - 0.12, w / GW + 0.121, 0.02):
        for sy in np.arange(h / GH - 0.12, h / GH + 0.121, 0.02):
            for ox in range(-6, 7, 2):
                for oy in range(-6, 7, 2):
                    d = np.abs(quant(sample(first, sx, sy, ox, oy)) - base).sum(-1)
                    same = (d == 0).mean()
                    if best is None or same > best[0]:
                        best = (same, sx, sy, ox, oy)
    print('mapping', best)
    _, sx, sy, ox, oy = best

    # 2. 每 0.15 秒取一張，防閃
    base_lab = lab(base)
    n = int(len(files) / FPS / STEP_S)
    raw = []
    for k in range(n):
        f = files[min(int(round(k * STEP_S * FPS)), len(files) - 1)]
        im = np.asarray(Image.open(f).convert('RGB')).astype(np.float32)
        raw.append(quant(sample(im, sx, sy, ox, oy)))
    region = np.zeros((GH, GW), bool)
    for q in raw:
        moved = np.linalg.norm(lab(q) - base_lab, axis=-1) > MOVED
        region |= grow(shrink(moved, 1), 1)          # 去掉零星的雜點
    region = grow(region, REGION_GROW)
    cells, prev = [], base.copy()
    for q in raw:
        # 先看跟原圖像不像：像就直接用原圖（動作結束時才會自己收回原圖，接回第一格不跳）；
        # 不像原圖、但跟上一格差不多，沿用上一格；兩個都不是才用影片這一格
        near_base = np.linalg.norm(lab(q) - base_lab, axis=-1) < STICKY
        steady = np.linalg.norm(lab(q) - lab(prev), axis=-1) < STICKY
        cur = np.where(steady[..., None], prev, q)
        cur = np.where(near_base[..., None], base, cur)
        cur = np.where(region[..., None], cur, base)
        cells.append(cur)
        prev = cur
    print('region cells', int(region.sum()))
    print('frames', n)

    # 成品格子圖：前面照原圖站著補到 96 格，動作放在 A 版掂桶同一個時間點（第 18 格起）
    out = [base.copy() for _ in range(A.N)]
    start = 18
    for k, c in enumerate(cells):
        out[(start + k) % A.N] = c
    idx = np.zeros((GH * (A.N // A.COLS), GW * A.COLS), np.uint8)
    for i, fr in enumerate(out):
        r, cc = divmod(i, A.COLS)
        idx[r * GH:(r + 1) * GH, cc * GW:(cc + 1) * GW] = px.nearest(px.rgb2lab(fr.reshape(-1, 3)), pal_lab).reshape(GH, GW)
    im = Image.fromarray(idx, 'P')
    im.putpalette(pal.reshape(-1).tolist())
    im.save(os.path.join(HERE, 'r0_anim96_B.png'), optimize=True)

    # 3. 三欄對照 GIF（現在／A／B），只放掂桶那一段，放大 3 倍，一格 0.15 秒
    def cells_of(path):
        sh = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
        return [sh[(i // A.COLS) * GH:(i // A.COLS + 1) * GH, (i % A.COLS) * GW:(i % A.COLS + 1) * GW] for i in range(A.N)]
    now = cells_of(os.path.join(FOLDER, 'r0_anim96.png'))
    fixed = cells_of(os.path.join(os.path.dirname(HERE), '輸出', 'r0_anim96.png'))
    S, GAP = 3, 8
    span = range(start - 2, start + len(cells) + 2)
    gif = []
    for i in span:
        row = [now[i % A.N], fixed[i % A.N], out[i % A.N]]
        canvas = np.full((GH * S, (GW * S + GAP) * 3 - GAP, 3), 40, np.uint8)
        for j, c in enumerate(row):
            canvas[:, j * (GW * S + GAP):j * (GW * S + GAP) + GW * S] = np.kron(c, np.ones((S, S, 1))).astype(np.uint8)
        gif.append(Image.fromarray(canvas))
    gif[0].save(os.path.join(HERE, '對照_現在vsAvsB_掂桶那段.gif'), save_all=True, append_images=gif[1:], duration=150, loop=0)

    # 特寫：B 動作中間的 8 格，整張縮小看動作、放大看像素
    picks = np.linspace(0, len(cells) - 1, 8).astype(int)
    Z = 3
    strip = np.full((GH * Z, (GW * Z + GAP) * len(picks), 3), 40, np.uint8)
    for j, k in enumerate(picks):
        strip[:, j * (GW * Z + GAP):j * (GW * Z + GAP) + GW * Z] = np.kron(cells[k], np.ones((Z, Z, 1))).astype(np.uint8)
    Image.fromarray(strip).save(os.path.join(HERE, 'B_動作八格.png'))


if __name__ == '__main__':
    main()
