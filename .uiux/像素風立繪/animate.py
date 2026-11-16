"""幫 14 張像素立繪各做一條待機動畫（12x8 的格子圖，共 96 格、一格 0.1 秒，一輪 9.6 秒）。

做法照 E:\\像素broll\\pixel-broll-kit 的 motion.js：角色有清楚的姿勢、一拍一拍地演。
  - 大動作前先往反方向小動（蹲、縮），出手只用一兩格，落定時壓扁再回彈。
  - 壓扁和拉長只動腿：頭、手、衣服是一整塊照姿勢位移，一格都不變形；腳踩在地上不動。
    （第二版把衣服那一段壓短拉長、又讓袖子衣襬一直起伏，多米說衣服變動得很詭異。衣服的花紋一被擠壓就怪。）
  - 布料（袖子、衣襬、裙子、飄帶）不做起伏，只有頭髮、鬚、葉子、道具會被帶著盪。
  - 招牌動作排在前 48 格，後 48 格只有呼吸和眨眼，所以 9.6 秒才做一次。
  - 葉子、頭髮、流蘇、水桶是被身體帶著動的：身體一動，它們晚一拍盪幾下才停。
  - 眨眼直接畫進格子裡。
每張的招牌動作：
  煉氣男 掂水桶          煉氣女 左右搖、踮兩下
  築基男 舉劍下劈        築基女 連點兩劍
  金丹男 拋接金丹        金丹女 金丹繞圈、盪出光環
  元嬰男 拄杖點地起光紋  元嬰女 光點匯進元嬰
  化神男 吐納、流星      化神女 星光匯聚到掌心
  大乘男 佛光盪出金環    大乘女 金色花瓣飄落
  渡劫男 扛一道大雷      渡劫女 電弧纏身、兩道小雷

用法：python animate.py <統一色盤資料夾> [檢查圖的資料夾] [只做哪幾張，逗號分隔]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

import pixelate2 as px
from rig import *

TAU = 2 * math.pi
FLASH = np.array([255, 248, 220], dtype=np.float32)
AMBER = np.array([232, 164, 54], dtype=np.float32)
SW = [0, 1, 1, 0, 0, -1, -1, 0]          # 左右搖的節拍


def load(folder, name, suffix=''):
    path = os.path.join(folder, '%s_%dx%d%s.png' % (name, GW, GH, suffix))
    if not os.path.exists(path):
        return None, None
    im = Image.open(path)
    pal = np.array(im.getpalette()[:px.NCOL * 3], dtype=np.uint8).reshape(-1, 3)
    return pal[np.asarray(im)].astype(np.float32), pal


# ---------- 共用 ----------
def disc(c, r):
    return np.hypot(XS - c[0], YS - c[1]) <= r


def ramp(origin, along, length):
    ux, uy = math.cos(math.radians(along)), math.sin(math.radians(along))
    return np.clip(((XS - origin[0]) * ux + (YS - origin[1]) * uy) / float(length), 0, 1)


def leafmask(base, bx):
    return close(box(*bx) & leafy(base), 1)


def rooty(base):
    """人蔘皮的黃。"""
    h, s, v = hsv(base)
    return (h > 22) & (h < 50) & (s > 0.42) & (v > 0.55)


def legmask(base, bx, seeds, extra=None):
    """衣襬底下露出來的腿：框裡面人蔘皮顏色、而且連著 seeds 的那幾塊。"""
    m = box(*bx) & rooty(base)
    if extra is not None:
        m &= extra
    return grow(flood(close(m, 1), *seeds), 1)


def actor(rg, mask, legs, band, posefn, pad=2):
    """背景乾淨、切得出零件的那幾張。上半身（頭、手、衣服）整塊照姿勢位移，一格都不變形；
    腿墊在下面，band=(衣襬的高度, 腳底) 之間壓短或拉長，腳不動。
    回傳身體零件、身體這一格往下移了幾格（給葉子頭髮當推力）、取姿勢的函式。"""
    P, D = stance(posefn)
    rg.part('legs', legs, lambda f: [tie(band[0], band[1], *D(f))])
    body = rg.part('body', grow(mask, pad) if pad else mask, lambda f: [shift(*D(f))])
    return body, (lambda f: D(f)[1]), P


def floater(rg, outline, posefn, legs=None, r=3):
    """背景複雜、衣服和飄帶佔滿畫面的那幾張：不切零件，整個人當一整塊照姿勢位移，輪廓外的背景漸漸歸零，所以沒有接縫。
    outline 是把整個人（含衣服、飄帶、道具）粗略圈起來的多邊形，不用很準。
    legs=(x0, y0, x1, y1) 表示腳踩在地上：那個框裡 y0 以上跟著走、y1 以下不動，中間的腿壓短或拉長。沒給就是整個人浮著。
    回傳身體這一格往下移了幾格、取姿勢的函式。"""
    P, D = stance(posefn)
    reach = max(max(abs(v) for v in D(f)) for f in range(N))
    B = poly(outline)
    W = np.maximum(feather(grow(B, reach + 2 * r), r), grow(B, reach).astype(np.float32))
    rg.regions['figure'] = W
    if legs:
        x0, y0, x1, y1 = legs
        L = feather(box(x0 - 2 * r, y0 - 2 * r, x1 + 2 * r, GH - 1), r)

    def field(f):
        dx, dy = D(f)
        if not legs or (dx == 0 and dy == 0):
            return [(W * dx, W * dy)]
        top = y0 + dy
        span = max(1.0, y1 - top)
        src = np.where(YS <= top, YS - dy, np.where(YS >= y1, YS, y1 - (y1 - YS) * (y1 - y0) / span))
        Wl = W * (1 - L * (1 - np.clip((y1 - src) / float(y1 - y0), 0, 1)))
        return [(Wl * dx, Wl * dy)]
    rg.soft.append(field)
    return (lambda f: D(f)[1]), P


def leaves(rg, base, bx, pivot, heady, length=45, k=0.8):
    """葉子和紅果：頭往下一沉，葉尖慢一拍、先翹起來再甩下去，盪幾下才停。"""
    W = rg.region('leaves', grow(leafmask(base, bx), 7), 3)
    lim = lambda v, m: max(-m, min(m, v))
    rg.soft.append(lambda f: [f_flap(W, pivot, lim(-k * follow(heady, f), 4), length), f_bend(W, pivot, lim(0.4 * follow(heady, f - 1), 3), length)])


def sway(rg, name, mask, along, amp, wavelength, period, phase=0.0, r=3, anchor=None, gain=None):
    """一束頭髮、一條髮帶或一片雲的起伏。不要用在衣服上（袖子、衣襬、飄帶的花紋會被扯得很怪）。anchor=(x, y, 長度) 表示從那一點開始越遠擺越大。"""
    W = rg.region(name, mask, r)
    if anchor:
        W = W * ramp(anchor[:2], along, anchor[2])
    rg.soft.append(lambda f: [f_wave(W, along, amp * (gain(f) if gain else 1.0), wavelength, TAU * (f / float(period) + phase))])


def kick(heady, k=0.3):
    """身體一動，頭髮和布料跟著甩大一點。"""
    return lambda f: 1 + k * abs(follow(heady, f))


def motes(rg, pts, rise=1.6, col=GOLD):
    def fx(img, f):
        for i, (x, y) in enumerate(pts):
            g = (f + i * 7) % N
            a = math.sin(math.pi * g / N)
            if i % 2 == 0:
                plus(img, x + 1.5 * math.sin(g / 5.0 + i), y - g * rise, col, a)
            else:
                dot(img, x + 1.5 * math.sin(g / 5.0 + i), y - g * rise, WHITE, a)
    rg.front.append(fx)


def flash(amount):
    def post(img, f):
        a = amount.get(f, 0)
        return img * (1 - a) + FLASH * a if a else img
    return post


def dim(amount):
    def post(img, f):
        a = amount.get(f, 0)
        return img * (1 - a) if a else img
    return post


def shake(amount):
    def post(img, f):
        s = amount.get(f, 0)
        return np.roll(img, s, axis=1) if s else img
    return post


def bolt(img, pts, a=1.0, wide=True):
    for p0, p1 in zip(pts, pts[1:]):
        line(img, (p0[0] - 1, p0[1]), (p1[0] - 1, p1[1]), GOLD, a * 0.9)
        line(img, (p0[0] + 2, p0[1]), (p1[0] + 2, p1[1]), GOLD, a * 0.6)
        line(img, p0, p1, WHITE, a, wide=wide)


def burst(img, c, g, n=8, r0=6, step=3, col=GOLD):
    """一圈往外散的火花。g 是散開後第幾格。"""
    for k in range(n):
        t = TAU * k / n + 0.3
        dot(img, c[0] + (r0 + g * step) * math.cos(t), c[1] + (r0 + g * step) * math.sin(t), col if k % 2 else WHITE, 1 - g * 0.2)


# ---------- 煉氣 ----------
BUCKET = [(106, 128), (126, 126), (144, 134), (145, 150), (142, 170), (138, 180), (112, 180), (107, 168), (105, 148)]


def woody(base):
    h, s, v = hsv(base)
    return (h > 12) & (h < 48) & (s > 0.34) & (lum(base) < 205)


def scene0(rg):
    sway(rg, 'banner', box(16, 84, 35, 122), 90, 1.6, 30, 24, anchor=(25, 84, 24))
    Wl = rg.region('lantern', box(135, 75, 154, 103), 2)
    rg.soft.append(lambda f: [f_bend(Wl, (144, 74), 4.0 * cyc(f, 48, 0.2), 26)])
    flick = [.2, .5, .35, .6, .25, .55, .3, .5, .2, .45, .6, .35]
    rg.front.append(lambda img, f: glow(img, 144, 88, 13, flick[(f // 2) % 12], PALE))


def bucket0(rg, base, body, arm_poly, arm_mv, swing):
    arm = rg.part('arm', grow(cut(base, arm_poly, seeds=[(123, 128)]), 1), arm_mv, body)
    bk = grow(close(cut(base, BUCKET, bg=~woody(base), seeds=[(125, 160)]) | (poly([(111, 144), (139, 144), (138, 151), (112, 151)])), 4), 1)
    rg.parts.insert(len(rg.parts) - 1, Part('bucket', bk & ~arm.mask, lambda f: [rot((125, 135), swing(f))], arm))


def rig_r0(base, blink):
    """煉氣男：開心地一拍彈一下。中間掂一次水桶：先蹲、手往下沉，一口氣把桶提起來，放下時桶盪幾下、水濺出來。"""
    rg = Rig(base)
    bx = (28, 0, 138, 64)
    torso = cut(base, [(72, 42), (98, 42), (108, 58), (118, 75), (120, 90), (112, 98), (120, 104), (126, 112), (124, 124), (118, 128),
                       (116, 140), (118, 156), (100, 160), (88, 154), (78, 160), (56, 156), (52, 140), (56, 128), (48, 118), (50, 104),
                       (60, 98), (62, 90), (60, 75), (66, 56)], seeds=[(88, 75)])
    wisps = (cut(base, [(36, 60), (64, 60), (64, 112), (40, 112)]) | cut(base, [(104, 58), (117, 60), (121, 74), (127, 84), (127, 94), (112, 94)])) & ~leafy(base)

    def P(f):
        bounce = sum(seq(f, a, [1, -2, -1]) for a in (2, 10, 38, 50, 58, 86))
        rest = -breathe(f) if 64 <= f < 80 else 0
        return pose(sq=bounce + rest + seq(f, 20, [1, 2, 2, -2, -2, -1, 0, 1]), ln=keys(f, [(19, 0), (22, 0.5), (24, -0.3), (30, 0)]))
    legs = legmask(base, (40, 146, 112, 199), [(60, 172), (90, 172), (58, 180), (92, 180)])
    body, heady, _ = actor(rg, torso | leafmask(base, bx) | wisps, legs, (158, 196), P)
    lift = lambda f: seq(f % N, 20, [1, 2, 2, -5, -6, -4, -1, 1])
    load_y = lambda f: heady(f) + lift(f)
    bucket0(rg, base, body, [(113, 114), (124, 112), (132, 128), (132, 140), (118, 140), (114, 126)],
            lambda f: [shift(0, lift(f))], lambda f: 1.3 * follow(load_y, f, 0.2, 1.0, 24))
    leaves(rg, base, bx, (84, 42), heady)
    sway(rg, 'wisp_l', box(36, 62, 62, 112), 90, 1.6, 34, 24, 0.2, anchor=(60, 62, 30), gain=kick(heady))
    sway(rg, 'wisp_r', box(111, 60, 127, 94), 90, 1.4, 30, 24, 0.5, r=2, anchor=(108, 60, 24), gain=kick(heady))
    scene0(rg)

    def splash(img, f):
        t = f - 24
        if 0 <= t < 5:
            for k in (-1, 0, 1):
                dot(img, 125 + k * (4 + 3 * t), 142 + int(heady(f)) - 5 * t + 1.3 * t * t, WHITE, 1 - t * 0.18)
                dot(img, 125 + k * (4 + 3 * t), 143 + int(heady(f)) - 5 * t + 1.3 * t * t, PALE, 0.7 - t * 0.12)
    rg.front.append(splash)
    if blink is not None:
        rg.blink(blink, [14, 15, 70, 71])
    return rg


def rig_gr0(base, blink):
    """煉氣女：提著桶一拍一拍左右搖，髮帶和長髮跟著甩，桶慢半拍往反方向盪。搖一陣子，原地踮兩下。"""
    rg = Rig(base)
    bx = (28, 0, 138, 62)
    torso = cut(base, [(72, 40), (98, 40), (110, 54), (120, 70), (130, 92), (130, 112), (126, 120), (120, 124), (118, 140), (120, 158),
                       (108, 164), (92, 158), (78, 164), (58, 160), (52, 142), (42, 150), (34, 130), (38, 104), (34, 92), (36, 78),
                       (46, 66), (52, 54), (62, 48)], seeds=[(88, 75)])

    def P(f):
        still = 22 <= f < 36 or 64 <= f < 80
        rest = -breathe(f) if 64 <= f < 80 else 0
        return pose(sq=rest + seq(f, 24, [1, -2, -1, 0.5]) + seq(f, 30, [1, -2, -1, 0.5]), ln=0 if still else 1.2 * SW[(f // 2) % 8])
    legs = legmask(base, (40, 148, 112, 199), [(60, 176), (90, 176), (58, 184), (92, 184)])
    body, heady, PP = actor(rg, torso | leafmask(base, bx), legs, (160, 196), P)
    tilt = lambda f: 2.5 * PP(f)['ln']
    bucket0(rg, base, body, [(114, 114), (126, 114), (132, 128), (132, 140), (119, 140), (115, 126)],
            lambda f: [], lambda f: -2.0 * follow(tilt, f, 0.25, 0.9, 24) + 1.2 * follow(heady, f, 0.25, 1.0, 24))
    both = lambda f: 1 + 0.3 * abs(follow(heady, f)) + 0.35 * abs(follow(tilt, f))
    leaves(rg, base, bx, (84, 42), lambda f: heady(f) + 0.6 * tilt(f))
    sway(rg, 'ribbon', box(38, 62, 60, 102), 90, 2.0, 30, 24, -0.1, anchor=(52, 62, 26), gain=both)
    sway(rg, 'hair_l', box(36, 96, 50, 150), 90, 1.8, 40, 24, -0.2, r=2, anchor=(46, 92, 36), gain=both)
    sway(rg, 'hair_r', box(113, 62, 130, 120), 90, 1.5, 36, 24, -0.25, r=2, anchor=(112, 60, 36), gain=both)
    scene0(rg)
    if blink is not None:
        rg.blink(blink, [16, 17, 68, 69])
    return rg


# ---------- 築基 ----------
SWORD = [(146, 37), (154, 38), (156, 46), (138, 84), (137, 91), (127, 92), (124, 104), (112, 104), (111, 92), (118, 84), (119, 76), (142, 44)]


def swordsman(rg, base, torso, legs, band, arm_poly, shoulder, sw, P, bx):
    body, heady, _ = actor(rg, torso | leafmask(base, bx), legs, band, P)
    arm = rg.part('arm', grow(cut(base, arm_poly, seeds=[(110, 106)]), 1), lambda f: [rot(shoulder, 0.45 * sw(f % N))], body)
    blade = cut(base, SWORD, seeds=[(140, 60)])
    rg.part('sword', grow(blade, 1) & (lum(base) < 250) & poly(SWORD) | blade, lambda f: [rot((118, 97), 0.55 * sw(f % N))], arm)
    return heady


def smear(rg, spans, sparks, heady):
    """劍劈下去那一兩格的殘影。spans 是 {格: (起始角, 結束角, 濃度)}。"""
    rest = math.degrees(math.atan2(41 - 97, 150 - 118))

    def fx(img, f):
        oy = 97 + heady(f)
        if f in spans:
            a0, a1, alpha = spans[f]
            d = a0
            while d <= a1:
                t = math.radians(rest + d)
                k = (d - a0) / float(a1 - a0)
                for r in range(34, 64):
                    dot(img, 116 + r * math.cos(t), oy + r * math.sin(t), PALE if r % 2 else WHITE, alpha * k * (0.4 + 0.6 * (r - 34) / 30.0))
                d += 0.5
        if f in sparks:
            t = math.radians(rest + sparks[f])
            plus(img, 116 + 65 * math.cos(t), oy + 65 * math.sin(t), GOLD)
    rg.front.append(fx)


def rig_r1(base, blink):
    """築基男：先蹲一下，把劍慢慢舉過頭、整個人跟著拉長，一格劈下來、身體壓扁往前帶，再彈回站好。"""
    rg = Rig(base)
    bx = (25, 0, 138, 64)
    sw = lambda f: keys(f, [(16, 0), (24, -32), (26, -34), (27, -8), (28, 18), (29, 20), (32, 12), (40, 0)])

    def P(f):
        if f < 14 or f >= 48:
            return pose(sq=-breathe(f))
        return pose(sq=seq(f, 16, [1, 2, 1, 0, -0.5, -1, -1.5, -2, -2, -2, -2, 1, 3, 3, 2, 1, -0.5]),
                    ln=keys(f, [(19, 0), (26, -0.8), (27, 0), (28, 1.2), (31, 1.0), (38, 0)]))
    torso = cut(base, [(72, 43), (90, 42), (100, 55), (106, 68), (107, 82), (103, 92), (110, 93), (124, 98), (122, 106), (117, 112), (114, 128),
                       (118, 140), (128, 148), (126, 160), (118, 166), (100, 168), (88, 163), (78, 168), (58, 166), (40, 160), (38, 148),
                       (28, 142), (30, 130), (44, 126), (42, 116), (50, 110), (60, 104), (62, 96), (66, 90), (62, 78), (63, 62), (68, 50)], seeds=[(85, 70)])
    wisps = (cut(base, [(36, 60), (64, 60), (64, 95), (58, 112), (38, 112), (34, 90)]) | cut(base, [(104, 58), (120, 60), (120, 92), (108, 92), (106, 80)])) & ~leafy(base)
    legs = legmask(base, (30, 150, 126, 198), [(56, 178), (100, 178), (60, 172), (96, 172)])
    heady = swordsman(rg, base, torso | wisps, legs, (164, 194), [(98, 93), (110, 90), (118, 92), (124, 98), (122, 106), (117, 112), (114, 128), (106, 128), (102, 112)],
                      (100, 100), sw, P, bx)
    leaves(rg, base, bx, (82, 42), heady)
    sway(rg, 'wisp_l', box(34, 60, 62, 112), 90, 1.6, 34, 24, 0.2, anchor=(62, 60, 30), gain=kick(heady))
    sway(rg, 'wisp_r', box(110, 60, 121, 92), 90, 1.4, 30, 24, 0.5, r=2, anchor=(106, 60, 22), gain=kick(heady))
    smear(rg, {27: (-34, -8, 0.85), 28: (-8, 18, 0.55), 29: (12, 20, 0.25)}, {28: 18, 29: 19}, heady)
    if blink is not None:
        rg.blink(blink, [10, 11, 66, 67])
    return rg


def rig_gr1(base, blink):
    """築基女：連點兩劍。第一下短，縮一下就刺；第二下蓄久一點、整個人往前送，裙襬和髮帶甩開再收回來。"""
    rg = Rig(base)
    bx = (25, 0, 138, 62)
    sw = lambda f: keys(f, [(10, 0), (13, -14), (14, 10), (15, 12), (18, 0), (20, 0), (23, -20), (24, 14), (25, 16), (28, 8), (36, 0)])

    def P(f):
        if f < 10 or f >= 48:
            return pose(sq=-breathe(f))
        return pose(sq=seq(f, 11, [0.5, 1, 1, -1, -0.5]) + seq(f, 20, [0.5, 1, 2, 2, -2, 1, 1, -0.5]),
                    ln=keys(f, [(12, 0), (13, -0.4), (14, 0.6), (17, 0), (22, 0), (23, -0.6), (24, 1.0), (27, 0.6), (34, 0)]))
    torso = cut(base, [(72, 40), (98, 40), (110, 56), (118, 72), (121, 92), (126, 100), (124, 110), (120, 126), (114, 128), (120, 140), (130, 150),
                       (128, 162), (118, 168), (100, 170), (88, 164), (76, 170), (56, 168), (44, 160), (42, 148), (30, 144), (32, 134),
                       (44, 128), (36, 118), (38, 104), (34, 96), (36, 84), (46, 72), (48, 58), (58, 48)], seeds=[(88, 75)])
    legs = legmask(base, (30, 152, 126, 198), [(52, 180), (100, 180), (58, 174), (96, 174)])
    heady = swordsman(rg, base, torso, legs, (166, 194), [(98, 95), (112, 92), (120, 94), (127, 100), (126, 110), (122, 126), (108, 128), (102, 112)],
                      (100, 102), sw, P, bx)
    leaves(rg, base, bx, (84, 42), heady)
    sway(rg, 'ribbon', box(34, 64, 62, 100), 90, 1.8, 30, 24, 0.1, anchor=(52, 64, 26), gain=kick(heady, 0.4))
    sway(rg, 'hair_l', box(34, 98, 48, 132), 90, 1.6, 36, 24, 0.25, r=2, anchor=(44, 94, 30), gain=kick(heady, 0.4))
    sway(rg, 'hair_r', box(112, 60, 122, 102), 90, 1.3, 30, 24, 0.5, r=2, anchor=(108, 60, 26), gain=kick(heady))
    smear(rg, {14: (-14, 10, 0.6), 24: (-20, 14, 0.85), 25: (8, 16, 0.4)}, {15: 12, 25: 16, 26: 16}, heady)
    if blink is not None:
        rg.blink(blink, [40, 41, 74, 75])
    return rg


# ---------- 金丹 ----------
def core_fx(rg, c, pos, sparks=3, radius=12, catch=None, trail=None):
    """金丹的光：跟著金丹走的光暈、繞著它轉的光點、接住那一下的火花。pos(f) 回傳金丹這一格在畫面上的位移。"""
    def fx(img, f):
        dx, dy = pos(f)
        x, y = c[0] + dx, c[1] + dy
        glow(img, x, y, 17, .12 + .22 * (.5 + .5 * cyc(f, 12)), PALE)
        for k in range(sparks):
            t = TAU * (f / 16.0 + k / float(sparks))
            qx, qy = x + radius * math.cos(t), y + radius * 0.8 * math.sin(t)
            plus(img, qx, qy, GOLD) if k == 0 else dot(img, qx, qy, WHITE)
        if trail:
            for j in range(1, trail + 1):
                tx, ty = pos(f - j)
                if abs(tx - dx) + abs(ty - dy) >= 2:
                    dot(img, c[0] + tx, c[1] + ty, PALE, 0.75 - 0.15 * j)
        if catch is not None and 0 <= f - catch < 5:
            burst(img, (x, y), f - catch)
    rg.front.append(fx)


def rig_r2(base, blink):
    """金丹男：手往下一沉、人蹲一下，往上一送把金丹拋高，頭跟著抬起來看；落回掌心時整個人一頓，迸出一圈火花。"""
    rg = Rig(base)
    bx = (22, 0, 132, 58)
    c = (135, 57)
    toss = {23: -6, 24: -12, 25: -17, 26: -20, 27: -21, 28: -20, 29: -17, 30: -12, 31: -6}
    h, s, v = hsv(base)
    core = grow(flood(disc(c, 11) & (s > 0.42), c), 1)

    def P(f):
        if f < 16 or f >= 48:
            return pose(sq=-breathe(f))
        return pose(sq=seq(f, 20, [1, 2, 2, -2, -1, -.5, -.5, -.5, -.5, -.5, -.5, -.5, 2, 1, -1]), ln=keys(f, [(23, 0), (25, 0.6), (30, 0.6), (33, 0)]))
    mask = cut(base, [(66, 36), (102, 36), (114, 60), (118, 74), (124, 62), (152, 62), (154, 80), (167, 104), (167, 156), (4, 156), (4, 120),
                      (28, 98), (34, 90), (34, 56), (58, 56)], seeds=[(88, 70)]) | leafmask(base, bx)
    legs = legmask(base, (44, 146, 112, 190), [(62, 168), (90, 168), (60, 174), (94, 174)])
    body, heady, _ = actor(rg, mask & ~core, legs, (156, 186), P)
    rg.part('core', core, lambda f: [shift(0, toss.get(f % N, 0))], body)
    leaves(rg, base, bx, (82, 38), heady)
    sway(rg, 'wisp_l', box(34, 58, 68, 96), 90, 1.5, 34, 24, 0.2, anchor=(68, 58, 30), gain=kick(heady))
    core_fx(rg, c, lambda f: (0, toss.get(f % N, 0) + heady(f)), catch=32, trail=3)
    if blink is not None:
        rg.blink(blink, [12, 13, 68, 69])
    return rg


def rig_gr2(base, blink):
    """金丹女：金丹在掌心上方繞圈，後面拖一串光點，身體跟著它輕輕左右傾。繞到第二圈，縮一下、往上一挺，盪出一圈光環。"""
    rg = Rig(base)
    bx = (22, 0, 132, 56)
    c = (136, 60)
    orbit = lambda f: (int(round(5 * math.cos(TAU * f / 24.0))), int(round(3.5 * math.sin(TAU * f / 24.0) - 2)))
    h, s, v = hsv(base)
    core = grow(flood(disc(c, 11) & (s > 0.42), c), 1)

    def P(f):
        return pose(sq=(-breathe(f) if (f < 32 or f >= 48) else 0) + seq(f, 34, [1, 2, -2, -1, 1]), ln=0.6 * math.cos(TAU * f / 24.0))
    mask = cut(base, [(60, 34), (104, 34), (116, 60), (120, 76), (126, 64), (154, 64), (156, 82), (167, 104), (167, 160), (4, 160), (4, 120),
                      (24, 100), (26, 80), (40, 52), (52, 38)], seeds=[(88, 72)]) | leafmask(base, bx)
    legs = legmask(base, (44, 150, 114, 190), [(62, 172), (92, 172), (60, 178), (96, 178)])
    body, heady, _ = actor(rg, mask & ~core, legs, (160, 186), P)
    rg.part('core', core, lambda f: [shift(*orbit(f))], body)
    leaves(rg, base, bx, (82, 38), heady)
    sway(rg, 'ribbon', box(44, 56, 68, 96), 90, 2.0, 30, 24, 0.0, anchor=(58, 56, 28), gain=kick(heady, 0.4))
    sway(rg, 'hair_r', box(114, 60, 126, 100), 90, 1.3, 30, 24, 0.5, r=2, anchor=(110, 58, 26))
    core_fx(rg, c, lambda f: (orbit(f)[0], orbit(f)[1] + heady(f)), sparks=2, radius=13, trail=5)

    def pulse(img, f):
        g = f - 36
        if 0 <= g < 10:
            r = 9 + g * 2.4
            for k in range(0, 360, 10):
                t = math.radians(k + g * 5)
                dot(img, c[0] + r * math.cos(t), c[1] - 2 + heady(f) + r * math.sin(t), PALE if (k // 10) % 2 else GOLD, 0.95 - g * 0.09)
    rg.front.append(pulse)
    if blink is not None:
        rg.blink(blink, [20, 21, 72, 73])
    return rg


# ---------- 元嬰 ----------
def clouds(rg, boxes, amp=1.5):
    for i, b in enumerate(boxes):
        sway(rg, 'cloud%d' % i, box(*b), 0, amp, 56, 48, i * 0.3, r=4)


def staff_mask(base):
    wood = (lum(base) < 180) & (base[..., 0] - base[..., 2] > 50)
    staff = close(poly([(114, 40), (160, 40), (160, 86), (146, 102), (144, 190), (126, 192), (124, 104), (118, 98), (114, 70)]) & wood, 1)
    return grow(flood(staff, (134, 150), (140, 60)) | cut(base, [(128, 98), (144, 98), (144, 112), (128, 112)]), 1)


OUT3 = [(78, 0), (98, 0), (132, 12), (134, 34), (164, 36), (166, 100), (168, 120), (168, 160), (150, 170), (150, 196), (112, 200), (56, 200),
        (52, 172), (20, 168), (0, 150), (0, 118), (18, 100), (22, 84), (30, 76), (28, 58), (50, 50), (34, 40), (36, 12)]
OUT3G = [(78, 0), (98, 0), (128, 12), (130, 34), (164, 36), (166, 100), (168, 118), (168, 162), (150, 172), (150, 196), (112, 200), (56, 200),
         (52, 174), (20, 170), (0, 154), (0, 112), (22, 98), (28, 84), (26, 60), (40, 44), (32, 36), (34, 12)]


def rig_r3(base, blink):
    """元嬰男：慢慢呼吸。把手杖提起來、人跟著拉長，往地上一頓，整個人壓扁、畫面震一下，腳邊盪開兩圈光紋，流蘇和鬍鬚被震得甩起來。"""
    rg = Rig(base)
    bx = (35, 0, 136, 52)
    staff = staff_mask(base)

    def P(f):
        if f < 18 or f >= 48:
            return pose(sq=-breathe(f, 12, 4))
        return pose(sq=seq(f, 21, [-0.5, -1, -1.5, -2, -2, -2, 2, 3, 2, 1, -1]))
    heady, _ = floater(rg, OUT3, P)
    lift = lambda f: keys(f % N, [(20, 0), (25, -7), (26, -7), (27, 0)])
    rg.part('staff', staff, lambda f: [shift({27: 1, 28: -1}.get(f % N, 0), lift(f))])
    Wt = rg.region('tassel', box(121, 58, 139, 100), 2)
    rg.soft.append(lambda f: [f_bend(Wt, (131, 58), 2.0 * cyc(f, 24) + 1.6 * follow(lift, f, 0.25, 1.1, 24), 40)])
    leaves(rg, base, bx, (88, 22), heady, 50, 0.6)
    clouds(rg, [(0, 182, 46, 209), (152, 182, 167, 209)])
    rg.front.append(lambda img, f: glow(img, 86, 38 + heady(f), 15, .12 + .30 * (.5 + .5 * cyc(f, 24, -0.25)), PALE))

    def ripple(img, f):
        for delay in (0, 4):
            g = f - 27 - delay
            if 0 <= g < 12:
                rx = 7 + g * 3.4
                for k in range(0, 360, 6):
                    if (k // 6 + g) % 2:
                        continue
                    t = math.radians(k)
                    x, y = 133 + rx * math.cos(t), 189 + rx * 0.26 * math.sin(t)
                    dot(img, x, y, AMBER, 0.95 * (1 - g / 14.0))
                    dot(img, x + 1, y, AMBER, 0.8 * (1 - g / 14.0))
                    dot(img, x, y - 1, GOLD, 0.8 * (1 - g / 12.0))
        if f in (27, 28):
            plus(img, 133, 187, GOLD)
    rg.front.append(ripple)
    rg.post.append(shake({27: 1, 28: -1}))
    return rg


def rig_gr3(base, blink):
    """元嬰女：慢慢呼吸。兩隻手各升起一顆光點，繞個彎匯進頭頂的元嬰；匯進去那一格人縮一下、往上一挺，元嬰亮起來、盪出一圈光。"""
    rg = Rig(base)
    bx = (32, 0, 136, 54)
    staff = staff_mask(base)
    hit = 20

    def P(f):
        idle_ = -breathe(f, 12, 4) if (f < 16 or f >= 24) else 0
        return pose(sq=idle_ + seq(f, hit - 1, [1, -2, -1, 1]))
    heady, _ = floater(rg, OUT3G, P)
    Wt = rg.region('tassel', box(120, 56, 140, 100), 2)
    rg.soft.append(lambda f: [f_bend(Wt, (131, 58), 3.0 * cyc(f, 24), 40)])
    sway(rg, 'hairpin', box(40, 46, 60, 90), 90, 1.5, 30, 24, 0.0, r=2, anchor=(54, 46, 30), gain=kick(heady, 0.5))
    leaves(rg, base, bx, (86, 22), heady, 50, 0.6)
    clouds(rg, [(0, 184, 46, 209), (152, 184, 167, 209)])

    def gather(img, f):
        hot = max(0.0, 1 - abs(f - hit - 2) / 5.0)
        glow(img, 86, 34 + heady(f), 16, .12 + .22 * (.5 + .5 * cyc(f, 24, -0.25)) + .4 * hot, PALE)
        for side, (sx, sy) in enumerate(((40, 90), (136, 100))):
            g = f - 2
            if 0 <= g < hit - 2:
                for j in range(4):
                    t = ease(max(0, g - j) / float(hit - 3))
                    x = sx + (86 - sx) * t + (1 - 2 * side) * 18 * math.sin(math.pi * t)
                    y = sy + (34 - sy) * t - 10 * math.sin(math.pi * t)
                    plus(img, x, y, GOLD, 0.95) if j == 0 else dot(img, x, y, PALE, 0.75 - 0.18 * j)
        if 0 <= f - hit < 6:
            g = f - hit
            for k in range(0, 360, 20):
                t = math.radians(k + g * 8)
                dot(img, 86 + (6 + g * 3) * math.cos(t), 34 + heady(f) + (6 + g * 3) * 0.8 * math.sin(t), PALE, 0.95 - g * 0.15)
    rg.front.append(gather)
    return rg


# ---------- 化神 ----------
def night(rg, base, stars, meteors):
    sky = (base[..., 2] > base[..., 0] + 18) & (lum(base) < 190)

    def fx(img, f):
        for i, (x, y) in enumerate(stars):
            if not sky[y, x]:
                continue
            ph = (f + i * 5) % 16
            if ph < 3:
                plus(img, x, y, WHITE)
            elif ph < 7:
                dot(img, x, y, WHITE)
            elif ph < 9:
                dot(img, x, y, WHITE, 0.5)
        for start, x0, y0, vx, vy, n in meteors:
            g = f - start
            if 0 <= g <= n:
                speed = 0.6 + 0.8 * g / float(n)
                hx, hy = x0 + vx * g * speed, y0 + vy * g * speed
                for j in range(10):
                    x, y = hx - vx * j * 0.45, hy - vy * j * 0.45
                    xi, yi = int(round(x)), int(round(y))
                    if 0 <= xi < GW and 0 <= yi < GH and sky[yi, xi]:
                        dot(img, x, y, WHITE if j < 2 else PALE, (1 - j * 0.1) * min(1.0, (n - g + 1) / 2.0))
    rg.front.append(fx)


OUT4 = [(70, 0), (96, 0), (120, 14), (118, 40), (108, 46), (168, 50), (168, 158), (120, 160), (104, 170), (100, 190), (64, 190), (56, 170),
        (24, 160), (0, 150), (0, 48), (60, 48), (28, 36), (30, 12)]
OUT4G = [(72, 0), (96, 0), (118, 14), (116, 40), (108, 44), (168, 50), (168, 160), (120, 162), (106, 170), (102, 188), (64, 188), (56, 170),
         (24, 165), (0, 150), (0, 48), (56, 44), (34, 36), (36, 12)]


def rig_r4(base, blink):
    """化神男：整個人在夜空裡慢慢浮上浮下。深吸一口氣、身體慢慢拉長，停住，一口吐出來、身體一沉，星光從身邊散開。流星由慢到快劃過去。"""
    rg = Rig(base)
    bx = (35, 0, 132, 50)

    def P(f):
        return pose(dy=1.3 * math.sin(TAU * f / 48.0), sq=seq(f, 18, [-0.4, -0.8, -1.2, -1.6, -2, -2, -2, -2, -2, -2, -2, 1, 2, 1]))
    heady, _ = floater(rg, OUT4, P)
    leaves(rg, base, bx, (86, 30), heady, 45, 0.6)
    night(rg, base, [(26, 38), (48, 24), (120, 22), (142, 36), (152, 62), (20, 70), (114, 46), (60, 44), (136, 20), (30, 56)],
          [(4, 162, 22, -5.0, 3.4, 9)])

    def exhale(img, f):
        g = f - 29
        if 0 <= g < 8:
            for k in range(12):
                t = TAU * k / 12.0 + 0.2
                r = 34 + g * 5
                x, y = 88 + r * math.cos(t), 100 + heady(f) + r * 0.8 * math.sin(t)
                plus(img, x, y, WHITE, 1 - g / 8.0) if k % 3 == 0 else dot(img, x, y, PALE, 1 - g / 8.0)
    rg.front.append(exhale)
    return rg


def rig_gr4(base, blink):
    """化神女：浮在夜空裡。四周的星光一顆顆被吸過來、繞個彎落進兩邊掌心；吸夠了，縮一下、往上一挺，兩掌的光一起炸開。"""
    rg = Rig(base)
    bx = (35, 0, 130, 48)
    hit = 34

    def P(f):
        return pose(dy=1.3 * math.sin(TAU * (f / 48.0 + 0.5)), sq=seq(f, hit - 2, [1, 2, -2, -2, -1, 1]))
    heady, _ = floater(rg, OUT4G, P)
    leaves(rg, base, bx, (86, 30), heady, 45, 0.6)
    night(rg, base, [(26, 40), (50, 26), (122, 24), (150, 60), (20, 72), (60, 44), (30, 58)], [])
    palms = ((50, 82), (139, 80))
    srcs = [(14, 36, 0), (150, 30, 3), (36, 14, 6), (128, 14, 9), (8, 70, 12), (160, 64, 15), (60, 30, 18), (112, 36, 21)]

    def gather(img, f):
        oy = heady(f)
        for i, (sx, sy, start) in enumerate(srcs):
            qx, qy = palms[i % 2]
            g = f - start
            if 0 <= g < 12:
                for j in range(4):
                    t = max(0.0, (g - j) / 11.0) ** 1.8
                    bow = (1 if i % 2 else -1) * 12 * math.sin(math.pi * t)
                    x, y = sx + (qx - sx) * t + bow * 0.4, sy + (qy + oy - sy) * t - abs(bow)
                    plus(img, x, y, WHITE, 0.95) if j == 0 else dot(img, x, y, PALE, 0.75 - 0.2 * j)
        charge = min(1.0, max(0.0, (f - 10) / 22.0)) if f < hit else max(0.0, 1 - (f - hit) / 8.0)
        for x, y in palms:
            glow(img, x, y - 3 + oy, 10, .12 + .3 * charge, PALE)
            if 0 <= f - hit < 6:
                glow(img, x, y - 3 + oy, 16, .5 * (1 - (f - hit) / 6.0), WHITE)
                burst(img, (x, y - 3 + oy), f - hit, 8, 5, 3, PALE)
    rg.front.append(gather)
    return rg


# ---------- 大乘 ----------
OUT5 = [(70, 0), (100, 0), (126, 14), (126, 44), (110, 50), (168, 50), (168, 150), (140, 165), (112, 170), (106, 196), (58, 196), (52, 170),
        (20, 160), (0, 145), (0, 55), (56, 50), (44, 44), (44, 14)]
OUT5G = [(70, 0), (100, 0), (122, 14), (122, 44), (112, 50), (168, 50), (168, 150), (140, 168), (112, 172), (106, 194), (58, 194), (52, 172),
         (20, 165), (0, 150), (0, 60), (40, 48), (40, 14)]


def rig_r5(base, blink):
    """大乘男：浮在雲上慢慢起伏。縮一下、兩手往上一托，背後的光輪盪出一圈金環，皇冠上的寶石閃一下，再慢慢落定。背後的佛光一直在轉。"""
    rg = Rig(base)
    bx = (40, 0, 138, 56)
    light = (lum(base) > 205).astype(np.float32)
    c = (88, 52)
    hit = 22

    def P(f):
        return pose(dy=1.0 * math.sin(TAU * f / 48.0), sq=seq(f, hit - 2, [1, 2, -2, -2, -1, -1, -1, -1, 0.5]))
    heady, _ = floater(rg, OUT5, P)
    leaves(rg, base, bx, (88, 38), heady, 45, 0.6)
    clouds(rg, [(0, 184, 50, 202), (122, 184, 167, 202)])

    def halo(img, f):
        tmp = img.copy()
        for k in range(12):
            t = math.radians(k * 30 + f * 30.0 / N)
            if math.sin(t) > 0.2:
                continue
            for r in range(60, 80):
                a = 0.75 * (1 - (r - 60) / 26.0)
                dot(tmp, c[0] + r * math.cos(t), c[1] + r * math.sin(t), PALE, a)
                dot(tmp, c[0] + r * math.cos(t) + 1, c[1] + r * math.sin(t), WHITE, a * 0.6)
        g = f - hit
        if 0 <= g < 12:
            r = 56 + g * 2.8
            for k in range(0, 360, 2):
                t = math.radians(k)
                for dr, col, a in ((0, AMBER, 0.9), (-1, GOLD, 0.9), (-2, WHITE, 0.6)):
                    dot(tmp, c[0] + (r + dr) * math.cos(t), c[1] + (r + dr) * math.sin(t), col, a * (1 - g / 12.0))
        lt = rg.warp(light)          # 光只畫在背景上；人移動了，背景的範圍要跟著算
        img[:] = img * (1 - lt[..., None]) + tmp * lt[..., None]
        glow(img, c[0], c[1], 74, .04 + .10 * (.5 + .5 * cyc(f, 24)) + (.22 * max(0.0, 1 - abs(g - 1) / 4.0)), PALE, only=lt)
        if 0 <= g < 4:
            plus(img, 87, 36 + heady(f), WHITE, 1.0 if g < 3 else 0.5)
    rg.front.append(halo)
    motes(rg, [(18, 176), (40, 150), (62, 190), (110, 186), (132, 150), (152, 178)])
    if blink is not None:
        rg.blink(blink, [10, 11, 64, 65])
    return rg


def rig_gr5(base, blink):
    """大乘女：浮在雲上，一拍一拍輕輕左右傾。金色花瓣從上面一片片飄下來、邊落邊翻面；中間開心地往上一挺。背後的光一明一暗。"""
    rg = Rig(base)
    bx = (44, 0, 132, 54)
    light = (lum(base) > 205).astype(np.float32)

    def P(f):
        return pose(dy=1.0 * math.sin(TAU * (f / 48.0 + 0.25)), sq=seq(f, 26, [1, -2, -1, 1]), ln=0 if 24 <= f < 32 else 0.8 * SW[(f // 3) % 8])
    heady, PP = floater(rg, OUT5G, P)
    tilt = lambda f: 2.0 * PP(f)['ln']
    leaves(rg, base, bx, (88, 40), lambda f: heady(f) + 0.6 * tilt(f), 45, 0.6)
    clouds(rg, [(0, 184, 50, 202), (122, 184, 167, 202)])
    rnd = random.Random(5)
    petals = [(rnd.uniform(8, 160), rnd.uniform(0, GH), rnd.uniform(0, 1), rnd.choice((3, 4, 5))) for _ in range(11)]

    def fall(img, f):
        glow(img, 88, 52, 66, .05 + .14 * (.5 + .5 * cyc(f, 24, -0.25)), PALE, only=rg.warp(light))
        for i, (x0, y0, ph, amp) in enumerate(petals):
            y = (y0 + 2 * f * GH / float(N)) % GH
            x = x0 + amp * math.sin(TAU * (f / 24.0 + ph))
            flip = (f + i * 3) % 8
            if flip < 3:
                dot(img, x, y, AMBER); dot(img, x + 1, y, GOLD); dot(img, x - 1, y + 1, AMBER, 0.8); dot(img, x, y + 1, GOLD)
            elif flip < 5:
                dot(img, x, y, GOLD); dot(img, x, y + 1, AMBER)
            else:
                dot(img, x, y, AMBER); dot(img, x - 1, y, GOLD); dot(img, x + 1, y + 1, AMBER, 0.8); dot(img, x, y + 1, GOLD)
    rg.front.append(fall)
    if blink is not None:
        rg.blink(blink, [14, 15, 70, 71])
    return rg


# ---------- 渡劫 ----------
def storm(rg, rocks, embers):
    for i, b in enumerate(rocks):
        W = rg.region('rock%d' % i, box(*b), 2)
        rg.soft.append(lambda f, W=W, i=i: [f_shift(W, 0, 2.0 * cyc(f, 24, i * 0.37))])

    def fx(img, f):
        glow(img, 84, 192, 34, .08 + .20 * (.5 + .5 * cyc(f, 12)), GOLD)
        for i, (x, y) in enumerate(embers):
            g = (f + i * 9) % N
            dot(img, x + 2 * math.sin(g / 4.0 + i), y - g * 1.1, GOLD, math.sin(math.pi * g / N))
    rg.front.append(fx)


EMBERS = [(30, 198), (56, 205), (118, 202), (144, 192), (92, 207), (70, 198)]


OUT6 = [(70, 2), (100, 2), (126, 20), (124, 56), (112, 62), (120, 78), (146, 80), (168, 96), (168, 150), (140, 158), (120, 165), (118, 186), (44, 186),
        (42, 165), (15, 160), (0, 140), (0, 55), (50, 60), (30, 52), (32, 22)]
OUT6G = [(70, 2), (98, 2), (122, 20), (122, 52), (112, 58), (120, 78), (146, 80), (168, 96), (168, 150), (140, 160), (120, 168), (118, 186), (48, 186),
         (44, 168), (15, 165), (0, 150), (0, 50), (46, 46), (38, 40), (40, 18)]


def rig_r6(base, blink):
    """渡劫男：喘著氣撐著。天暗下來、人越蹲越低，一道大雷沿著畫裡的閃電劈下來，整張閃白、震一下、人被壓到最扁；頂住之後一口氣挺回來。"""
    rg = Rig(base)
    bx = (34, 14, 124, 62)
    hit = 23
    main = [(142, 0), (137, 20), (131, 40), (126, 58), (121, 75), (118, 92)]
    side = [(122, 72), (134, 84), (130, 98), (142, 112), (138, 126)]

    def P(f):
        if f < 18 or f >= 36:
            return pose(sq=breathe(f, 6, 2))
        return pose(sq=seq(f, 18, [1, 1, 1, 2, 2, 3, 3, 2, 1, -1, -2, -2, -1, -1]))
    heady, _ = floater(rg, OUT6, P, legs=(44, 150, 118, 184))
    gust = kick(heady, 0.25)
    sway(rg, 'wisp_l', box(10, 50, 48, 76), 0, 1.8, 36, 12, 0.1, gain=gust)
    leaves(rg, base, bx, (86, 42), heady)
    storm(rg, [(8, 164, 26, 180), (152, 162, 167, 198)], EMBERS)

    def strike(img, f):
        g = f - hit
        if g in (0, 1, 2):
            bolt(img, main, 1.0)
            bolt(img, side, 0.9 if g != 1 else 0.5, wide=False)
            glow(img, 118, 96, 26, 0.55, WHITE)
        elif 3 <= g <= 8:
            bolt(img, main, 0.55 * (1 - (g - 3) / 6.0), wide=False)
    rg.front.append(strike)
    rg.post.append(dim({hit - 3: .10, hit - 2: .18, hit - 1: .24}))
    rg.post.append(flash({hit: .55, hit + 1: .16, hit + 2: .36, hit + 3: .10}))
    rg.post.append(shake({hit: 2, hit + 1: -2, hit + 2: 1}))
    if blink is not None:
        rg.blink(blink, [8, 9, 62, 63])
    return rg


def rig_gr6(base, blink):
    """渡劫女：細電弧一條條在身上竄、一閃就沒。左邊先落一道小雷，人一沉又彈回來；隔一陣子右邊那道大的再劈一次。長髮被風扯得一直甩。"""
    rg = Rig(base)
    bx = (40, 8, 124, 52)
    hits = (12, 34)
    main = [(130, 0), (128, 20), (124, 40), (121, 60), (118, 80), (116, 95)]
    left = [(36, 0), (30, 22), (40, 26), (28, 52), (38, 56), (26, 78)]

    def P(f):
        idle_ = breathe(f, 6, 2) if (f < 10 or 18 <= f < 31 or f >= 42) else 0
        return pose(sq=idle_ + seq(f, hits[0] - 1, [1, 2, 2, 1, -1]) + seq(f, hits[1] - 1, [1, 3, 3, 2, 1, -1, -1]))
    heady, _ = floater(rg, OUT6G, P, legs=(46, 153, 118, 184))
    gust = kick(heady, 0.25)
    sway(rg, 'hair_l', box(2, 48, 40, 94), 10, 2.2, 44, 12, 0.0, gain=gust)
    leaves(rg, base, bx, (86, 40), heady)
    storm(rg, [(8, 164, 26, 180), (152, 162, 167, 196)], EMBERS)
    rnd = random.Random(11)
    arcs = []
    for k in range(N // 4):
        ang, rad = rnd.uniform(0, TAU), rnd.uniform(24, 44)
        x, y = 88 + rad * math.cos(ang), 112 + rad * 1.2 * math.sin(ang)
        pts = [(x, y)]
        for _ in range(4):
            x += rnd.uniform(-7, 7)
            y += rnd.uniform(-8, 8)
            pts.append((x, y))
        arcs.append((k * 4, pts))

    def crackle(img, f):
        for start, pts in arcs:
            g = (f - start) % N
            if g < 3:
                n = len(pts) if g else 3
                for p0, p1 in zip(pts[:n], pts[1:n]):
                    line(img, (p0[0] + 1, p0[1]), (p1[0] + 1, p1[1]), GOLD, 0.7 if g < 2 else 0.35)
                    line(img, p0, p1, WHITE, 1.0 if g < 2 else 0.5)
                if g == 1:
                    plus(img, pts[-1][0], pts[-1][1], WHITE)
        for h, path in zip(hits, (left, main)):
            g = f - h
            if g in (0, 1, 2):
                bolt(img, path, 1.0 if g != 1 else 0.6, wide=(path is main))
            elif 3 <= g <= 6:
                bolt(img, path, 0.4 * (1 - (g - 3) / 4.0), wide=False)
    rg.front.append(crackle)
    rg.post.append(dim({hits[1] - 2: .12, hits[1] - 1: .2}))
    rg.post.append(flash({hits[0]: .30, hits[0] + 2: .16, hits[1]: .46, hits[1] + 1: .12, hits[1] + 2: .28}))
    rg.post.append(shake({hits[0]: 1, hits[1]: 2, hits[1] + 1: -2}))
    if blink is not None:
        rg.blink(blink, [22, 23, 76, 77])
    return rg


RIGS = {'r0': rig_r0, 'gr0': rig_gr0, 'r1': rig_r1, 'gr1': rig_gr1, 'r2': rig_r2, 'gr2': rig_gr2, 'r3': rig_r3, 'gr3': rig_gr3,
        'r4': rig_r4, 'gr4': rig_gr4, 'r5': rig_r5, 'gr5': rig_gr5, 'r6': rig_r6, 'gr6': rig_gr6}
# 動作條從第幾格開始看（連續 14 格）：招牌動作的預備到落定
STRIP = {'r0': 18, 'gr0': 21, 'r1': 15, 'gr1': 11, 'r2': 19, 'gr2': 31, 'r3': 19, 'gr3': 15,
         'r4': 20, 'gr4': 29, 'r5': 18, 'gr5': 23, 'r6': 18, 'gr6': 9}


def main():
    folder = sys.argv[1]
    dbg = sys.argv[2] if len(sys.argv) > 2 else None
    only = sys.argv[3].split(',') if len(sys.argv) > 3 else px.NAMES
    for name in only:
        base, pal = load(folder, name)
        blink, _ = load(folder, name, '_blink')
        pal_lab = px.rgb2lab(pal.astype(np.float32))
        rg = RIGS[name](base, blink)
        frames = rg.frames()
        sheet = np.zeros((GH * (N // COLS), GW * COLS), dtype=np.uint8)
        cells = []
        for i, fr in enumerate(frames):
            cells.append(px.nearest(px.rgb2lab(np.clip(fr, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW))
            r, c = divmod(i, COLS)
            sheet[r * GH:(r + 1) * GH, c * GW:(c + 1) * GW] = cells[-1]
        im = Image.fromarray(sheet, mode='P')
        im.putpalette(pal.reshape(-1).tolist())
        out = os.path.join(folder, '%s_anim%d.png' % (name, N))
        im.save(out, optimize=True)
        print(name, 'frames', N, os.path.getsize(out), 'bytes')
        if dbg:
            rg.debug(os.path.join(dbg, 'dbg_%s.png' % name))
            a = STRIP[name]
            st = Image.new('RGB', (14 * (GW + 2), GH), (30, 30, 30))
            for i in range(14):
                st.paste(Image.fromarray(pal[cells[(a + i) % N]]), (i * (GW + 2), 0))
            st.save(os.path.join(dbg, 'st_%s.png' % name))
            np.save(os.path.join(dbg, 'cells_%s.npy' % name), np.stack(cells))


if __name__ == '__main__':
    main()
