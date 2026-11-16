"""幫 14 張像素立繪各做一條待機動畫（橫向排開的長條圖，每條 48 格、一格 0.1 秒）。

每一張有自己的動作，平常只有呼吸、葉子、鬚和衣角在動，隔一陣子做一次招牌動作：
  煉氣男 掂水桶          煉氣女 左右搖擺、髮帶飄
  築基男 舉劍下劈        築基女 連點兩劍
  金丹男 拋接金丹        金丹女 金丹繞圈
  元嬰男 拄杖點地起光紋  元嬰女 元嬰呼吸發光、流蘇輕擺
  化神男 飄帶、流星      化神女 星光匯聚到掌心
  大乘男 佛光輪轉、光環  大乘女 金色花瓣飄落
  渡劫男 一道大雷劈下    渡劫女 電弧纏身、兩道小雷

另外產生只有眼睛那一小塊的眨眼圖，疊在動畫上，跟動作的節奏分開。
頭在眼睛那個高度最多只動一格，眨眼圖才對得上。

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


def load(folder, name):
    im = Image.open(os.path.join(folder, '%s_%dx%d.png' % (name, GW, GH)))
    pal = np.array(im.getpalette()[:px.NCOL * 3], dtype=np.uint8).reshape(-1, 3)
    return pal[np.asarray(im)].astype(np.float32), pal


# ---------- 每張都會用到的小動作 ----------
def disc(c, r):
    return np.hypot(XS - c[0], YS - c[1]) <= r


def ramp(origin, along, length):
    ux, uy = math.cos(math.radians(along)), math.sin(math.radians(along))
    return np.clip(((XS - origin[0]) * ux + (YS - origin[1]) * uy) / float(length), 0, 1)


def leaves(rg, base, bx, pivot, deg, length=45):
    """頭上的葉子和紅果繞著莖的根部晃。"""
    W = rg.region('leaves', grow(close(box(*bx) & leafy(base), 1), 2), 2)
    rg.soft.append(lambda f: [f_bend(W, pivot, deg(f), length)])
    return W


def sway(rg, name, mask, along, amp, wavelength, period, phase=0.0, r=3, anchor=None, gain=None):
    """一塊布、一束頭髮或一片雲的起伏。anchor=(x, y, 長度) 表示從那一點開始越遠擺越大。"""
    W = rg.region(name, mask, r)
    if anchor:
        W = W * ramp(anchor[:2], along, anchor[2])
    rg.soft.append(lambda f: [f_wave(W, along, amp * (gain(f) if gain else 1.0), wavelength, TAU * (f / float(period) + phase))])
    return W


def breathe(rg, mask, y0, y1, fn=None, r=4):
    """站著的角色：胸口以上吸氣時往上一格，腰到衣襬之間拉長一列。"""
    W = rg.region('body', mask, r)
    fn = fn or (lambda f: -breath(f))
    rg.soft.append(lambda f: [f_squash(W, y0, y1, fn(f))])
    return W


def floaty(rg, mask, amp=1.0, period=48, phase=0.0, r=6):
    """飄在空中的角色：身體連衣服慢慢起伏，背景的山和雲不動。"""
    W = rg.region('float', mask, r)
    rg.soft.append(lambda f: [f_shift(W, 0, amp * cyc(f, period, phase))])
    return W


def motes(rg, pts, rise=1.6, col=GOLD):
    """往上飄的光點，一輪剛好飄完一次，接得起來。"""
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
    """整張閃白。amount 是 {格: 強度}。"""
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


# ---------- 煉氣 ----------
BUCKET = [(106, 128), (126, 126), (144, 134), (145, 150), (142, 170), (138, 180), (112, 180), (107, 168), (105, 148)]


def woody(base):
    h, s, v = hsv(base)
    return (h > 12) & (h < 48) & (s > 0.34) & (lum(base) < 205)


def scene0(rg, base):
    """煉氣的場景：左邊的布旗飄、右邊的燈籠晃。"""
    sway(rg, 'banner', box(16, 84, 35, 122), 90, 1.3, 30, 24, anchor=(25, 84, 24))
    Wl = rg.region('lantern', box(135, 75, 154, 103), 2)
    rg.soft.append(lambda f: [f_bend(Wl, (144, 74), 3.0 * cyc(f, 48, 0.2), 26)])
    flick = [.2, .5, .35, .6, .25, .55, .3, .5, .2, .45, .6, .35]
    rg.front.append(lambda img, f: glow(img, 144, 88, 13, flick[(f // 2) % 12], PALE))


def bucket0(rg, base, body, arm_poly, shoulder, arm_mv, swing):
    arm = rg.part('arm', cut(base, arm_poly, seeds=[(123, 128)]), arm_mv, body)
    bk = close(cut(base, BUCKET, bg=~woody(base), seeds=[(125, 160)]) | (poly([(111, 144), (139, 144), (138, 151), (112, 151)])), 1)
    rg.parts.insert(len(rg.parts) - 1, Part('bucket', bk & ~arm.mask, lambda f: [rot((125, 135), swing(f))], arm))
    return arm


def rig_r0(base):
    """煉氣男：掂一下水桶。先蹲一格、把桶往上提，放下之後桶晃幾下才停。"""
    rg = Rig(base)
    leafm = close(box(28, 0, 138, 64) & leafy(base), 1)
    torso = cut(base, [(72, 42), (98, 42), (108, 58), (118, 75), (120, 90), (112, 98), (120, 104), (126, 112), (124, 124), (118, 128),
                       (116, 140), (118, 156), (100, 160), (88, 154), (78, 160), (56, 156), (52, 140), (56, 128), (48, 118), (50, 104),
                       (60, 98), (62, 90), (60, 75), (66, 56)], seeds=[(88, 75)])
    wisps = cut(base, [(36, 60), (64, 60), (64, 112), (40, 112)]) | cut(base, [(104, 58), (117, 60), (121, 74), (127, 84), (127, 94), (112, 94)])
    wisps &= ~leafy(base)

    def body_mv(f):
        idle = breath(f) if (f < 21 or f > 38) else 0
        dy = -idle + keys(f, [(23, 0), (26, 1), (27, 1), (29, -1), (31, -1), (35, 0)])
        return [lean((85, 160), keys(f, [(22, 0), (26, 0.6), (29, -0.3), (36, 0)]), 120), squash(104, 150, round(dy))]
    body = rg.part('body', torso | leafm | wisps, body_mv)
    lift = lambda f: round(keys(f, [(24, 0), (27, 1), (29, -3), (32, -2), (37, 0)]))
    swing = lambda f: 2.2 * cyc(f, 24) + ring(f, 30, 8, 12, 7, True)
    bucket0(rg, base, body, [(113, 114), (124, 112), (132, 128), (132, 140), (118, 140), (114, 126)], (115, 108),
            lambda f: [shift(0, lift(f))], swing)
    leaves(rg, base, (28, 0, 138, 64), (84, 42), lambda f: 2.0 * cyc(f, 24, 0.1) + ring(f, 29, 4, 10, 6))
    sway(rg, 'wisp_l', box(36, 62, 62, 112), 90, 1.4, 34, 24, 0.2, anchor=(60, 62, 30))
    sway(rg, 'wisp_r', box(111, 60, 127, 94), 90, 1.2, 30, 24, 0.5, r=2, anchor=(108, 60, 24))
    sway(rg, 'hem', box(54, 140, 118, 160), 90, 1.0, 30, 24, 0.3, anchor=(85, 136, 16))
    scene0(rg, base)

    def glint(img, f):
        if 29 <= f <= 40 and f % 2 == 0:
            dot(img, 119 + (f % 3) * 5, 147 + lift(f), WHITE)
            dot(img, 131 - (f % 4) * 3, 148 + lift(f), WHITE, 0.8)
    rg.front.append(glint)
    return rg


def rig_gr0(base):
    """煉氣女：提著水桶左右搖，像在哼歌。髮帶和長髮跟著飄，桶慢半拍往反方向晃。"""
    rg = Rig(base)
    leafm = close(box(28, 0, 138, 62) & leafy(base), 1)
    torso = cut(base, [(72, 40), (98, 40), (110, 54), (120, 70), (130, 92), (130, 112), (126, 120), (120, 124), (118, 140), (120, 158),
                       (108, 164), (92, 158), (78, 164), (58, 160), (52, 142), (42, 150), (34, 130), (38, 104), (34, 92), (36, 78),
                       (46, 66), (52, 54), (62, 48)], seeds=[(88, 75)])
    sw = lambda f: cyc(f, 24)
    body = rg.part('body', torso | leafm, lambda f: [lean((85, 162), 1.1 * sw(f), 120), squash(104, 152, -breath(f, 24, (2, 12)))])
    bucket0(rg, base, body, [(114, 114), (126, 114), (132, 128), (132, 140), (119, 140), (115, 126)], (116, 110),
            lambda f: [rot((116, 110), 2.0 * cyc(f, 24, -0.15))], lambda f: -5.0 * cyc(f, 24, -0.2))
    leaves(rg, base, (28, 0, 138, 62), (84, 42), lambda f: 3.0 * cyc(f, 24, -0.18))
    sway(rg, 'ribbon', box(38, 62, 60, 102), 90, 2.0, 30, 24, -0.1, anchor=(52, 62, 26))
    sway(rg, 'hair_l', box(38, 96, 68, 152), 90, 1.8, 40, 24, -0.2, anchor=(55, 92, 36))
    sway(rg, 'hair_r', box(113, 62, 130, 120), 90, 1.4, 36, 24, -0.25, r=2, anchor=(112, 60, 36))
    sway(rg, 'hem', box(52, 142, 122, 166), 90, 1.4, 32, 24, -0.3, anchor=(86, 138, 18))
    scene0(rg, base)
    return rg


# ---------- 築基 ----------
SWORD = [(146, 37), (154, 38), (156, 46), (138, 84), (137, 91), (127, 92), (124, 104), (112, 104), (111, 92), (118, 84), (119, 76), (142, 44)]


def swordsman(rg, base, torso, skirt, arm_poly, shoulder, sw, body_mv, hit_frames):
    leafm = close(box(25, 0, 138, 64) & leafy(base), 1)
    body = rg.part('body', torso | leafm, body_mv)
    rg.part('skirt', skirt, lambda f: [wave((85, 130), 90, 1.0 + sum(abs(ring(f, h, 1.4, 12, 6)) for h in hit_frames), 36, TAU * f / 24, 28)], body)
    arm = rg.part('arm', cut(base, arm_poly, seeds=[(110, 106)]), lambda f: [rot(shoulder, 0.45 * sw(f))], body)
    blade = cut(base, SWORD, seeds=[(140, 60)])
    rg.part('sword', grow(blade, 1) & (lum(base) < 250) & poly(SWORD) | blade, lambda f: [rot((118, 97), 0.55 * sw(f))], arm)
    return body


def smear(rg, spans, sparks):
    """劍劈下去那一兩格的殘影。spans 是 {格: (起始角, 結束角, 濃度)}，角度是劍相對原本位置轉了幾度。"""
    rest = math.degrees(math.atan2(41 - 97, 150 - 118))

    def fx(img, f):
        if f in spans:
            a0, a1, alpha = spans[f]
            d = a0
            while d <= a1:
                t = math.radians(rest + d)
                k = (d - a0) / float(a1 - a0)
                for r in range(34, 64):
                    dot(img, 116 + r * math.cos(t), 97 + r * math.sin(t), PALE if r % 2 else WHITE, alpha * k * (0.4 + 0.6 * (r - 34) / 30.0))
                d += 0.5
        if f in sparks:
            t = math.radians(rest + sparks[f])
            plus(img, 116 + 65 * math.cos(t), 97 + 65 * math.sin(t), GOLD)
    rg.front.append(fx)


def rig_r1(base):
    """築基男：慢慢把劍舉過頭、一下劈下去。手臂和袖子跟著劍轉，身體往前帶，葉子和衣襬晚一拍回彈。"""
    rg = Rig(base)
    sw = lambda f: keys(f, [(19, 0), (26, -32), (27, -34), (28, -6), (29, 16), (30, 20), (33, 13), (42, 0)])

    def body_mv(f):
        idle = breath(f) if (f < 19 or f > 43) else 0
        dy = -idle + keys(f, [(20, 0), (24, -1), (27, -1), (28, 1), (31, 1), (34, 0)])
        ln = keys(f, [(19, 0), (26, -0.6), (27, -0.7), (29, 0.8), (31, 0.7), (40, 0)])
        return [lean((85, 166), ln, 120), squash(100, 150, round(dy))]
    torso = cut(base, [(72, 43), (90, 42), (100, 55), (106, 68), (107, 82), (103, 92), (110, 93), (124, 98), (122, 106), (117, 112), (114, 128),
                       (118, 140), (128, 148), (126, 160), (118, 166), (100, 168), (88, 163), (78, 168), (58, 166), (40, 160), (38, 148),
                       (28, 142), (30, 130), (44, 126), (42, 116), (50, 110), (60, 104), (62, 96), (66, 90), (62, 78), (63, 62), (68, 50)], seeds=[(85, 70)])
    wisps = (cut(base, [(36, 60), (64, 60), (64, 95), (58, 112), (38, 112), (34, 90)]) | cut(base, [(104, 58), (120, 60), (120, 92), (108, 92), (106, 80)])) & ~leafy(base)
    skirt = cut(base, [(58, 130), (112, 130), (118, 140), (128, 148), (126, 160), (118, 166), (100, 168), (88, 163), (78, 168), (58, 166),
                       (40, 160), (38, 148), (48, 140)], seeds=[(85, 150)])
    swordsman(rg, base, torso | wisps, skirt, [(98, 93), (110, 90), (118, 92), (124, 98), (122, 106), (117, 112), (114, 128), (106, 128), (102, 112)],
              (100, 100), sw, body_mv, [29])
    leaves(rg, base, (25, 0, 138, 64), (82, 42), lambda f: 2.0 * cyc(f, 24, 0.1) + ring(f, 29, -5, 10, 6) + keys(f, [(19, 0), (25, 2.5), (28, 0)]))
    sway(rg, 'wisp_l', box(34, 60, 62, 112), 90, 1.4, 34, 24, 0.2, anchor=(62, 60, 30), gain=lambda f: 1 + abs(ring(f, 29, 1.2, 10, 6)))
    sway(rg, 'wisp_r', box(110, 60, 121, 92), 90, 1.2, 30, 24, 0.5, r=2, anchor=(106, 60, 22))
    smear(rg, {28: (-34, -6, 0.85), 29: (-6, 16, 0.55), 30: (10, 20, 0.25)}, {29: 18, 30: 18})
    return rg


def rig_gr1(base):
    """築基女：連點兩劍，一短一長。每點一下裙襬轉開、髮帶甩一下，再收回來。"""
    rg = Rig(base)
    sw = lambda f: keys(f, [(8, 0), (13, -15), (14, -16), (15, 8), (16, 11), (19, 3), (22, -19), (23, -20), (24, 12), (25, 16), (29, 9), (40, 0)])

    def body_mv(f):
        idle = breath(f) if (f < 8 or f > 40) else 0
        dy = -idle + keys(f, [(9, 0), (13, -1), (14, -1), (15, 1), (17, 0), (21, -1), (23, -1), (24, 1), (27, 1), (31, 0)])
        ln = keys(f, [(8, 0), (14, -0.4), (16, 0.5), (19, 0), (23, -0.6), (25, 0.8), (28, 0.6), (38, 0)])
        return [lean((85, 168), ln, 120), squash(102, 152, round(dy))]
    torso = cut(base, [(72, 40), (98, 40), (110, 56), (118, 72), (121, 92), (126, 100), (124, 110), (120, 126), (114, 128), (120, 140), (130, 150),
                       (128, 162), (118, 168), (100, 170), (88, 164), (76, 170), (56, 168), (44, 160), (42, 148), (30, 144), (32, 134),
                       (44, 128), (36, 118), (38, 104), (34, 96), (36, 84), (46, 72), (48, 58), (58, 48)], seeds=[(88, 75)])
    skirt = cut(base, [(56, 130), (114, 130), (120, 140), (130, 150), (128, 162), (118, 168), (100, 170), (88, 164), (76, 170), (56, 168),
                       (44, 160), (42, 148), (50, 138)], seeds=[(85, 150)])
    swordsman(rg, base, torso, skirt, [(98, 95), (112, 92), (120, 94), (127, 100), (126, 110), (122, 126), (108, 128), (102, 112)],
              (100, 102), sw, body_mv, [15, 24])
    kick = lambda f: 1 + abs(ring(f, 15, 1.0, 10, 5)) + abs(ring(f, 24, 1.4, 10, 6))
    leaves(rg, base, (25, 0, 138, 62), (84, 42), lambda f: 2.0 * cyc(f, 24, 0.1) + ring(f, 15, -3, 9, 5) + ring(f, 24, -5, 10, 6))
    sway(rg, 'ribbon', box(34, 64, 62, 100), 90, 1.6, 30, 24, 0.1, anchor=(52, 64, 26), gain=kick)
    sway(rg, 'hair_l', box(36, 98, 66, 134), 90, 1.5, 36, 24, 0.25, anchor=(55, 94, 30), gain=kick)
    sway(rg, 'hair_r', box(112, 60, 122, 102), 90, 1.2, 30, 24, 0.5, r=2, anchor=(108, 60, 26))
    smear(rg, {15: (-16, 8, 0.6), 24: (-20, 12, 0.85), 25: (8, 16, 0.4)}, {16: 11, 25: 16, 26: 16})
    return rg


# ---------- 金丹 ----------
def core_fx(rg, c, pos, sparks=3, radius=12, burst=None, trail=None):
    """金丹周圍的光：跟著金丹走的光暈、繞著它轉的光點、接住那一下的火花。pos(f) 回傳金丹這一格的位移。"""
    def fx(img, f):
        dx, dy = pos(f)
        x, y = c[0] + dx, c[1] + dy
        glow(img, x, y, 17, .12 + .22 * (.5 + .5 * cyc(f, 12)), PALE)
        for k in range(sparks):
            t = TAU * (f / 16.0 + k / float(sparks))
            px_, py_ = x + radius * math.cos(t), y + radius * 0.8 * math.sin(t)
            plus(img, px_, py_, GOLD) if k == 0 else dot(img, px_, py_, WHITE)
        if trail:
            for j in range(1, trail + 1):
                tx, ty = pos(f - j)
                if (tx, ty) != (dx, dy):
                    dot(img, c[0] + tx, c[1] + ty + (3 if ty < dy else 0), PALE, 0.7 - 0.2 * j)
        if burst and burst[0] <= f < burst[0] + 5:
            g = f - burst[0]
            for k in range(8):
                t = TAU * k / 8.0 + 0.3
                dot(img, c[0] + (7 + g * 3) * math.cos(t), c[1] + burst[1] + (7 + g * 3) * math.sin(t), GOLD if k % 2 else WHITE, 1 - g * 0.2)
    rg.front.append(fx)


def rig_r2(base):
    """金丹男：把金丹往上一拋、再接住。手先沉一下才出力，頭跟著抬起來看，接住時手往下一頓、迸出火花。"""
    rg = Rig(base)
    c = (135, 57)
    toss = {23: 1, 24: 1, 25: -5, 26: -10, 27: -14, 28: -16, 29: -16, 30: -14, 31: -10, 32: -5, 33: 0, 34: 1, 35: 1}
    pos = lambda f: (0, toss.get(f % N, -1 if breath(f, 24, (6, 16)) else 0))
    h, s, v = hsv(base)
    rg.part('core', flood(disc(c, 11) & (s > 0.42), c), lambda f: [shift(*pos(f))])
    breathe(rg, poly([(60, 40), (105, 40), (115, 70), (150, 85), (165, 110), (160, 150), (20, 150), (8, 125), (30, 100), (60, 80)]), 95, 150)
    Wh = rg.region('hand', poly([(118, 62), (150, 62), (152, 80), (140, 92), (120, 90)]), 3)
    hand = lambda f: keys(f, [(21, 0), (24, 1.4), (25, -2), (27, -1.4), (31, 0), (33, 0), (34, 1.6), (37, 0)])
    rg.soft.append(lambda f: [f_shift(Wh, 0, hand(f))])
    Whead = rg.region('head', poly([(58, 34), (112, 34), (118, 60), (112, 92), (66, 92), (56, 60)]), 3)
    rg.soft.append(lambda f: [f_bend(Whead, (88, 96), keys(f, [(24, 0), (27, 1.8), (31, 1.8), (36, 0)]), 40)])
    leaves(rg, base, (22, 0, 132, 58), (82, 38), lambda f: 2.0 * cyc(f, 24, 0.1) + keys(f, [(24, 0), (28, 3), (32, 3), (38, 0)]) + ring(f, 34, -3, 10, 5))
    sway(rg, 'sleeve_l', box(8, 104, 62, 166), 60, 1.4, 44, 24, 0.0)
    sway(rg, 'sleeve_r', box(118, 96, 166, 152), 110, 1.4, 44, 24, 0.3, gain=lambda f: 1 + abs(ring(f, 34, 1.0, 10, 6)))
    sway(rg, 'wisp_l', box(34, 58, 68, 96), 90, 1.3, 34, 24, 0.2, anchor=(68, 58, 30))
    sway(rg, 'hem', box(40, 136, 140, 162), 90, 1.0, 40, 24, 0.5)
    core_fx(rg, c, pos, burst=(33, 0), trail=3)
    return rg


def rig_gr2(base):
    """金丹女：金丹在掌心上方慢慢繞圈，後面拖著一串光點；繞到第二圈尾巴，往外盪出一圈光環。長髮和髮帶一直在飄。"""
    rg = Rig(base)
    c = (136, 60)
    pos = lambda f: (int(round(4.5 * math.cos(TAU * f / 24.0))), int(round(3.0 * math.sin(TAU * f / 24.0) - 2)))
    h, s, v = hsv(base)
    rg.part('core', flood(disc(c, 11) & (s > 0.42), c), lambda f: [shift(*pos(f))])
    breathe(rg, poly([(56, 40), (108, 40), (118, 70), (152, 85), (166, 110), (160, 150), (20, 150), (8, 125), (30, 100), (56, 80)]), 95, 150)
    Wh = rg.region('hand', poly([(124, 66), (152, 66), (152, 84), (140, 94), (124, 90)]), 3)
    rg.soft.append(lambda f: [f_shift(Wh, 0, 1.0 * cyc(f, 24, 0.3))])
    leaves(rg, base, (22, 0, 132, 56), (82, 38), lambda f: 2.4 * cyc(f, 24, 0.1))
    sway(rg, 'ribbon', box(44, 56, 68, 96), 90, 1.8, 30, 24, 0.0, anchor=(58, 56, 28))
    sway(rg, 'hair_l', box(24, 84, 70, 152), 70, 1.8, 46, 24, 0.2)
    sway(rg, 'hair_r', box(114, 60, 126, 100), 90, 1.2, 30, 24, 0.5, r=2, anchor=(110, 58, 26))
    sway(rg, 'sleeve_l', box(8, 104, 60, 150), 60, 1.3, 44, 24, 0.1)
    sway(rg, 'sleeve_r', box(120, 96, 166, 146), 110, 1.3, 44, 24, 0.4)
    sway(rg, 'hem', box(40, 136, 140, 164), 90, 1.2, 40, 24, 0.6)
    core_fx(rg, c, pos, sparks=2, radius=13, trail=5)

    def pulse(img, f):
        g = f - 36
        if 0 <= g < 10:
            r = 9 + g * 2.2
            for k in range(0, 360, 12):
                t = math.radians(k + g * 5)
                dot(img, c[0] + r * math.cos(t), c[1] - 2 + r * math.sin(t), PALE if (k // 12) % 2 else GOLD, 0.9 - g * 0.09)
    rg.front.append(pulse)
    return rg


# ---------- 元嬰 ----------
def clouds(rg, boxes, amp=1.2):
    for i, b in enumerate(boxes):
        sway(rg, 'cloud%d' % i, box(*b), 0, amp, 56, 48, i * 0.3, r=4)


def infant(rg, c, r=15):
    rg.front.append(lambda img, f: glow(img, c[0], c[1], r, .12 + .30 * (.5 + .5 * cyc(f, 24, -0.25)), PALE))


def rig_r3(base):
    """元嬰男：把手杖提起來、往地上一點，腳邊盪開兩圈光紋。杖頭的流蘇被震得甩起來，鬍鬚和袍角慢慢落定。"""
    rg = Rig(base)
    wood = (lum(base) < 180) & (base[..., 0] - base[..., 2] > 50)
    staff = close(poly([(114, 40), (160, 40), (160, 86), (146, 102), (144, 190), (126, 192), (124, 104), (118, 98), (114, 70)]) & wood, 1)
    staff = flood(staff, (134, 150), (140, 60)) | cut(base, [(128, 98), (144, 98), (144, 112), (128, 112)])
    lift = lambda f: round(keys(f, [(20, 0), (26, -3), (27, -3), (28, 0)]))
    jolt = {28: 1, 29: -1}
    rg.part('staff', staff, lambda f: [shift(jolt.get(f, 0), lift(f))])
    breathe(rg, poly([(60, 55), (112, 55), (120, 90), (130, 150), (125, 166), (40, 166), (20, 140), (30, 100), (55, 85)]), 100, 162,
            lambda f: -breath(f) if (f < 20 or f > 34) else keys(f, [(20, 0), (25, -1), (27, -1), (28, 1), (31, 1), (34, 0)]))
    Wt = rg.region('tassel', box(121, 58, 139, 100), 2)
    rg.soft.append(lambda f: [f_bend(Wt, (131, 58), 2.0 * cyc(f, 24) + ring(f, 28, 9, 10, 7, True) + keys(f, [(20, 0), (26, -3), (28, 0)]), 40),
                              f_shift(Wt, 0, lift(f))])
    sway(rg, 'beard', box(86, 86, 104, 114), 90, 1.1, 24, 24, 0.2, anchor=(95, 84, 22), gain=lambda f: 1 + abs(ring(f, 28, 1.0, 10, 6)))
    Wi = rg.region('infant', box(72, 22, 102, 54), 3)
    rg.soft.append(lambda f: [f_shift(Wi, 0, -1.0 * breath(f, 24, (14, 24)))])
    Wl = rg.region('hand_l', box(30, 86, 54, 104), 3)
    rg.soft.append(lambda f: [f_shift(Wl, 0, 1.0 * cyc(f, 48, 0.1))])
    leaves(rg, base, (35, 0, 136, 52), (88, 22), lambda f: 1.6 * cyc(f, 24, 0.1) + ring(f, 28, 2.5, 10, 6, True), 50)
    sway(rg, 'hem_l', box(22, 118, 70, 166), 70, 1.2, 46, 24, 0.1, gain=lambda f: 1 + abs(ring(f, 28, 0.8, 12, 6)))
    sway(rg, 'hem_r', box(96, 120, 126, 166), 100, 1.0, 40, 24, 0.4)
    clouds(rg, [(0, 166, 52, 209), (146, 166, 167, 209)])
    infant(rg, (86, 38))

    def ripple(img, f):
        for delay in (0, 4):
            g = f - 28 - delay
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
        if f in (28, 29):
            plus(img, 133, 187, GOLD)
    rg.front.append(ripple)
    return rg


def rig_gr3(base):
    """元嬰女：頭頂的元嬰跟著呼吸一亮一暗，兩隻手各升起一顆光點、繞上去匯到元嬰身上。流蘇和髮飾輕輕擺，偶爾被風帶一下。"""
    rg = Rig(base)
    floaty(rg, poly([(50, 16), (120, 16), (126, 90), (150, 150), (130, 196), (50, 196), (10, 150), (30, 90)]), 1.0, 48, 0.0)
    Wt = rg.region('tassel', box(120, 56, 140, 100), 2)
    gust = lambda f: ring(f, 30, 5, 12, 7, True)
    rg.soft.append(lambda f: [f_bend(Wt, (131, 58), 3.0 * cyc(f, 24) + gust(f), 40)])
    Wi = rg.region('infant', box(72, 18, 102, 46), 3)
    rg.soft.append(lambda f: [f_shift(Wi, 0, -1.0 * breath(f, 24, (4, 14)))])
    sway(rg, 'hairpin', box(40, 46, 66, 98), 90, 1.4, 30, 24, 0.0, r=2, anchor=(58, 46, 30), gain=lambda f: 1 + abs(gust(f)) / 4)
    sway(rg, 'hair_r', box(112, 62, 124, 104), 90, 1.2, 30, 24, 0.4, r=2, anchor=(108, 60, 26))
    leaves(rg, base, (32, 0, 136, 54), (86, 22), lambda f: 1.6 * cyc(f, 24, 0.1) + 0.4 * gust(f), 50)
    sway(rg, 'hem_l', box(14, 110, 70, 168), 70, 1.4, 46, 24, 0.1)
    sway(rg, 'hem_r', box(96, 120, 126, 168), 100, 1.1, 40, 24, 0.4)
    sway(rg, 'ribbon_r', box(134, 116, 166, 168), 60, 1.4, 40, 24, 0.6)
    clouds(rg, [(0, 172, 56, 209), (146, 172, 167, 209)])
    infant(rg, (86, 34), 16)

    def gather(img, f):
        for side, (sx, sy) in enumerate(((40, 90), (136, 100))):
            for rep in (0, 24):
                g = (f - rep - side * 6) % N
                if g >= 20:
                    continue
                t = ease(g / 19.0)
                bx = sx + (86 - sx) * t + (1 - 2 * side) * 18 * math.sin(math.pi * t)
                by = sy + (34 - sy) * t - 10 * math.sin(math.pi * t)
                plus(img, bx, by, GOLD, 0.95)
                for j in (1, 2, 3):
                    tt = ease(max(0, g - j) / 19.0)
                    dot(img, sx + (86 - sx) * tt + (1 - 2 * side) * 18 * math.sin(math.pi * tt), sy + (34 - sy) * tt - 10 * math.sin(math.pi * tt), PALE, 0.7 - 0.18 * j)
        for rep in (20, 44):
            g = (f - rep) % N
            if g < 6:
                r = 6 + g * 2.5
                for k in range(0, 360, 20):
                    t = math.radians(k + g * 8)
                    dot(img, 86 + r * math.cos(t), 34 + r * 0.8 * math.sin(t), PALE, 0.9 - g * 0.15)
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
    return sky


FLOAT4 = [(25, 30), (145, 30), (165, 60), (165, 150), (140, 160), (110, 185), (60, 185), (30, 160), (5, 140), (5, 60)]


def rig_r4(base):
    """化神男：整個人浮在夜空裡慢慢起伏，兩條飄帶一前一後地盪，垂著的腳跟著晃。一顆流星由慢到快劃過去，星星輪流閃。"""
    rg = Rig(base)
    floaty(rg, poly(FLOAT4), 1.0, 48)
    sway(rg, 'ribbon_ul', box(6, 48, 62, 84), 0, 1.8, 46, 24, 0.0)
    sway(rg, 'ribbon_ur', box(112, 54, 166, 86), 0, 1.8, 46, 24, 0.35)
    sway(rg, 'ribbon_l', box(4, 96, 44, 146), 90, 1.8, 44, 24, 0.15)
    sway(rg, 'ribbon_r', box(124, 96, 166, 152), 90, 1.8, 44, 24, 0.5)
    sway(rg, 'sleeve_l', box(40, 86, 72, 132), 90, 1.1, 36, 24, 0.3)
    sway(rg, 'sleeve_r', box(104, 86, 136, 132), 90, 1.1, 36, 24, 0.65)
    sway(rg, 'wisp_l', box(38, 52, 70, 98), 90, 1.3, 34, 24, 0.2, anchor=(70, 52, 30))
    Wg = rg.region('legs', box(62, 134, 114, 184), 3)
    rg.soft.append(lambda f: [f_bend(Wg, (88, 134), 2.6 * cyc(f, 48, 0.2), 46)])
    leaves(rg, base, (35, 0, 132, 50), (86, 30), lambda f: 2.0 * cyc(f, 24, 0.1))
    night(rg, base, [(26, 38), (48, 24), (120, 22), (142, 36), (152, 62), (20, 70), (114, 46), (60, 44), (136, 20), (30, 56)],
          [(6, 162, 22, -5.0, 3.4, 9), (31, 8, 40, 4.2, 2.6, 7)])
    return rg


def rig_gr4(base):
    """化神女：四周的星光一顆顆被吸過來，繞個彎落進兩邊掌心，掌心跟著亮。長髮和飄帶往兩邊散開，人慢慢起伏。"""
    rg = Rig(base)
    floaty(rg, poly(FLOAT4), 1.0, 48, 0.25)
    sway(rg, 'ribbon_ul', box(6, 50, 60, 84), 0, 1.6, 46, 24, 0.1)
    sway(rg, 'ribbon_ur', box(116, 54, 166, 86), 0, 1.6, 46, 24, 0.45)
    sway(rg, 'hair_l', box(18, 88, 72, 166), 80, 2.0, 50, 24, 0.0)
    sway(rg, 'hair_r', box(108, 96, 152, 156), 100, 1.8, 48, 24, 0.3)
    sway(rg, 'ribbon_r', box(132, 96, 166, 156), 90, 1.6, 44, 24, 0.6)
    Wg = rg.region('legs', box(68, 136, 114, 184), 3)
    rg.soft.append(lambda f: [f_bend(Wg, (90, 136), 2.2 * cyc(f, 48, 0.6), 44)])
    leaves(rg, base, (35, 0, 130, 48), (86, 30), lambda f: 2.0 * cyc(f, 24, 0.3))
    sky = night(rg, base, [(26, 40), (50, 26), (122, 24), (150, 60), (20, 72), (60, 44), (30, 58)], [])
    palms = ((50, 82), (139, 80))
    srcs = [(14, 36), (150, 30), (36, 14), (128, 14), (8, 70), (160, 64), (60, 30), (112, 36)]

    def gather(img, f):
        for i, (sx, sy) in enumerate(srcs):
            px_, py_ = palms[i % 2]
            g = (f + i * 6) % N
            if g >= 18:
                continue
            for j in range(4):
                t = max(0.0, (g - j) / 17.0) ** 1.8
                bend_ = (1 if i % 2 else -1) * 12 * math.sin(math.pi * t)
                x, y = sx + (px_ - sx) * t + bend_ * 0.4, sy + (py_ - sy) * t - abs(bend_)
                if j == 0:
                    plus(img, x, y, WHITE, 0.95)
                else:
                    dot(img, x, y, PALE, 0.75 - 0.2 * j)
        for k, (x, y) in enumerate(palms):
            hit = max(0.0, max(1 - ((f + i * 6 - 17) % N) / 5.0 for i in range(len(srcs)) if i % 2 == k))
            glow(img, x, y - 3, 10, .14 + .34 * hit, PALE)
            if hit > 0.6:
                plus(img, x, y - 4, GOLD)
    rg.front.append(gather)
    return rg


# ---------- 大乘 ----------
FLOAT5 = [(30, 20), (145, 20), (165, 60), (165, 140), (140, 170), (110, 192), (60, 192), (30, 170), (5, 140), (5, 60)]


def rig_r5(base):
    """大乘男：背後的佛光慢慢轉，隔一陣子從光輪盪出一圈金環，兩手跟著往上托一下、皇冠上的寶石閃一下。金色光點一直往上升。"""
    rg = Rig(base)
    light = (lum(base) > 205).astype(np.float32)
    c = (88, 52)
    floaty(rg, poly(FLOAT5), 1.0, 48)
    sway(rg, 'ribbon_l', box(4, 52, 50, 152), 90, 1.8, 50, 24, 0.0)
    sway(rg, 'ribbon_r', box(124, 50, 166, 150), 90, 1.8, 50, 24, 0.4)
    sway(rg, 'sleeve_l', box(32, 96, 70, 150), 80, 1.1, 40, 24, 0.2)
    sway(rg, 'sleeve_r', box(108, 96, 148, 150), 100, 1.1, 40, 24, 0.6)
    Wg = rg.region('legs', box(62, 150, 114, 192), 3)
    rg.soft.append(lambda f: [f_bend(Wg, (88, 150), 1.6 * cyc(f, 48, 0.3), 40)])
    hands = rg.region('hands', box(30, 82, 52, 100) | box(138, 82, 162, 100), 3)
    rg.soft.append(lambda f: [f_shift(hands, 0, keys(f, [(16, 0), (20, 1), (23, -1.6), (30, -1), (38, 0)]))])
    leaves(rg, base, (40, 0, 138, 56), (88, 38), lambda f: 1.8 * cyc(f, 24, 0.1) + ring(f, 23, 2, 10, 6, True))
    clouds(rg, [(0, 168, 58, 198), (116, 168, 167, 198)])

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
        g = f - 22
        if 0 <= g < 12:
            r = 56 + g * 2.6
            for k in range(0, 360, 2):
                t = math.radians(k)
                dot(tmp, c[0] + r * math.cos(t), c[1] + r * math.sin(t), GOLD, 0.9 * (1 - g / 12.0))
                dot(tmp, c[0] + (r - 1) * math.cos(t), c[1] + (r - 1) * math.sin(t), WHITE, 0.6 * (1 - g / 12.0))
        img[:] = img * (1 - light[..., None]) + tmp * light[..., None]
        glow(img, c[0], c[1], 74, .04 + .10 * (.5 + .5 * cyc(f, 24)), PALE, only=light)
        if f in (23, 24, 25, 26):
            plus(img, 87, 36, WHITE, 1.0 if f < 26 else 0.5)
    rg.front.append(halo)
    motes(rg, [(18, 176), (40, 150), (62, 190), (110, 186), (132, 150), (152, 178)])
    return rg


def rig_gr5(base):
    """大乘女：金色的花瓣從上面一片片飄下來，邊落邊翻面。背後的光跟著呼吸一明一暗，長髮和飄帶往兩邊盪。"""
    rg = Rig(base)
    light = (lum(base) > 205).astype(np.float32)
    floaty(rg, poly(FLOAT5), 1.0, 48, 0.25)
    sway(rg, 'hair_l', box(8, 62, 70, 152), 80, 2.0, 52, 24, 0.0)
    sway(rg, 'hair_r', box(116, 62, 150, 150), 100, 1.8, 50, 24, 0.35)
    sway(rg, 'ribbon_ur', box(120, 50, 166, 100), 0, 1.8, 46, 24, 0.2)
    sway(rg, 'ribbon_ll', box(4, 96, 40, 152), 90, 1.6, 44, 24, 0.5)
    sway(rg, 'hem', box(34, 128, 140, 166), 90, 1.2, 44, 24, 0.7)
    Wg = rg.region('legs', box(62, 150, 114, 192), 3)
    rg.soft.append(lambda f: [f_bend(Wg, (88, 150), 1.6 * cyc(f, 48, 0.7), 40)])
    leaves(rg, base, (44, 0, 132, 54), (88, 40), lambda f: 1.8 * cyc(f, 24, 0.3))
    clouds(rg, [(0, 170, 58, 198), (116, 170, 167, 198)])
    rnd = random.Random(5)
    petals = [(rnd.uniform(8, 160), rnd.uniform(0, GH), rnd.uniform(0, 1), rnd.choice((3, 4, 5))) for _ in range(11)]

    def fall(img, f):
        glow(img, 88, 52, 66, .05 + .14 * (.5 + .5 * cyc(f, 24, -0.25)), PALE, only=light)
        for i, (x0, y0, ph, amp) in enumerate(petals):
            y = (y0 + f * GH / float(N)) % GH
            x = x0 + amp * math.sin(TAU * (f / 24.0 + ph))
            flip = (f + i * 3) % 8
            if flip < 3:
                dot(img, x, y, GOLD); dot(img, x + 1, y, PALE); dot(img, x - 1, y + 1, GOLD, 0.8)
            elif flip < 5:
                dot(img, x, y, PALE); dot(img, x, y + 1, GOLD)
            else:
                dot(img, x, y, GOLD); dot(img, x - 1, y, PALE); dot(img, x + 1, y + 1, GOLD, 0.8)
    rg.front.append(fall)
    return rg


# ---------- 渡劫 ----------
def storm(rg, base, rocks, embers):
    for i, b in enumerate(rocks):
        W = rg.region('rock%d' % i, box(*b), 2)
        rg.soft.append(lambda f, W=W, i=i: [f_shift(W, 0, 1.6 * cyc(f, 24, i * 0.37))])

    def fx(img, f):
        glow(img, 84, 192, 34, .08 + .20 * (.5 + .5 * cyc(f, 12)), GOLD)
        for i, (x, y) in enumerate(embers):
            g = (f + i * 9) % N
            dot(img, x + 2 * math.sin(g / 4.0 + i), y - g * 1.1, GOLD, math.sin(math.pi * g / N))
    rg.front.append(fx)


def rig_r6(base):
    """渡劫男：天先暗兩格，一道大雷沿著畫裡那道閃電劈下來，整張閃白、震一下。人往下一沉扛住，破掉的衣角被吹得亂甩，再慢慢站穩。"""
    rg = Rig(base)
    hit = 23
    main = [(142, 0), (137, 20), (131, 40), (126, 58), (121, 75), (118, 92)]
    side = [(122, 72), (134, 84), (130, 98), (142, 112), (138, 126)]
    gust = lambda f: 1 + abs(ring(f, hit, 1.2, 10, 8))
    breathe(rg, poly([(50, 45), (115, 45), (125, 90), (135, 140), (120, 172), (45, 172), (30, 140), (40, 90)]), 100, 172,
            lambda f: keys(f, [(20, 0), (22, -1), (23, 1.4), (28, 1), (34, 0)]) if 20 <= f <= 34 else -breath(f, 24, (2, 10)))
    sway(rg, 'cloth_l', box(4, 76, 70, 150), 0, 2.0, 40, 12, 0.0, gain=gust)
    sway(rg, 'cloth_r', box(108, 96, 166, 150), 0, 2.0, 40, 12, 0.4, gain=gust)
    sway(rg, 'hem', box(40, 130, 130, 166), 90, 1.4, 40, 12, 0.2, gain=gust)
    sway(rg, 'wisp_l', box(10, 52, 66, 82), 0, 1.6, 36, 12, 0.1, gain=gust)
    leaves(rg, base, (34, 14, 124, 62), (86, 42), lambda f: 2.4 * cyc(f, 12, 0.1) + ring(f, hit, -6, 9, 7))
    storm(rg, base, [(14, 152, 31, 175), (150, 156, 167, 198), (16, 132, 28, 146)], [(30, 198), (56, 205), (118, 202), (144, 192), (92, 207), (70, 198)])

    def strike(img, f):
        g = f - hit
        if g in (0, 1, 2):
            bolt(img, main, 1.0)
            bolt(img, side, 0.9 if g != 1 else 0.5, wide=False)
            glow(img, 118, 96, 26, 0.55, WHITE)
        elif 3 <= g <= 8:
            bolt(img, main, 0.55 * (1 - (g - 3) / 6.0), wide=False)
        if f in (40, 41):
            bolt(img, main[:4], 0.45, wide=False)
    rg.front.append(strike)
    rg.post.append(dim({hit - 3: .10, hit - 2: .18, hit - 1: .24}))
    rg.post.append(flash({hit: .55, hit + 1: .16, hit + 2: .36, hit + 3: .10, 40: .12}))
    rg.post.append(shake({hit: 1, hit + 1: -1, hit + 2: 1}))
    return rg


def rig_gr6(base):
    """渡劫女：細小的電弧一條條在身上竄、一閃就沒。左邊先落一道小雷，隔一陣子右邊再一道。長髮被風扯得一直甩。"""
    rg = Rig(base)
    hits = (12, 34)
    main = [(130, 0), (128, 20), (124, 40), (121, 60), (118, 80), (116, 95)]
    left = [(36, 0), (30, 22), (40, 26), (28, 52), (38, 56), (26, 78)]
    gust = lambda f: 1 + abs(ring(f, hits[0], 0.8, 10, 6)) + abs(ring(f, hits[1], 1.0, 10, 7))

    def body_dy(f):
        for h in hits:
            if h <= f <= h + 6:
                return keys(f, [(h, 1.2), (h + 3, 1), (h + 6, 0)])
        return -breath(f, 24, (20, 24))
    breathe(rg, poly([(50, 40), (115, 40), (125, 90), (135, 140), (120, 174), (45, 174), (30, 140), (40, 90)]), 100, 174, body_dy)
    sway(rg, 'hair_l', box(4, 52, 72, 150), 10, 2.2, 44, 12, 0.0, gain=gust)
    sway(rg, 'cloth_r', box(110, 98, 166, 150), 0, 1.8, 40, 12, 0.4, gain=gust)
    sway(rg, 'hem', box(30, 130, 136, 168), 90, 1.4, 40, 12, 0.2, gain=gust)
    leaves(rg, base, (40, 8, 124, 52), (86, 40), lambda f: 2.4 * cyc(f, 12, 0.1) + ring(f, hits[0], -4, 9, 6) + ring(f, hits[1], -5, 9, 7))
    storm(rg, base, [(12, 140, 30, 176), (150, 140, 167, 192)], [(30, 198), (56, 205), (118, 202), (144, 192), (92, 207), (70, 198)])
    rnd = random.Random(11)
    arcs = []
    for k in range(12):
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
    rg.post.append(shake({hits[1]: 1, hits[1] + 1: -1}))
    return rg


RIGS = {'r0': rig_r0, 'gr0': rig_gr0, 'r1': rig_r1, 'gr1': rig_gr1, 'r2': rig_r2, 'gr2': rig_gr2, 'r3': rig_r3, 'gr3': rig_gr3,
        'r4': rig_r4, 'gr4': rig_gr4, 'r5': rig_r5, 'gr5': rig_gr5, 'r6': rig_r6, 'gr6': rig_gr6}
# 檢查總表要看哪幾格：平常的一格，加上招牌動作前後
CHECK = {'r0': [0, 26, 29, 31, 34, 40], 'gr0': [0, 6, 12, 18, 30, 42], 'r1': [0, 26, 28, 29, 33, 40], 'gr1': [0, 14, 15, 23, 24, 30],
         'r2': [0, 24, 26, 28, 33, 35], 'gr2': [0, 6, 12, 18, 38, 42], 'r3': [0, 26, 28, 30, 34, 40], 'gr3': [0, 8, 16, 22, 32, 44],
         'r4': [0, 8, 12, 24, 34, 40], 'gr4': [0, 8, 16, 24, 32, 40], 'r5': [0, 12, 23, 26, 30, 40], 'gr5': [0, 8, 16, 24, 32, 40],
         'r6': [0, 21, 23, 24, 25, 30], 'gr6': [0, 12, 13, 20, 34, 36]}


def main():
    folder = sys.argv[1]
    dbg = sys.argv[2] if len(sys.argv) > 2 else None
    only = sys.argv[3].split(',') if len(sys.argv) > 3 else px.NAMES
    for name in only:
        base, pal = load(folder, name)
        pal_lab = px.rgb2lab(pal.astype(np.float32))
        rg = RIGS[name](base)
        frames = rg.frames()
        strip = np.zeros((GH, GW * N), dtype=np.uint8)
        for i, fr in enumerate(frames):
            strip[:, i * GW:(i + 1) * GW] = px.nearest(px.rgb2lab(np.clip(fr, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)
        im = Image.fromarray(strip, mode='P')
        im.putpalette(pal.reshape(-1).tolist())
        out = os.path.join(folder, '%s_anim%d.png' % (name, N))
        im.save(out, optimize=True)
        print(name, 'frames', N, os.path.getsize(out), 'bytes')
        blink = os.path.join(folder, '%s_%dx%d_blink.png' % (name, GW, GH))
        if os.path.exists(blink):
            b = np.asarray(Image.open(blink).convert('RGB')).astype(np.int32)
            ys, xs = np.where(np.abs(b - base.astype(np.int32)).sum(-1) > 0)
            alpha = np.zeros((GH, GW), dtype=np.uint8)
            alpha[max(0, ys.min() - 2):ys.max() + 3, max(0, xs.min() - 2):xs.max() + 3] = 255
            Image.fromarray(np.dstack([b.astype(np.uint8), alpha]), mode='RGBA').save(os.path.join(folder, '%s_eyes.png' % name), optimize=True)
        if dbg:
            rg.debug(os.path.join(dbg, 'dbg_%s.png' % name))
            rgb = im.convert('RGB')
            picks = CHECK[name]
            S = 2
            sheet = Image.new('RGB', (len(picks) * (GW * S + 4), GH * S), (30, 30, 30))
            for i, f in enumerate(picks):
                sheet.paste(rgb.crop((f * GW, 0, (f + 1) * GW, GH)).resize((GW * S, GH * S), Image.NEAREST), (i * (GW * S + 4), 0))
            sheet.save(os.path.join(dbg, 'sh_%s.png' % name))
            rgb.crop((0, 0, GW, GH)).save(os.path.join(dbg, 'f0_%s.png' % name))


if __name__ == '__main__':
    main()
