"""把 14 張水彩立繪轉成像素圖：固定格數、14 張共用一份色盤、另外產生閉眼的那一張。

用法：python pixelate2.py <Portraits 資料夾> <輸出資料夾> [檢查用總表的資料夾]
"""
import os
import sys
from collections import Counter, deque

import numpy as np
from PIL import Image, ImageEnhance

NAMES = ['r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'gr0', 'gr1', 'gr2', 'gr3', 'gr4', 'gr5', 'gr6']
GW, GH, K = 168, 210, 4      # 格數，以及每格取樣的邊長
NCOL = 72                    # 共用色盤的顏色數
LW = np.array([0.299, 0.587, 0.114], dtype=np.float32)


def rgb2lab(rgb):
    c = np.asarray(rgb, dtype=np.float64) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = (c @ m.T) / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1).astype(np.float32)


def cells(path):
    """切格取色：每格取平均，格子裡有深色線條就往線條的顏色拉。"""
    im = Image.open(path).convert('RGBA')
    bg = Image.new('RGBA', im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    im = bg.convert('RGB')
    w, h = im.size
    ta = GW / GH
    if w / h > ta:
        nw = int(round(h * ta)); x0 = (w - nw) // 2; im = im.crop((x0, 0, x0 + nw, h))
    else:
        nh = int(round(w / ta)); y0 = (h - nh) // 2; im = im.crop((0, y0, w, y0 + nh))
    im = ImageEnhance.Color(im).enhance(1.2)
    im = ImageEnhance.Contrast(im).enhance(1.06)
    big = im.resize((GW * K, GH * K), Image.LANCZOS)
    a = np.asarray(big).astype(np.float32).reshape(GH, K, GW, K, 3).transpose(0, 2, 1, 3, 4).reshape(GH, GW, K * K, 3)
    mean = a.mean(axis=2)
    idx = np.argsort(a @ LW, axis=2)
    n = max(1, int(K * K * 0.2))
    dark = np.take_along_axis(a, idx[:, :, :n, None], axis=2).mean(axis=2)
    t = np.clip(((mean @ LW) - (dark @ LW) - 16) / 36, 0, 1)[..., None] * 0.75
    return np.clip(mean * (1 - t) + dark * t, 0, 255)


def nearest(lab, centers):
    out = np.empty(lab.shape[0], dtype=np.int32)
    for s in range(0, lab.shape[0], 40000):
        d = ((lab[s:s + 40000, None, :] - centers[None]) ** 2).sum(-1)
        out[s:s + 40000] = d.argmin(1)
    return out


def shared_palette(arrs):
    """14 張的格子放在一起分群，鮮豔的顏色加權，免得紅果、粉袍、玉佩這些小面積被吃掉。"""
    mosaic = np.concatenate([a.reshape(-1, 3) for a in arrs])
    img = Image.fromarray(mosaic.reshape(len(arrs) * GH, GW, 3).astype(np.uint8))
    q = img.quantize(colors=NCOL, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:NCOL * 3], dtype=np.float32).reshape(-1, 3)
    lab = rgb2lab(mosaic)
    wgt = 1 + np.hypot(lab[:, 1], lab[:, 2]) / 30
    cen = rgb2lab(pal)
    for _ in range(14):
        lbl = nearest(lab, cen)
        for j in range(NCOL):
            m = lbl == j
            if m.any():
                ww = wgt[m][:, None]
                cen[j] = (lab[m] * ww).sum(0) / ww.sum()
                pal[j] = (mosaic[m] * ww).sum(0) / ww.sum()
    # 眼睛和最深的線條固定用同一個墨色，14 張才會一致；拿最少格子用到的那一色來換
    counts = np.bincount(nearest(lab, cen), minlength=NCOL)
    pal[counts.argmin()] = (74, 42, 14)
    return np.clip(np.round(pal), 0, 255).astype(np.uint8)


def cleanup(idx, pal_lab):
    """拿掉孤立的雜點：跟上下左右都不同色，而且跟鄰居顏色很接近的那種。對比大的細節（眼睛亮點）不動。"""
    out = idx.copy()
    for y in range(1, GH - 1):
        for x in range(1, GW - 1):
            c = idx[y, x]
            nb = [idx[y - 1, x], idx[y + 1, x], idx[y, x - 1], idx[y, x + 1]]
            if c in nb:
                continue
            top, cnt = Counter(nb).most_common(1)[0]
            if cnt >= 3 and ((pal_lab[c] - pal_lab[top]) ** 2).sum() < 18 ** 2:
                out[y, x] = top
    return out


def find_eyes(idx, pal_lab):
    """找兩顆張開的眼睛：臉部範圍內，兩塊大小相近、高度相近的深色小塊。找不到就回傳 None（閉眼的境界）。"""
    dark = pal_lab[idx][..., 0] < 46
    seen = np.zeros_like(dark)
    comps = []
    for y in range(int(GH * 0.14), int(GH * 0.46)):
        for x in range(int(GW * 0.22), int(GW * 0.78)):
            if not dark[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)]); seen[y, x] = True; pts = []
            while q:
                cy, cx = q.popleft(); pts.append((cy, cx))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < GH and 0 <= nx < GW and dark[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
            ys = [p[0] for p in pts]; xs = [p[1] for p in pts]
            bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
            if 6 <= len(pts) <= 90 and 2 <= bw <= 12 and 4 <= bh <= 14 and bh >= bw * 0.8 and len(pts) >= bw * bh * 0.45 and max(ys) < GH * 0.46:
                comps.append((min(xs), min(ys), max(xs), max(ys), len(pts)))
    best = None
    for i in range(len(comps)):
        for j in range(i + 1, len(comps)):
            a, b = comps[i], comps[j]
            dx = abs((a[0] + a[2]) - (b[0] + b[2])) / 2
            dy = abs((a[1] + a[3]) - (b[1] + b[3])) / 2
            if 10 <= dx <= 28 and dy <= 4 and 0.5 <= a[4] / b[4] <= 2:
                score = dy + abs(a[4] - b[4]) / 10
                if best is None or score < best[0]:
                    best = (score, a, b)
    return None if best is None else (best[1], best[2])


def blink(idx, pal_lab, eyes):
    out = idx.copy()
    for x0, y0, x1, y1, _ in eyes:
        ring = []
        for y in range(y0 - 3, y1 + 4):
            for x in range(x0 - 3, x1 + 4):
                if 0 <= y < GH and 0 <= x < GW and not (x0 - 1 <= x <= x1 + 1 and y0 - 1 <= y <= y1 + 1):
                    if pal_lab[idx[y, x], 0] > 60:
                        ring.append(idx[y, x])
        skin = Counter(ring).most_common(1)[0][0]
        eye = Counter(idx[y0:y1 + 1, x0:x1 + 1].ravel().tolist())
        ink = min(eye, key=lambda c: pal_lab[c, 0])
        out[max(0, y0 - 1):y1 + 2, max(0, x0 - 1):x1 + 2] = skin
        ly = (y0 + y1) // 2 + 1
        out[ly, x0:x1 + 1] = ink
        out[ly - 1, x0 - 1] = ink
        out[ly - 1, x1 + 1] = ink
    return out


def save(idx, pal, path):
    im = Image.fromarray(idx.astype(np.uint8), mode='P')
    im.putpalette(pal.reshape(-1).tolist())
    im.save(path, optimize=True)
    return im.convert('RGB')


def main():
    src, out = sys.argv[1], sys.argv[2]
    dbg = sys.argv[3] if len(sys.argv) > 3 else None
    os.makedirs(out, exist_ok=True)
    arrs = [cells(os.path.join(src, n + '.imageset', n + '.png')) for n in NAMES]
    pal = shared_palette(arrs)
    pal_lab = rgb2lab(pal.astype(np.float32))
    sheet = Image.new('RGB', (GW * 7 + 36, GH * 2 + 6), (40, 40, 40))
    eyesheet = Image.new('RGB', (132 * 14, 180), (40, 40, 40))
    for i, (n, a) in enumerate(zip(NAMES, arrs)):
        idx = nearest(rgb2lab(a.reshape(-1, 3)), pal_lab).reshape(GH, GW)
        idx = cleanup(idx, pal_lab)
        rgb = save(idx, pal, os.path.join(out, '%s_%dx%d.png' % (n, GW, GH)))
        sheet.paste(rgb, ((i % 7) * (GW + 6), (i // 7) * (GH + 6)))
        eyes = find_eyes(idx, pal_lab)
        used = len(set(idx.ravel().tolist()))
        if eyes:
            b = save(blink(idx, pal_lab, eyes), pal, os.path.join(out, '%s_%dx%d_blink.png' % (n, GW, GH)))
            cx = (eyes[0][0] + eyes[1][2]) // 2; cy = (eyes[0][1] + eyes[0][3]) // 2
            box = (max(0, cx - 22), max(0, cy - 14), max(0, cx - 22) + 44, max(0, cy - 14) + 28)
            eyesheet.paste(rgb.crop(box).resize((132, 84), Image.NEAREST), (i * 132, 0))
            eyesheet.paste(b.crop(box).resize((132, 84), Image.NEAREST), (i * 132, 90))
            print(n, 'colours', used, 'eyes', eyes[0][:4], eyes[1][:4])
        else:
            print(n, 'colours', used, 'eyes not found')
    sw = Image.new('RGB', (NCOL * 12, 24))
    for j in range(NCOL):
        sw.paste(tuple(int(v) for v in pal[j]), (j * 12, 0, j * 12 + 12, 24))
    sw.save(os.path.join(out, '_共用色盤.png'))
    if dbg:
        sheet.save(os.path.join(dbg, 'sheet_shared.png'))
        eyesheet.save(os.path.join(dbg, 'sheet_eyes.png'))


if __name__ == '__main__':
    main()
