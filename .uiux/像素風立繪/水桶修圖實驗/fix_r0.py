"""煉氣男水桶破圖的修法 A（2026-11-19 多米選的，先只試煉氣男）。不改 animate.py，在這裡把它的煉氣男骨架換掉三樣東西：

1. 背景層：原本用 OpenCV 照周圍紋路猜（rig.fill_bg，自己註解就寫「會糊」），桶一提起來露出一塊糊白。
   改用分層實驗留下的 Codex 乾淨背景（素材/原圖版/背景_codex縮到1008.png），每 6×6 取正中央一點縮回 168×210、收回共用色盤。
   只換角色那一塊（rg.hole），其他地方還是原圖的格子。
2. 桶後面的衣襬：原本桶的範圍整塊從身體扣掉，桶一盪開，衣襬像被切成一條直線。
   請 Codex 畫一張拿掉水桶、背景洋紅的煉氣男（codex/nobucket.png），縮回 168×210 收色盤，
   只取「原本被桶擋住、又在角色範圍裡」的那幾格，接到身體上，跟著身體呼吸、蹲。
3. 桶不再逐格轉：先用 RotSprite（放大 8 倍、轉、再縮回來）做好每 3 度一張，程式只負責換圖。
   原本在 30 格寬的桶上直接用最近鄰轉，桶板會斷、外框鋸齒。
4. 起風的草屑：原本是畫在角色前面的 5 格細線，手機上像刮痕。改成 2 格的小塊、畫在角色後面。

用法：python fix_r0.py [輸出資料夾，預設 ./輸出]
輸出：r0_anim96.png（跟 app 同格式的 12×8 格子圖）、對照 GIF（現在 vs 修過，放大 4 倍）、掂桶那一下的前後對照圖。
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)
import animate as A          # noqa: E402
import pixelate2 as px       # noqa: E402
from rig import GH, GW, grow, XS, YS   # noqa: E402

FOLDER = os.path.join(ROOT, '造型風格', '動畫_新去背')
CLEAN_BG = os.path.join(ROOT, '分層動畫實驗', '素材', '原圖版', '背景_codex縮到1008.png')
NOBUCKET = os.path.join(HERE, 'codex', 'nobucket_raw.png')
# Codex 交回來的圖是 1131×1391、整張等比放大過，不是 1008×1260。用輪廓對原本的遮罩找出來的對法（桶附近不算），重疊 95%：
# 第 x 格取 ((x + 0.5) × 6.66, (y + 0.5) × 6.62 + 1) 那一點
NOBUCKET_MAP = (6.66, 6.62, 0, 1)
GRIP = (125, 135)            # 桶繞著轉的點（手握提把那裡），跟 animate.bucket_parts 一樣
STEP_DEG = 3                 # 預先做好的桶每隔幾度一張
MAGENTA_TOL = 90             # 離洋紅多近算背景（RGB 三個差的總和）


# ---------- 縮回 168×210、收色盤 ----------
def center_sample(path, mapping=None):
    """高解析圖 → 168×210：每格取正中央那一點（整格平均會把像素邊糊掉）。mapping=(每格寬, 每格高, x 偏移, y 偏移)。"""
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    h, w = im.shape[:2]
    sx, sy, ox, oy = mapping or (w / GW, h / GH, 0, 0)
    ys = np.clip(((np.arange(GH) + 0.5) * sy + oy).astype(int), 0, h - 1)
    xs = np.clip(((np.arange(GW) + 0.5) * sx + ox).astype(int), 0, w - 1)
    return im[ys][:, xs]


def quantizer(pal):
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    return lambda rgb: pal[px.nearest(px.rgb2lab(np.clip(rgb, 0, 255).reshape(-1, 3)), pal_lab).reshape(rgb.shape[:2])].astype(np.float32)


# ---------- RotSprite ----------
def scale2x(img, alpha):
    """EPX 放大兩倍：斜線會長成斜線，不會變成兩倍大的階梯。img 是 (h, w, 3)，alpha 是 (h, w) bool。"""
    key = img.astype(np.int64) @ np.array([1, 256, 65536]) + 1
    key = np.where(alpha, key, 0)
    P = np.pad(key, 1, mode='edge')
    c = P[1:-1, 1:-1]
    A_, B, C, D = P[:-2, 1:-1], P[1:-1, 2:], P[1:-1, :-2], P[2:, 1:-1]   # 上、右、左、下
    e0 = np.where((C == A_) & (C != D) & (A_ != B), A_, c)
    e1 = np.where((A_ == B) & (A_ != C) & (B != D), B, c)
    e2 = np.where((D == C) & (D != B) & (C != A_), C, c)
    e3 = np.where((B == D) & (B != A_) & (D != C), D, c)
    h, w = key.shape
    out = np.zeros((h * 2, w * 2), np.int64)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
    a = out > 0
    v = np.where(a, out - 1, 0)
    rgb = np.stack([v % 256, (v // 256) % 256, v // 65536], -1).astype(np.float32)
    return rgb, a


def rotsprite(tex, mask, pivot, deg):
    """把零件繞 pivot 轉 deg 度（順時針為正，跟 rig.rot 同方向），回傳整張 168×210 大小的 (顏色, 遮罩)。"""
    if deg == 0:
        return tex.copy(), mask.copy()
    ys, xs = np.where(mask)
    pad = 16
    y0, y1, x0, x1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, GH), max(xs.min() - pad, 0), min(xs.max() + pad + 1, GW)
    rgb, a = tex[y0:y1, x0:x1], mask[y0:y1, x0:x1]
    for _ in range(3):
        rgb, a = scale2x(rgb, a)
    S = 8
    th = math.radians(deg)
    c, s = math.cos(th), math.sin(th)
    out_rgb, out_a = tex.copy(), np.zeros((GH, GW), bool)
    # 在 8 倍的圖上轉，再取每一格正中央那一點縮回來
    py, px_ = (pivot[1] - y0) * S + S / 2, (pivot[0] - x0) * S + S / 2
    gy, gx = np.mgrid[y0:y1, x0:x1]
    cy, cx = (gy - y0) * S + S / 2, (gx - x0) * S + S / 2
    dx, dy = cx - px_, cy - py
    sx, sy = c * dx + s * dy + px_, -s * dx + c * dy + py           # 回頭找原圖座標，跟 rig.rot 一樣的式子
    ix, iy = np.floor(sx).astype(int), np.floor(sy).astype(int)
    ok = (ix >= 0) & (ix < a.shape[1]) & (iy >= 0) & (iy < a.shape[0])
    hit = np.zeros_like(ok)
    hit[ok] = a[iy[ok], ix[ok]]
    region_rgb = out_rgb[y0:y1, x0:x1]
    region_rgb[hit] = rgb[iy[hit], ix[hit]]
    out_a[y0:y1, x0:x1] = hit
    return out_rgb, out_a


# ---------- 換掉骨架裡的東西 ----------
def bucket_angle(part, f):
    """animate 原本給桶的轉角（從 rig.rot 的閉包裡讀出來），四捨五入到 STEP_DEG 的倍數。"""
    fn = part.move(f)[-1]
    cl = {n: c.cell_contents for n, c in zip(fn.__code__.co_freevars, fn.__closure__)}
    deg = math.degrees(math.atan2(cl['s'], cl['c']))
    return int(STEP_DEG * round(deg / STEP_DEG))


def grass_back(rg):
    """起風的草屑：兩格一小塊（深的一格在前、亮的一格在後），畫在角色後面。路線跟原本一樣。"""
    def fx(img, f):
        f %= A.N
        t = f - A.GUST0
        if not 0 <= t < 34:
            return
        for j, (x0, y0) in enumerate([(10, 186), (22, 196), (4, 174), (30, 190), (16, 180)]):
            s = t - (0, 1, 3, 5, 7)[j]
            if not 0 <= s < 30:
                continue
            x = x0 + 5.0 * s
            y = y0 - 10 * math.sin(min(s, 9) / 9 * math.pi / 2) + max(0, s - 9) * 0.9 + 2 * math.sin(s * 0.7)
            dx, dy = [(1, 0), (1, 1), (0, 1), (-1, 1)][(s // 2) % 4]
            a = min(1.0, (30 - s) / 6.0)
            A.dot(img, x, y, A.GRASS_EDGE, a)
            A.dot(img, x + dx, y + dy, (A.GRASS_A if j % 2 else A.GRASS_B), a)
    rg.back.append(fx)


def leaves_only(rg, base, name):
    """原本 env_lianqi 的另一半：樹叢掉下來的葉子，照舊畫在最上面。"""
    dark, light = A.leaf_colors(base)

    def fx(img, f):
        f %= A.N
        for i, (start, x0, y0) in enumerate(A.LIANQI_LEAVES.get(name, [])):
            t = (f - start) % A.N
            y = y0 + 1.6 * t
            if y > A.LIANQI_GROUND + 8:
                continue
            push = sum(A.gust_rate(start + k) for k in range(t))
            x = x0 + 4 * math.sin(A.TAU * t / 20.0 + i) + 0.2 * t + push
            fade = min(1.0, (A.LIANQI_GROUND + 8 - y) / 8.0)
            A.draw_leaf(img, x, y, t, dark, light, fade)
    rg.front.append(fx)


def fixed_rig(base, pal, M, blink=None, use_patch=True):
    quant = quantizer(pal)
    rg = A.make_rig('r0', base, blink, M)
    # 4. 草屑：拿掉 env_lianqi 那一個（草屑＋落葉畫在最上面），換成草屑在後面、落葉照舊
    rg.front = [fn for fn in rg.front if 'env_lianqi' not in fn.__qualname__]
    grass_back(rg)
    leaves_only(rg, base, 'r0')
    rg.build()

    parts = {p.name: p for p in rg.parts}
    body, bucket = parts['body'], parts['bucket']

    # 1. 背景層：角色那一塊換成 Codex 乾淨背景
    clean = quant(center_sample(CLEAN_BG))
    hole = rg.hole.copy()
    for p in rg.parts:
        hole |= p.mask
    rg.bg = np.where(hole[..., None], clean, rg.bg)
    rg.bg_alt = np.where(hole[..., None], clean, rg.bg_alt)

    # 2. 桶後面的衣襬：Codex 拿掉水桶的圖，只取原本被桶擋住、又是角色的格子
    if use_patch and os.path.exists(NOBUCKET):
        nb = center_sample(NOBUCKET, NOBUCKET_MAP)
        magenta = np.abs(nb - np.array([255, 0, 255], np.float32)).sum(-1) < MAGENTA_TOL
        nb_char = ~magenta
        behind = bucket.mask & nb_char & ~body.mask & ~parts['arm'].mask
        behind &= ~(YS > 182)       # 腳底那一帶不接（地面歸背景層）
        body.mask = body.mask | behind
        body.tex = body.tex.copy()
        body.tex[behind] = quant(nb)[behind]
        body.alt = body.alt.copy()
        body.alt[behind] = body.tex[behind]
        rg._patch = behind

    # 3. 桶：預先轉好，逐格換圖；轉的部分從 move 拿掉，只剩跟著手臂走
    cache = {}
    angle_of = lambda f: bucket_angle(bucket, f)
    angles = sorted({angle_of(f) for f in range(A.N)})
    for d in angles:
        cache[d] = rotsprite(bucket.tex, bucket.mask, GRIP, d)
    rg._bucket_angles = [angle_of(f) for f in range(A.N)]
    rg._bucket_cache = cache
    bucket.move = lambda f: []
    return rg


def render(rg, f):
    """照 rig.Rig.frame 疊，只差在桶那一格換成預先轉好的圖。"""
    angle = rg._bucket_angles[f % A.N]
    closed = bool(rg._blink) and (f % A.N) in rg._blink[1]
    out = (rg.bg_alt if closed else rg.bg).copy()
    for fx in rg.back:
        fx(out, f)
    for p in rg.parts:
        mask, tex = p.mask, (p.alt if closed else p.tex)
        if p.name == 'bucket':
            tex, mask = rg._bucket_cache[angle]
        X, Y = XS, YS
        for tr in p.chain(f):
            X, Y = tr(X, Y)
        sx, sy = np.floor(X + 0.5).astype(int), np.floor(Y + 0.5).astype(int)
        ok = (sx >= 0) & (sx < GW) & (sy >= 0) & (sy < GH)
        m = np.zeros((GH, GW), dtype=bool)
        m[ok] = mask[sy[ok], sx[ok]]
        out[m] = tex[sy[m], sx[m]]
    for fx in rg.front:
        fx(out, f)
    for fx in rg.post:
        out = fx(out, f)
    return out


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '輸出')
    os.makedirs(out_dir, exist_ok=True)
    base, pal = A.load(FOLDER, 'r0')
    blink, _ = A.load(FOLDER, 'r0', '_blink')
    M = np.asarray(Image.open(os.path.join(FOLDER, 'r0_168x210_mask.png'))) > 127
    quant = quantizer(pal)

    rg = fixed_rig(base, pal, M, blink)
    new = [quant(render(rg, f)) for f in range(A.N)]

    # 現在 app 裡的那條（同一個資料夾的 r0_anim96.png）
    sheet = np.asarray(Image.open(os.path.join(FOLDER, 'r0_anim96.png')).convert('RGB')).astype(np.float32)
    old = [sheet[(i // A.COLS) * GH:(i // A.COLS + 1) * GH, (i % A.COLS) * GW:(i % A.COLS + 1) * GW] for i in range(A.N)]

    # 成品格子圖（收色盤的 P 模式，跟 app 同格式）
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    idx = np.zeros((GH * (A.N // A.COLS), GW * A.COLS), np.uint8)
    for i, fr in enumerate(new):
        r, c = divmod(i, A.COLS)
        idx[r * GH:(r + 1) * GH, c * GW:(c + 1) * GW] = px.nearest(px.rgb2lab(fr.reshape(-1, 3)), pal_lab).reshape(GH, GW)
    im = Image.fromarray(idx, 'P')
    im.putpalette(pal.reshape(-1).tolist())
    im.save(os.path.join(out_dir, 'r0_anim96.png'), optimize=True)

    # 對照 GIF：左現在、右修過，放大 4 倍，一格 0.15 秒
    S, GAP = 4, 8
    gif = []
    for o, n in zip(old, new):
        canvas = np.full((GH * S, GW * S * 2 + GAP, 3), 40, np.uint8)
        canvas[:, :GW * S] = np.kron(o, np.ones((S, S, 1))).astype(np.uint8)
        canvas[:, GW * S + GAP:] = np.kron(n, np.ones((S, S, 1))).astype(np.uint8)
        gif.append(Image.fromarray(canvas))
    gif[0].save(os.path.join(out_dir, '對照_現在vs修過.gif'), save_all=True, append_images=gif[1:], duration=150, loop=0)

    # 掂桶那幾格的特寫：上排現在、下排修過，裁水桶附近，放大 6 倍
    frames = [20, 22, 23, 24, 25, 26, 27, 31, 32]
    x0, y0, x1, y1 = 70, 96, 160, 196
    Z = 6
    w, h = (x1 - x0) * Z, (y1 - y0) * Z
    strip = np.full((h * 2 + GAP, (w + GAP) * len(frames), 3), 40, np.uint8)
    for k, f in enumerate(frames):
        for row, src in enumerate((old, new)):
            crop = src[f][y0:y1, x0:x1]
            strip[row * (h + GAP):row * (h + GAP) + h, k * (w + GAP):k * (w + GAP) + w] = np.kron(crop, np.ones((Z, Z, 1))).astype(np.uint8)
    Image.fromarray(strip).save(os.path.join(out_dir, '掂桶特寫_上現在_下修過.png'))
    print('angles', sorted(rg._bucket_cache), 'patch cells', int(getattr(rg, '_patch', np.zeros(1)).sum()))


if __name__ == '__main__':
    main()
