"""幫 14 張像素立繪各做一條待機動畫（12x8 的格子圖，共 96 格、一格 0.1 秒，一輪 9.6 秒）。

分三層疊，角色動的時候背景一格都不動：
  1. 背景層：把角色佔的那一塊補起來的底圖。完全不動。背後的光（佛光、星星）畫在這一層上面、角色後面。
  2. 角色層：照 matte.py 切出來的遮罩（統一色盤/{代號}_168x210_mask.png）把角色整個人蓋上去。
     頭、手、衣服是一整塊，只做整數格的平移，一格都不變形；腿墊在下面，蹲下站高只有腿在伸縮，腳不動。
     道具（水桶、劍、金丹、手杖）和頭上的葉子是掛在身體上的零件，各自轉動或位移。
  3. 特效層：火花、光環、閃電、花瓣，畫在最上面。

動作照 E:\\像素broll\\pixel-broll-kit 的 motion.js：角色有清楚的姿勢、一拍一拍地演；大動作前先往反方向小動，
葉子和水桶被身體帶著、晚一拍盪幾下。招牌動作排在前 48 格，一輪做一次。
待機時身體只有慢慢呼吸：整個人升一格、停 16 格、再回來停 16 格（多米在比較畫板上選的「乙」）。
「縮一下再挺起來」「一拍彈一下」「喘氣」「浮上浮下」這些他說是「上下跳抖一下」，不要。其餘靠眨眼、葉子被風輕輕帶、道具自己的小動作和特效。
招牌動作裡身體要動的（提桶、下劈、拄杖、扛雷），用關鍵格慢慢帶過去，不做一格彈起來的那種跳。
播放速度是一格 0.15 秒（畫板和 app 決定，圖本身不管）。

不做的事（都被多米退過）：
  - 不壓扁、不拉長衣服（花紋會被擠得很怪）。
  - 不做任何「推一塊區域」的柔性變形（根鬚、頭髮、布料、雲的起伏）：看起來像火旁邊的空氣在扭。
  - 不讓背景跟著角色動。
  - 待機不做「縮一下、往上一挺」「一拍彈一下」「喘氣」這類上下跳。

每張的招牌動作：
  煉氣男 掂水桶          煉氣女 左右搖、踮兩下
  築基男 舉劍下劈        築基女 連點兩劍
  金丹男 拋接金丹        金丹女 金丹繞圈、盪出光環
  元嬰男 拄杖點地起光紋  元嬰女 光點匯進元嬰
  化神男 吐納、流星      化神女 星光匯聚到掌心
  大乘男 佛光盪出金環    大乘女 金色花瓣飄落
  渡劫男 扛一道大雷      渡劫女 電弧纏身、兩道小雷

用法：python animate.py <統一色盤資料夾> [檢查圖的資料夾] [只做哪幾張，逗號分隔]
比較用：環境變數 IDLE=still（身體不動）或 IDLE=sway（慢慢左右晃）可以出別種待機方式，
        這時成品檔名會多一段（{代號}_anim96_still.png），並存到環境變數 OUTDIR 指定的資料夾。
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
DEFAULT_STYLE = 'breath'                 # 多米 2026-11-16 在比較畫板上選的：乙 慢慢呼吸
STYLE = os.environ.get('IDLE', DEFAULT_STYLE)  # 待機時身體怎麼動：still 不動、breath 慢慢呼吸、sway 慢慢左右晃


def idle_pose(f):
    if STYLE == 'breath':
        return pose(sq=-1 / 3.0 if (f % 32) < 16 else 0)          # 升一格、停、回來
    if STYLE == 'sway':
        return pose(ln=[0, 0.6, 0, -0.6][(f // 12) % 4])          # 往右一格、回中、往左一格
    return pose()


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


def rooty(base):
    """人蔘皮的黃。"""
    h, s, v = hsv(base)
    return (h > 22) & (h < 50) & (s > 0.42) & (v > 0.55)


def leafgreen(base, bx, pivot):
    """頭上的葉子（只有綠色的部分，紅果留在頭上）：框裡的綠，而且連著葉柄。"""
    h, s, v = hsv(base)
    g = close(box(*bx) & (h > 52) & (h < 110) & (s > 0.38), 1)
    seeds = [(pivot[0] + dx, pivot[1] - dy) for dx in (-26, -18, -10, -4, 4, 10, 18, 26) for dy in (2, 8, 14, 20)]
    return grow(flood(g, *[(x, y) for x, y in seeds if 0 <= x < GW and 0 <= y < GH]), 1)


def figure(rg, base, M, posefn, legbox=None, band=None, minus=None):
    """角色層。M 是角色的遮罩。上半身（頭、手、衣服）整塊照姿勢位移，一格都不變形。
    legbox、band 有給：腳踩在地上，legbox 框裡人蔘皮顏色的是腿，墊在身體下面，
    band=(衣襬的高度, 腳底) 之間壓短或拉長，腳不動。沒給：整個人浮著，連腿一起整塊移。
    minus：另外做成零件的東西（葉子、水桶、劍、金丹、手杖），從身體扣掉。
    回傳身體零件、身體這一格往下移了幾格、取姿勢的函式。"""
    if legbox:
        # 腳底那一帶只留腿：去背時黏上來的地面、石頭留在背景層
        legs0 = close(box(*legbox) & rooty(base) & M, 1)
        if minus is not None:
            legs0 &= ~minus          # 顏色像腿、其實是道具的格子（木桶的邊）不算腿
        M = M & ~((YS >= band[1] - 3) & ~legs0)
    C = grow(M, 1)
    rg.hole = grow(M, 2)
    P, D = stance(lambda f: padd(posefn(f), idle_pose(f)))
    body = C.copy()
    if minus is not None:
        body &= ~minus
    if legbox:
        lg = grow(legs0, 1) & C
        rg.part('legs', lg, lambda f: [tie(band[0], band[1], *D(f))])
        body &= ~(lg & (YS >= band[0]))
    part = rg.part('body', body, lambda f: [shift(*D(f))])
    return part, (lambda f: D(f)[1]), P


def leaves(rg, base, body, lm, pivot, heady, k=0.9, lim=4.0, ph=0.0):
    """葉子分左右兩片掛在頭頂，各自繞葉柄轉。
    平常被風輕輕帶：兩片一起往一邊偏 1.5 度、回正、再往另一邊（一次換一個姿勢，不是連續慢轉，連續轉邊緣會一直閃）。
    身體有動的時候：頭往下一沉，葉尖慢一拍、先翹起來再甩下去，盪幾下才停。"""
    flap = lambda f: max(-lim, min(lim, k * follow(heady, f)))
    wind = lambda f: 1.5 * round(1.3 * math.sin(TAU * (f / 48.0 + ph)))
    rg.part('leaf_l', lm & (XS < pivot[0]), lambda f: [rot(pivot, wind(f) + flap(f))], body)
    rg.part('leaf_r', lm & (XS >= pivot[0]), lambda f: [rot(pivot, wind(f) - flap(f))], body)


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


def lantern(rg):
    flick = [.2, .5, .35, .6, .25, .55, .3, .5, .2, .45, .6, .35]
    rg.back.append(lambda img, f: glow(img, 144, 88, 13, flick[(f // 2) % 12], PALE))


def bucket_masks(base, arm_poly):
    arm = grow(cut(base, arm_poly, seeds=[(123, 128)]), 1)
    bk = grow(close(cut(base, BUCKET, bg=~woody(base), seeds=[(125, 160)]) | (poly([(111, 144), (139, 144), (138, 151), (112, 151)])), 4), 1)
    return arm, bk & ~arm


def bucket_parts(rg, body, arm_m, bk_m, arm_mv, swing):
    arm = Part('arm', arm_m, arm_mv, body)
    rg.parts.append(Part('bucket', bk_m, lambda f: [rot((125, 135), swing(f))], arm))
    rg.parts.append(arm)


def rig_r0(base, blink, M):
    """煉氣男：平常站著，桶輕輕晃。掂一次水桶：慢慢蹲、手往下沉，把桶提起來，放下時桶盪幾下、水濺出來。"""
    rg = Rig(base)
    pivot = (84, 42)
    lm = leafgreen(base, (28, 0, 138, 64), pivot)
    arm_m, bk_m = bucket_masks(base, [(113, 114), (124, 112), (132, 128), (132, 140), (118, 140), (114, 126)])

    def P(f):
        return pose(sq=keys(f, [(18, 0), (22, 1), (24, -0.67), (27, -0.67), (31, 0.33), (35, 0)]))
    body, heady, _ = figure(rg, base, M, P, (40, 146, 112, 199), (158, 196), minus=lm | bk_m)
    lift = lambda f: keys(f % N, [(19, 0), (22, 2), (24, -6), (27, -6), (30, 1), (33, 0)])
    load_y = lambda f: heady(f) + lift(f)
    idle_swing = lambda f: 2.0 * round(1.2 * math.sin(TAU * f / 48.0))       # 平常桶自己輕輕晃
    bucket_parts(rg, body, arm_m, bk_m, lambda f: [shift(0, lift(f))], lambda f: idle_swing(f) + 1.3 * follow(load_y, f, 0.2, 1.0, 24))
    leaves(rg, base, body, lm, pivot, heady)
    lantern(rg)

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


def rig_r0_parts(base, blink, M):
    """煉氣男，拆成零件的試做版。比整塊移動的版本多三個零件：頭（含根鬚、臉、紅果）、提桶的手臂、兩片葉子掛在頭上。
    被擋住的地方（頭底下的衣領、衣襬底下的腿、袖口底下的手臂）用「往一個方向複製格子」補，不是糊的。
    多出來的動作：呼吸時頭晚兩格才跟上；頭會歪向一邊看；手臂繞肩膀擺，桶掛在手上垂著晃。"""
    rg = Rig(base)
    rg.bg_rows = True
    C = grow(M, 1)
    pivot = (84, 42)
    lm = leafgreen(base, (28, 0, 138, 64), pivot)
    h_, s_, v_ = hsv(base)
    skin = rooty(base) & (v_ > 0.75)
    # 頭：臉、根鬚、紅果，往下到衣領中間露出來的那一小塊。88 以下只收人蔘皮的顏色，衣服不算
    headp = poly([(64, 0), (116, 0), (116, 40), (110, 56), (124, 70), (126, 92), (112, 94), (106, 90), (98, 96), (89, 103), (80, 98),
                  (66, 92), (60, 90), (56, 95), (46, 97), (42, 114), (31, 114), (31, 58), (56, 54)])
    head = flood(close(C & headp & ~lm & ((YS < 88) | skin | (XS < 58) | (XS > 110)), 1), (86, 70), (86, 60), (92, 12))
    # 提桶的手臂：只有人蔘皮的部分，往上多留幾格藏在袖口底下，轉的時候才不會露出缺口
    arm_poly = [(113, 114), (124, 112), (132, 128), (132, 140), (118, 140), (114, 126)]
    arm_skin = close(cut(base, arm_poly, seeds=[(123, 128)]) & skin, 1)
    up = np.zeros_like(arm_skin)
    for k in range(1, 6):
        up[:-k, :] |= arm_skin[k:, :]
    arm_m = grow(arm_skin, 1) | (up & C & ~head & (YS < 120))
    _, bk_m = bucket_masks(base, arm_poly)
    bk_m = bk_m & ~arm_skin & ~(pale(base, 228) & (YS < 142))      # 提把中間透出來的白底不是桶
    # 手邊剩下的零碎（握在手裡的那一小段提把、手的邊緣）跟著手臂走，不要留在身體上
    loose = C & box(113, 119, 134, 142) & ~bk_m & ~pale(base, 228)
    arm_m = arm_m | loose

    def P(f):
        return pose(sq=keys(f, [(18, 0), (22, 1), (24, -0.67), (27, -0.67), (31, 0.33), (35, 0)]))
    body, heady, _ = figure(rg, base, M, P, (40, 146, 112, 199), (158, 196), minus=lm | bk_m | head | grow(arm_skin, 1) | box(113, 119, 150, 190))
    rg.hole = grow(M, 3)              # 背景層多補一圈，免得角色邊緣的雜色被複製進去
    rg.parts[0].fill = (-1, 0)        # 腿：衣襬底下那一段，從看得到的腿往上複製
    body.name = 'torso'

    # 手臂繞肩膀轉。平常輕輕擺（一次換一個姿勢），掂桶時先往下沉、再往外提起來
    swing = lambda f: 2.0 * round(1.2 * math.sin(TAU * f / 48.0)) + keys(f % N, [(19, 0), (22, 5), (24, -24), (27, -24), (30, 4), (33, 0)])
    shoulder, grip = (115, 115), (121, 132)
    arm = Part('arm', arm_m, lambda f: [rot(shoulder, swing(f))], body, fill=(-1, 0))
    # 桶掛在手上：手臂轉多少它就反過來轉多少（所以一直垂著），再加上被手帶動的餘盪
    hang = lambda f: -swing(f) + 0.3 * follow(swing, f, 0.2, 1.0, 24)
    rg.parts.insert(1, arm)           # 手臂墊在身體下面，袖口蓋著它
    rg.parts.append(Part('bucket', bk_m, lambda f: [rot(grip, hang(f))], arm))

    # 頭：晚兩格才跟上身體（呼吸時脖子那邊會有一點錯開），偶爾歪一下。掂桶時歪向桶那邊看
    lag = lambda f: heady(f - 2) - heady(f)
    tilt = lambda f: 1.5 * round(keys(f % N, [(20, 0), (23, 3), (29, 3), (33, 0), (54, 0), (57, -3), (69, -3), (72, 0)]) / 1.5)
    neck = (87, 97)
    # 頭墊在衣服下面、往下多畫五格脖子（從下巴的顏色往下複製），頭抬起來或歪的時候，衣領裡露出來的是脖子不是空隙
    chin = head & skin & (YS >= 84)
    down = np.zeros_like(chin)
    for k in range(1, 6):
        down[k:, :] |= chin[:-k, :]
    hd = Part('head', head | (down & C & ~lm), lambda f: [shift(0, lag(f)), rot(neck, tilt(f))], body, fill=(1, 0))
    rg.parts.insert(rg.parts.index(body), hd)
    leaves(rg, base, hd, lm, pivot, lambda f: heady(f - 2) + 0.8 * tilt(f))
    lantern(rg)

    def splash(img, f):
        t = f - 24
        if 0 <= t < 5:
            for k in (-1, 0, 1):
                dot(img, 136 + k * (4 + 3 * t), 134 + int(heady(f)) - 5 * t + 1.3 * t * t, WHITE, 1 - t * 0.18)
                dot(img, 136 + k * (4 + 3 * t), 135 + int(heady(f)) - 5 * t + 1.3 * t * t, PALE, 0.7 - t * 0.12)
    rg.front.append(splash)
    if blink is not None:
        rg.blink(blink, [14, 15, 70, 71])
    return rg


def rig_gr0(base, blink, M):
    """煉氣女：提著桶慢慢左右搖（一次移一格、停一下），桶慢半拍往反方向盪。搖一陣子停下來歇一下。"""
    rg = Rig(base)
    pivot = (84, 42)
    lm = leafgreen(base, (28, 0, 138, 62), pivot)
    arm_m, bk_m = bucket_masks(base, [(114, 114), (126, 114), (132, 128), (132, 140), (119, 140), (115, 126)])

    def P(f):
        return pose(ln=0 if 64 <= f < 80 else 0.6 * SW[(f // 4) % 8])
    body, heady, PP = figure(rg, base, M, P, (40, 148, 112, 199), (160, 196), minus=lm | bk_m)
    tilt = lambda f: 2.5 * PP(f)['ln']
    bucket_parts(rg, body, arm_m, bk_m, lambda f: [],
                 lambda f: -4.0 * follow(tilt, f, 0.25, 0.9, 24) + 1.2 * follow(heady, f, 0.25, 1.0, 24))
    leaves(rg, base, body, lm, pivot, lambda f: heady(f) + 0.6 * tilt(f))
    lantern(rg)
    if blink is not None:
        rg.blink(blink, [16, 17, 68, 69])
    return rg


# ---------- 築基 ----------
SWORD = [(146, 37), (154, 38), (156, 46), (138, 84), (137, 91), (127, 92), (124, 104), (112, 104), (111, 92), (118, 84), (119, 76), (142, 44)]


def swordsman(rg, base, M, bx, pivot, legbox, band, arm_poly, shoulder, sw, P):
    lm = leafgreen(base, bx, pivot)
    blade = cut(base, SWORD, seeds=[(140, 60)])
    sword = grow(blade, 1) & (lum(base) < 250) & poly(SWORD) | blade
    body, heady, _ = figure(rg, base, M, P, legbox, band, minus=lm | (sword & ~poly(arm_poly)))
    arm = rg.part('arm', grow(cut(base, arm_poly, seeds=[(110, 106)]), 1), lambda f: [rot(shoulder, 0.45 * sw(f % N))], body)
    rg.part('sword', sword, lambda f: [rot((118, 97), 0.55 * sw(f % N))], arm)
    leaves(rg, base, body, lm, pivot, heady)

    def glint(img, f):
        """平常劍上偶爾有一點光從劍柄滑到劍尖。"""
        g = (f % N) - 62
        if 0 <= g < 8:
            plus(img, 121 + (150 - 121) * g / 7.0, 84 + (42 - 84) * g / 7.0 + heady(f), WHITE, 1.0 if g < 6 else 0.5)
    rg.front.append(glint)
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


def rig_r1(base, blink, M):
    """築基男：先蹲一下，把劍慢慢舉過頭、整個人跟著站高，一格劈下來、人往下一沉往前帶，再彈回站好。"""
    rg = Rig(base)
    sw = lambda f: keys(f, [(16, 0), (24, -32), (26, -34), (27, -8), (28, 18), (29, 20), (32, 12), (40, 0)])

    def P(f):
        return pose(sq=keys(f, [(16, 0), (18, 0.5), (24, -1), (26, -1), (28, 1.5), (31, 1), (38, 0)]),
                    ln=keys(f, [(19, 0), (26, -0.8), (27, 0), (28, 1.2), (31, 1.0), (38, 0)]))
    heady = swordsman(rg, base, M, (25, 0, 138, 64), (82, 42), (30, 150, 126, 198), (164, 194),
                      [(98, 93), (110, 90), (118, 92), (124, 98), (122, 106), (117, 112), (114, 128), (106, 128), (102, 112)], (100, 100), sw, P)
    smear(rg, {27: (-34, -8, 0.85), 28: (-8, 18, 0.55), 29: (12, 20, 0.25)}, {28: 18, 29: 19}, heady)
    if blink is not None:
        rg.blink(blink, [10, 11, 66, 67])
    return rg


def rig_gr1(base, blink, M):
    """築基女：連點兩劍。第一下短，縮一下就刺；第二下蓄久一點、整個人往前送再收回來。"""
    rg = Rig(base)
    sw = lambda f: keys(f, [(10, 0), (13, -14), (14, 10), (15, 12), (18, 0), (20, 0), (23, -20), (24, 14), (25, 16), (28, 8), (36, 0)])

    def P(f):
        return pose(sq=keys(f, [(11, 0), (13, 0.5), (14, -0.33), (18, 0), (20, 0), (23, 0.67), (24, -0.5), (29, 0)]),
                    ln=keys(f, [(12, 0), (13, -0.4), (14, 0.6), (17, 0), (22, 0), (23, -0.6), (24, 1.0), (27, 0.6), (34, 0)]))
    heady = swordsman(rg, base, M, (25, 0, 138, 62), (84, 42), (30, 152, 126, 198), (166, 194),
                      [(98, 95), (112, 92), (120, 94), (127, 100), (126, 110), (122, 126), (108, 128), (102, 112)], (100, 102), sw, P)
    smear(rg, {14: (-14, 10, 0.6), 24: (-20, 14, 0.85), 25: (8, 16, 0.4)}, {15: 12, 25: 16, 26: 16}, heady)
    if blink is not None:
        rg.blink(blink, [40, 41, 74, 75])
    return rg


# ---------- 金丹 ----------
def core_mask(base, c):
    """只有金丹那一顆。下面托著它的手指顏色一樣、又連在一起，所以高度要切在金丹底下，不然手指會跟著金丹飛走。"""
    h, s, v = hsv(base)
    return grow(flood(disc(c, 9) & (s > 0.42) & (YS <= c[1] + 6), c), 1) & (YS <= c[1] + 7)


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


def rig_r2(base, blink, M):
    """金丹男：平常金丹在掌心上方輕輕浮。人慢慢蹲一下，往上一送把金丹拋高；落回掌心時人微微一沉，迸出一圈火花。"""
    rg = Rig(base)
    pivot = (82, 38)
    c = (135, 57)
    toss = {23: -6, 24: -12, 25: -17, 26: -20, 27: -21, 28: -20, 29: -17, 30: -12, 31: -6}
    lm = leafgreen(base, (22, 0, 132, 52), pivot)
    core = core_mask(base, c)
    M = M & ~(disc(c, 16) & (YS < c[1] + 6))     # 金丹周圍的光暈是背景，不要跟著身體走

    def P(f):
        return pose(sq=keys(f, [(20, 0), (22, 1), (24, -0.67), (30, -0.33), (32, 0.67), (36, 0)]))
    body, heady, _ = figure(rg, base, M, P, (44, 140, 112, 190), (158, 186), minus=lm | core)
    # 平常金丹在掌心上方輕輕浮：上一格、回來、下一格
    fly = lambda f: toss.get(f % N, 0) if 18 <= (f % N) < 36 else int(round(math.sin(TAU * f / 24.0)))
    rg.part('core', core, lambda f: [shift(0, fly(f))], body)
    leaves(rg, base, body, lm, pivot, heady)
    core_fx(rg, c, lambda f: (0, fly(f) + heady(f)), catch=32, trail=3)
    if blink is not None:
        rg.blink(blink, [12, 13, 68, 69])
    return rg


def rig_gr2(base, blink, M):
    """金丹女：金丹在掌心上方繞圈，後面拖一串光點，身體跟著它輕輕左右移。繞到第二圈，金丹盪出一圈光環。"""
    rg = Rig(base)
    pivot = (82, 38)
    c = (136, 60)
    orbit = lambda f: (int(round(5 * math.cos(TAU * f / 24.0))), int(round(3.5 * math.sin(TAU * f / 24.0) - 2)))
    lm = leafgreen(base, (22, 0, 132, 42), pivot)
    core = core_mask(base, c)
    M = M & ~(box(113, 38, 154, c[1] + 5) & ~core)     # 金丹周圍那一圈光暈是背景，不要跟著身體走；手指留在身體上

    def P(f):
        return pose(ln=0.6 * math.cos(TAU * f / 24.0))
    body, heady, _ = figure(rg, base, M, P, (44, 146, 114, 190), (164, 186), minus=lm | core)
    rg.part('core', core, lambda f: [shift(*orbit(f))], body)
    leaves(rg, base, body, lm, pivot, heady)
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
def staff_mask(base, M):
    """手杖、握著它的手、掛在上面的流蘇。"""
    wood = (lum(base) < 180) & (base[..., 0] - base[..., 2] > 50)
    staff = close(poly([(114, 40), (160, 40), (160, 86), (146, 102), (144, 190), (126, 192), (124, 104), (118, 98), (114, 70)]) & wood, 1)
    staff = flood(staff, (134, 150), (140, 60)) | cut(base, [(128, 98), (144, 98), (144, 112), (128, 112)])
    return grow(staff, 1) | (grow(M, 1) & box(118, 52, 144, 100))


def rig_r3(base, blink, M):
    """元嬰男：站在雲上慢慢呼吸。把手杖提起來、人跟著升高，往下一頓，人一沉，腳邊盪開兩圈光紋。"""
    rg = Rig(base)
    pivot = (88, 22)
    lm = leafgreen(base, (35, 0, 136, 52), pivot)
    staff = staff_mask(base, M)

    def P(f):
        return pose(sq=keys(f, [(20, 0), (25, -1), (26, -1), (27, 1.5), (29, 1), (35, 0)]))
    body, heady, _ = figure(rg, base, M, P, minus=lm | staff)
    lift = lambda f: keys(f % N, [(20, 0), (25, -7), (26, -7), (27, 0)])
    rg.part('staff', staff, lambda f: [shift(0, lift(f))], body)
    leaves(rg, base, body, lm, pivot, heady, 0.7)
    rg.front.append(lambda img, f: glow(img, 86, 38 + heady(f), 15, .12 + .30 * (.5 + .5 * cyc(f, 24, -0.25)), PALE))
    motes(rg, [(22, 186), (48, 196), (70, 204), (108, 202), (150, 190), (160, 150)], 1.2)

    def ripple(img, f):
        for delay in (0, 4):
            g = f - 27 - delay
            if 0 <= g < 12:
                rx = 7 + g * 3.4
                for k in range(0, 360, 6):
                    if (k // 6 + g) % 2:
                        continue
                    t = math.radians(k)
                    x, y = 133 + rx * math.cos(t), 192 + rx * 0.26 * math.sin(t)
                    dot(img, x, y, AMBER, 0.95 * (1 - g / 14.0))
                    dot(img, x + 1, y, AMBER, 0.8 * (1 - g / 14.0))
                    dot(img, x, y - 1, GOLD, 0.8 * (1 - g / 12.0))
        if f in (27, 28):
            plus(img, 133, 190, GOLD)
    rg.front.append(ripple)
    return rg


def rig_gr3(base, blink, M):
    """元嬰女：站在雲上慢慢呼吸。兩隻手各升起一顆光點，繞個彎匯進頭頂的元嬰；匯進去那一格人縮一下、往上一挺，元嬰亮起來、盪出一圈光。"""
    rg = Rig(base)
    pivot = (86, 22)
    lm = leafgreen(base, (32, 0, 136, 54), pivot)
    hit = 20

    def P(f):
        return pose()
    body, heady, _ = figure(rg, base, M, P, minus=lm)
    leaves(rg, base, body, lm, pivot, heady, 0.7)

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
    motes(rg, [(20, 188), (46, 198), (72, 204), (110, 202), (150, 192), (10, 150)], 1.2)
    return rg


# ---------- 化神 ----------
def night(rg, base, stars, meteors):
    """星星和流星畫在背景層上、角色後面。"""
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
    rg.back.append(fx)


def rig_r4(base, blink, M):
    """化神男：整個人在夜空裡慢慢浮上浮下。深吸一口氣、人慢慢升高，停住，一口吐出來、人一沉，星光從身邊散開。流星由慢到快劃過去。"""
    rg = Rig(base)
    pivot = (86, 30)
    lm = leafgreen(base, (35, 0, 132, 50), pivot)

    def P(f):
        return pose(sq=keys(f, [(18, 0), (25, -1.33), (28, -1.33), (30, 0.33), (35, 0)]))
    body, heady, _ = figure(rg, base, M, P, minus=lm)
    leaves(rg, base, body, lm, pivot, heady, 0.7)
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


def rig_gr4(base, blink, M):
    """化神女：浮在夜空裡。四周的星光一顆顆被吸過來、繞個彎落進兩邊掌心；吸夠了，縮一下、往上一挺，兩掌的光一起炸開。"""
    rg = Rig(base)
    pivot = (86, 30)
    lm = leafgreen(base, (35, 0, 130, 48), pivot)
    hit = 34

    def P(f):
        return pose()
    body, heady, _ = figure(rg, base, M, P, minus=lm)
    leaves(rg, base, body, lm, pivot, heady, 0.7)
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
def rig_r5(base, blink, M):
    """大乘男：浮在雲上慢慢起伏。縮一下、往上一挺，背後的光輪盪出一圈金環，皇冠上的寶石閃一下，再慢慢落定。背後的佛光一直在轉。"""
    rg = Rig(base)
    pivot = (88, 38)
    lm = leafgreen(base, (40, 0, 138, 56), pivot)
    c = (88, 52)
    hit = 22

    def P(f):
        return pose()
    body, heady, _ = figure(rg, base, M, P, minus=lm)
    leaves(rg, base, body, lm, pivot, heady, 0.7)

    def halo(img, f):
        """畫在背景層上、角色後面，所以不用管角色移到哪。只畫在原本就亮的地方（天空的光），不蓋到山。"""
        light = (lum(rg.bg) > 205).astype(np.float32)
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
        img[:] = img * (1 - light[..., None]) + tmp * light[..., None]
        glow(img, c[0], c[1], 74, .04 + .10 * (.5 + .5 * cyc(f, 24)) + (.22 * max(0.0, 1 - abs(g - 1) / 4.0)), PALE, only=light)
    rg.back.append(halo)

    def gem(img, f):
        g = f - hit
        if 0 <= g < 4:
            plus(img, 87, 36 + heady(f), WHITE, 1.0 if g < 3 else 0.5)
    rg.front.append(gem)
    motes(rg, [(18, 176), (40, 150), (62, 190), (110, 186), (132, 150), (152, 178)])
    if blink is not None:
        rg.blink(blink, [10, 11, 64, 65])
    return rg


def rig_gr5(base, blink, M):
    """大乘女：浮在雲上，一拍一拍輕輕左右移。金色花瓣從上面一片片飄下來、邊落邊翻面；中間開心地往上一挺。背後的光一明一暗。"""
    rg = Rig(base)
    pivot = (88, 40)
    lm = leafgreen(base, (44, 0, 132, 54), pivot)

    def P(f):
        return pose(ln=0.6 * SW[(f // 6) % 8])
    body, heady, PP = figure(rg, base, M, P, minus=lm)
    tilt = lambda f: 2.0 * PP(f)['ln']
    leaves(rg, base, body, lm, pivot, lambda f: heady(f) + 0.6 * tilt(f), 0.7)
    rg.back.append(lambda img, f: glow(img, 88, 52, 66, .05 + .14 * (.5 + .5 * cyc(f, 24, -0.25)), PALE, only=(lum(rg.bg) > 205).astype(np.float32)))
    rnd = random.Random(5)
    petals = [(rnd.uniform(8, 160), rnd.uniform(0, GH), rnd.uniform(0, 1), rnd.choice((3, 4, 5))) for _ in range(11)]

    def fall(img, f):
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
EMBERS = [(30, 198), (56, 205), (118, 202), (144, 192), (92, 207), (70, 198)]


def storm(rg, embers):
    def fx(img, f):
        glow(img, 84, 192, 34, .08 + .20 * (.5 + .5 * cyc(f, 12)), GOLD)
        for i, (x, y) in enumerate(embers):
            g = (f + i * 9) % N
            dot(img, x + 2 * math.sin(g / 4.0 + i), y - g * 1.1, GOLD, math.sin(math.pi * g / N))
    rg.front.append(fx)


def rig_r6(base, blink, M):
    """渡劫男：喘著氣撐著。天暗下來、人越蹲越低，一道大雷沿著畫裡的閃電劈下來，整張閃白、人被壓到最低；頂住之後一口氣挺回來。"""
    rg = Rig(base)
    pivot = (86, 42)
    lm = leafgreen(base, (34, 14, 124, 62), pivot)
    hit = 23
    main = [(142, 0), (137, 20), (131, 40), (126, 58), (121, 75), (118, 92)]
    side = [(122, 72), (134, 84), (130, 98), (142, 112), (138, 126)]

    def P(f):
        return pose(sq=keys(f, [(18, 0), (23, 2.5), (25, 3), (27, 1), (29, -0.67), (34, 0)]))
    body, heady, _ = figure(rg, base, M, P, (44, 144, 118, 186), (152, 184), minus=lm)
    leaves(rg, base, body, lm, pivot, heady)
    storm(rg, EMBERS)

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
    if blink is not None:
        rg.blink(blink, [8, 9, 62, 63])
    return rg


def rig_gr6(base, blink, M):
    """渡劫女：細電弧一條條在身上竄、一閃就沒。左邊先落一道小雷，人一沉又彈回來；隔一陣子右邊那道大的再劈一次。"""
    rg = Rig(base)
    pivot = (86, 40)
    lm = leafgreen(base, (40, 8, 124, 52), pivot)
    hits = (12, 34)
    main = [(130, 0), (128, 20), (124, 40), (121, 60), (118, 80), (116, 95)]
    left = [(36, 0), (30, 22), (40, 26), (28, 52), (38, 56), (26, 78)]

    def P(f):
        return pose(sq=keys(f, [(10, 0), (12, 1.5), (14, 1.5), (18, 0), (32, 0), (34, 2.5), (36, 2.5), (41, 0)]))
    body, heady, _ = figure(rg, base, M, P, (46, 146, 118, 186), (155, 184), minus=lm)
    leaves(rg, base, body, lm, pivot, heady)
    storm(rg, EMBERS)
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
    if blink is not None:
        rg.blink(blink, [22, 23, 76, 77])
    return rg


# 拆成零件的試做版。環境變數 PARTS=1 時用這裡的，成品檔名多一段 _parts，零件圖層另外存到 OUTDIR/<代號>_layers/
PARTS = {'r0': rig_r0_parts}
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
        M = np.asarray(Image.open(os.path.join(folder, '%s_%dx%d_mask.png' % (name, GW, GH)))) > 127
        pal_lab = px.rgb2lab(pal.astype(np.float32))
        use_parts = bool(os.environ.get('PARTS')) and name in PARTS
        rg = (PARTS if use_parts else RIGS)[name](base, blink, M)
        frames = rg.frames()
        sheet = np.zeros((GH * (N // COLS), GW * COLS), dtype=np.uint8)
        cells = []
        for i, fr in enumerate(frames):
            cells.append(px.nearest(px.rgb2lab(np.clip(fr, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW))
            r, c = divmod(i, COLS)
            sheet[r * GH:(r + 1) * GH, c * GW:(c + 1) * GW] = cells[-1]
        im = Image.fromarray(sheet, mode='P')
        im.putpalette(pal.reshape(-1).tolist())
        tag = ('_parts' if use_parts else '') + ('' if STYLE == DEFAULT_STYLE else '_' + STYLE)
        outdir = os.environ.get('OUTDIR', folder) if tag else folder
        out = os.path.join(outdir, '%s_anim%d%s.png' % (name, N, tag))
        if use_parts:
            # 把每個零件存成一張透明底的圖（顏色都收回色盤），由下往上編號。檔名開頭的數字就是疊的順序
            ldir = os.path.join(outdir, name + '_layers')
            os.makedirs(ldir, exist_ok=True)
            quant = lambda a: pal[px.nearest(px.rgb2lab(np.clip(a, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)]
            Image.fromarray(quant(rg.bg)).save(os.path.join(ldir, '0_bg.png'))
            for i, part in enumerate(rg.parts):
                rgba = np.dstack([quant(part.tex), (part.mask * 255).astype(np.uint8)])
                Image.fromarray(rgba, 'RGBA').save(os.path.join(ldir, '%d_%s.png' % (i + 1, part.name)))
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
            bgq = px.nearest(px.rgb2lab(np.clip(rg.bg, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)
            Image.fromarray(pal[bgq]).save(os.path.join(dbg, 'bg_%s.png' % name))


if __name__ == '__main__':
    main()
