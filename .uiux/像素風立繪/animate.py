"""幫 14 張像素立繪各做一條逐格動畫（橫向排開的長條圖），每個境界一種動作。

煉氣晃水桶、築基揮劍、金丹凝丹、元嬰法環、化神流星、大乘佛光、渡劫天雷。
另外產生只有眼睛那一小塊的眨眼圖，疊在動畫上不會打架。

用法：python animate.py <統一色盤資料夾> [檢查用總表的資料夾]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

import pixelate2 as px

GW, GH = px.GW, px.GH
FRAMES = {'0': 16, '1': 12, '2': 12, '3': 12, '4': 16, '5': 12, '6': 20}
GOLD = np.array([246, 207, 90], dtype=np.float32)
PALE = np.array([255, 244, 190], dtype=np.float32)
WHITE = np.array([255, 255, 255], dtype=np.float32)


def load(folder, name):
    im = Image.open(os.path.join(folder, '%s_%dx%d.png' % (name, GW, GH)))
    pal = np.array(im.getpalette()[:px.NCOL * 3], dtype=np.uint8).reshape(-1, 3)
    return pal[np.asarray(im)].astype(np.float32), pal


def polymask(points):
    m = Image.new('L', (GW, GH), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return np.asarray(m) > 0


def lum(rgb):
    return rgb @ px.LW


def inpaint(rgb, hole):
    """把挖掉的地方用周圍的顏色一圈一圈補回來。"""
    out = rgb.copy()
    unknown = hole.copy()
    while unknown.any():
        known = ~unknown
        acc = np.zeros_like(out)
        cnt = np.zeros((GH, GW), dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), axis=(0, 1))
            v = np.roll(out, (dy, dx), axis=(0, 1))
            if dy == 1: k[0, :] = False
            if dy == -1: k[-1, :] = False
            if dx == 1: k[:, 0] = False
            if dx == -1: k[:, -1] = False
            acc += v * k[..., None]
            cnt += k
        fill = unknown & (cnt > 0)
        if not fill.any():
            break
        out[fill] = acc[fill] / cnt[fill][:, None]
        unknown &= ~fill
    return out


def rotate_paste(bg, rgb, mask, pivot, deg):
    """把切下來的那一塊繞著支點轉 deg 度（順時針為正）貼回背景。"""
    out = bg.copy()
    th = math.radians(deg)
    c, s = math.cos(th), math.sin(th)
    ys, xs = np.mgrid[0:GH, 0:GW]
    dx, dy = xs - pivot[0], ys - pivot[1]
    sx = np.rint(c * dx + s * dy + pivot[0]).astype(int)
    sy = np.rint(-s * dx + c * dy + pivot[1]).astype(int)
    ok = (sx >= 0) & (sx < GW) & (sy >= 0) & (sy < GH)
    src = np.zeros((GH, GW), dtype=bool)
    src[ok] = mask[sy[ok], sx[ok]]
    out[src] = rgb[sy[src], sx[src]]
    return out


def lighten(rgb, cx, cy, r, amt, col):
    ys, xs = np.mgrid[0:GH, 0:GW]
    w = np.clip(1 - np.hypot(xs - cx, ys - cy) / r, 0, 1) ** 2 * amt
    return rgb * (1 - w[..., None]) + col * w[..., None]


def dot(rgb, x, y, col, a=1.0):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < GW and 0 <= y < GH:
        rgb[y, x] = rgb[y, x] * (1 - a) + col * a


def plus(rgb, x, y, col, a=1.0):
    for ddx, ddy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        dot(rgb, x + ddx, y + ddy, col, a)
    dot(rgb, x, y, WHITE, a)


def line(rgb, p0, p1, col, a=1.0, wide=False):
    n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 2) + 1
    for i in range(n + 1):
        t = i / n
        x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
        dot(rgb, x, y, col, a)
        if wide:
            dot(rgb, x + 1, y, col, a)


def skin(rgb):
    return (rgb[..., 0] > 215) & (rgb[..., 1] > 175) & (rgb[..., 2] < 185) & (rgb[..., 0] - rgb[..., 2] > 45)


# ---- 煉氣：水桶像鐘擺一樣晃，燈籠一明一暗 ----
def realm0(base):
    body = polymask([(109, 146), (111, 142), (138, 142), (140, 146), (139, 168), (135, 175), (114, 175), (110, 168)])
    arc = polymask([(107, 147), (109, 136), (116, 129), (129, 128), (137, 134), (142, 147)]) & ~body
    part = body | (arc & (lum(base) < 165) & (base[..., 0] - base[..., 2] > 30))
    hand = polymask([(115, 124), (128, 124), (128, 137), (115, 137)]) & skin(base)
    part &= ~hand
    bg = inpaint(base, part)
    flick = [.2, .5, .35, .6, .25, .55, .3, .5, .2, .45, .6, .35, .5, .25, .55, .3]
    out = []
    for f in range(16):
        ang = [0, 3, 5, 3, 0, -3, -5, -3][f % 8]
        fr = rotate_paste(bg, base, part, (121.5, 132), ang)
        fr[hand] = base[hand]
        out.append(lighten(fr, 141, 85, 13, flick[f], PALE))
    return out


# ---- 築基：先收劍、再劈下去，劈的那一下帶一道劍光 ----
def realm1(base):
    poly = polymask([(146, 37), (154, 38), (156, 46), (137, 83), (136, 90), (127, 91), (121, 95), (116, 93), (117, 84), (119, 76), (142, 44)])
    part = poly & (base[..., 0] - base[..., 2] > 45)
    fist = polymask([(108, 89), (122, 89), (122, 105), (108, 105)]) & skin(base)
    part &= ~fist
    bg = inpaint(base, part)
    pivot = (115, 96)
    tip0 = math.degrees(math.atan2(41 - 96, 150 - 115))
    seq = [0, 0, 0, 0, 0, -6, -10, 10, 18, 18, 8, 0]
    out = []
    for f, ang in enumerate(seq):
        fr = rotate_paste(bg, base, part, pivot, ang)
        fr[fist] = base[fist]
        if f in (7, 8):
            a0, a1 = (-10, 10) if f == 7 else (2, 18)
            alpha = 0.9 if f == 7 else 0.5
            d = a0
            while d <= a1:
                t = math.radians(tip0 + d)
                for r, col in ((57, PALE), (59, GOLD), (61, GOLD), (63, PALE)):
                    dot(fr, pivot[0] + r * math.cos(t), pivot[1] + r * math.sin(t), col, alpha)
                d += 0.6
        if f in (8, 9):
            t = math.radians(tip0 + 18)
            plus(fr, pivot[0] + 66 * math.cos(t), pivot[1] + 66 * math.sin(t), GOLD)
        out.append(fr)
    return out


# ---- 金丹：金丹的光一脹一縮，光點繞著它轉，光環一圈圈往外擴 ----
def realm2(base, c):
    out = []
    for f in range(12):
        fr = lighten(base, c[0], c[1], 19, .15 + .35 * (.5 + .5 * math.sin(2 * math.pi * f / 12)), PALE)
        if f < 6:
            r = 7 + f * 2.6
            for k in range(18):
                t = math.radians(k * 20 + f * 7)
                dot(fr, c[0] + r * math.cos(t), c[1] + r * math.sin(t), PALE, .85 - f * .12)
        for k in range(5):
            t = math.radians(f * 30 + k * 72)
            x, y = c[0] + 13 * math.cos(t), c[1] + 13 * math.sin(t)
            if k % 2 == 0:
                plus(fr, x, y, GOLD)
            else:
                dot(fr, x, y, WHITE)
        out.append(fr)
    return out


# ---- 元嬰：頭上的元嬰發光，腳下升起一圈法環掃過全身 ----
def realm3(base, c):
    out = []
    for f in range(12):
        fr = lighten(base, c[0], c[1], 15, .15 + .4 * (.5 + .5 * math.sin(2 * math.pi * f / 12)), PALE)
        cy = 196 - f * 11
        fade = min(1.0, (f + 1) / 2, (12 - f) / 3)
        for i in range(0, 181, 3):
            if (i // 3 + f) % 2:
                continue
            t = math.radians(i)
            x, y = 84 + 46 * math.cos(t), cy + 9 * math.sin(t)
            dot(fr, x, y, GOLD, .9 * fade)
            dot(fr, x, y - 1, PALE, .6 * fade)
        plus(fr, 84 - 46, cy, GOLD, fade)
        plus(fr, 84 + 46, cy, GOLD, fade)
        out.append(fr)
    return out


# ---- 化神：流星劃過夜空，星星輪流閃 ----
def realm4(base):
    sky = (base[..., 2] > base[..., 0] + 18) & (lum(base) < 190)
    stars = [(30, 50), (138, 48), (22, 95), (146, 90), (120, 22), (48, 26)]
    out = []
    for f in range(16):
        fr = base.copy()
        for i, (x, y) in enumerate(stars):
            ph = (f + i * 3) % 8
            if sky[y, x]:
                if ph < 3:
                    plus(fr, x, y, WHITE)
                elif ph < 5:
                    dot(fr, x, y, WHITE)
        for start, (x0, y0, vx, vy) in ((0, (152, 12, -6, 4)), (8, (20, 26, 5, 3))):
            g = f - start
            if 0 <= g <= 6:
                for j in range(7):
                    x, y = x0 + vx * g - vx * j * .5, y0 + vy * g - vy * j * .5
                    xi, yi = int(round(x)), int(round(y))
                    if 0 <= xi < GW and 0 <= yi < GH and sky[yi, xi]:
                        dot(fr, x, y, WHITE if j < 2 else PALE, 1 - j * .14)
        out.append(fr)
    return out


# ---- 大乘：背後的光芒慢慢轉，金色光點往上升 ----
def realm5(base):
    c = (84, 63)
    motes = [(20, 150), (40, 120), (60, 176), (108, 170), (130, 126), (150, 156)]
    out = []
    for f in range(12):
        fr = lighten(base, c[0], c[1], 72, .05 + .13 * (.5 + .5 * math.sin(2 * math.pi * f / 12)), PALE)
        for k in range(12):
            ang = k * 30 + f * 2.5
            t = math.radians(ang)
            if math.sin(t) > 0.15:
                continue
            for r in range(60, 73):
                x, y = c[0] + r * math.cos(t), c[1] + r * math.sin(t)
                dot(fr, x, y, PALE, .75)
                dot(fr, x + 1, y, PALE, .45)
        for i, (x, y) in enumerate(motes):
            g = (f + i * 2) % 12
            plus(fr, x, y - g * 2, GOLD, math.sin(math.pi * g / 12)) if i % 2 == 0 else dot(fr, x, y - g * 2, WHITE, math.sin(math.pi * g / 12))
        out.append(fr)
    return out


# ---- 渡劫：天雷劈下來，整張閃白、震一下，腳下的裂縫發亮 ----
def realm6(base):
    bolt_a = [(50, 0), (44, 18), (54, 20), (40, 44), (50, 46), (38, 70)]
    painted = (lum(base) > 205) & (np.mgrid[0:GH, 0:GW][1] > 104)
    embers = [(30, 196), (56, 204), (118, 200), (144, 190), (92, 206)]
    out = []
    for f in range(20):
        fr = base.copy()
        fr = lighten(fr, 84, 192, 34, .1 + .22 * (.5 + .5 * math.sin(2 * math.pi * f / 10)), GOLD)
        for i, (x, y) in enumerate(embers):
            g = (f + i * 4) % 20
            dot(fr, x, y - g * .9, GOLD, math.sin(math.pi * g / 20))
        flash = {0: .5, 1: .15, 2: .38, 10: .28, 12: .14}.get(f, 0)
        if f in (0, 1, 2, 3):
            for a, b in zip(bolt_a, bolt_a[1:]):
                line(fr, (a[0] - 1, a[1]), (b[0] - 1, b[1]), GOLD, .9 if f < 3 else .4)
                line(fr, a, b, WHITE, 1 if f < 3 else .5, wide=f < 3)
        if f in (10, 11, 12):
            fr[painted] = fr[painted] * .3 + WHITE * .7
        if flash:
            fr = fr * (1 - flash) + np.array([255, 248, 220], dtype=np.float32) * flash
        shift = {0: 1, 1: -1, 2: 1}.get(f, 0)
        if shift:
            fr = np.roll(fr, shift, axis=1)
        out.append(fr)
    return out


def main():
    folder = sys.argv[1]
    dbg = sys.argv[2] if len(sys.argv) > 2 else None
    picks = []
    for name in px.NAMES:
        base, pal = load(folder, name)
        pal_lab = px.rgb2lab(pal.astype(np.float32))
        realm = name[-1]
        female = name.startswith('g')
        if realm == '0': frames = realm0(base)
        elif realm == '1': frames = realm1(base)
        elif realm == '2': frames = realm2(base, (133, 59) if female else (133, 58))
        elif realm == '3': frames = realm3(base, (85, 34) if female else (85, 38))
        elif realm == '4': frames = realm4(base)
        elif realm == '5': frames = realm5(base)
        else: frames = realm6(base)
        n = len(frames)
        strip = np.zeros((GH, GW * n), dtype=np.uint8)
        for i, fr in enumerate(frames):
            idx = px.nearest(px.rgb2lab(np.clip(fr, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)
            strip[:, i * GW:(i + 1) * GW] = idx
        im = Image.fromarray(strip, mode='P')
        im.putpalette(pal.reshape(-1).tolist())
        out = os.path.join(folder, '%s_anim%d.png' % (name, n))
        im.save(out, optimize=True)
        print(name, 'frames', n, os.path.getsize(out), 'bytes')
        picks.append(im.convert('RGB'))
        blink = os.path.join(folder, '%s_%dx%d_blink.png' % (name, GW, GH))
        if os.path.exists(blink):
            b = np.asarray(Image.open(blink).convert('RGB')).astype(np.int32)
            diff = np.abs(b - base.astype(np.int32)).sum(-1) > 0
            ys, xs = np.where(diff)
            alpha = np.zeros((GH, GW), dtype=np.uint8)
            alpha[max(0, ys.min() - 1):ys.max() + 2, max(0, xs.min() - 1):xs.max() + 2] = 255
            rgba = np.dstack([b.astype(np.uint8), alpha])
            Image.fromarray(rgba, mode='RGBA').save(os.path.join(folder, '%s_eyes.png' % name), optimize=True)
    if dbg:
        want = {'r0': [0, 2, 6], 'r1': [0, 6, 7, 8, 9], 'r2': [0, 3], 'r3': [3, 8], 'r4': [3, 11], 'r5': [0, 6], 'r6': [0, 5, 11],
                'gr0': [2], 'gr1': [7, 8], 'gr6': [0]}
        tiles = []
        for name, im in zip(px.NAMES, picks):
            for f in want.get(name, []):
                tiles.append(im.crop((f * GW, 0, (f + 1) * GW, GH)))
        cols = 10
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * (GW + 4), rows * (GH + 4)), (30, 30, 30))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * (GW + 4), (i // cols) * (GH + 4)))
        sheet.save(os.path.join(dbg, 'sheet_anim.png'))


if __name__ == '__main__':
    main()
