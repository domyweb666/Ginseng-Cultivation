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
輸出：{代號}_anim96.png（動畫），以及同樣 12×8 排法的 {代號}_anim96_mask.png（白＝角色，付費造型換色用，見 layers()）。
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
    windy = _windy_now           # 起風的場景（煉氣、渡劫），8.4 秒那陣風把葉子吹歪
    wind = lambda f: 1.5 * round(1.3 * math.sin(TAU * (f / 48.0 + ph)) + (gust(f) / 1.5 if windy else 0))
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


# ---------- 環境特效（照每個境界的背景配）----------
# 多米 2026-11-18：看完分層動畫實驗，還是覺得 app 原本的動畫好，要在原本的上面加特效。
# 第一版 14 張都套同一組（落葉、起風、紅果閃），他說每個境界要不一樣，要看背景裡有什麼再配。照他點頭的表：
#   煉氣 山村石板路、草叢 → 起風捲起草屑、頭上葉子被吹歪；兩邊樹叢偶爾掉一片葉子（燈籠光原本就有）
#   築基 練功場石地、石階、霧山 → 出劍那一下腳邊揚起一圈塵土；石階和遠山前一層薄霧慢慢飄
#   金丹 懸崖、崖邊的雲和灰山 → 雲絲在灰山前慢慢流；一隻小仙鶴拍著翅膀從天上飛過
#   元嬰 站在金白色的雲上 → 腳下的雲邊冒出小雲絮往兩邊飄散（金色光點原本就有）
#   化神 夜空、星星、下方雲海 → 星星加多、化神女也加一顆流星；下方雲海起一層慢慢飄的霧
#        （表上原本寫月暈，放大看那兩彎黃色是葉尖，不是月亮，所以沒做）
#   大乘 背後金色光輪 → 大乘男：金粉從光輪往下灑（佛光原本就在轉）；大乘女：光輪的光芒一道道輪流亮（花瓣原本就有）
#   渡劫 烏雲、雷、山頂碎石 → 斜斜的雨絲一直下；雷劈下來那一下腳邊碎石彈起來；起風時頭上葉子被吹歪
#   14 張都有：沒有大動作的空檔，頭上紅果閃一下金色四角星，跟著身體呼吸一起升降。
# 招牌動作都在前 48 格，起風排在後半段（GUST0）。這些都畫在 rg.back / rg.front，付費造型會照特效的規矩換色。
GUST0 = 56                                   # 起風那一格（8.4 秒）
GUST_KEYS = [(GUST0, 0), (GUST0 + 3, 9), (GUST0 + 6, -4.5), (GUST0 + 9, 4.5), (GUST0 + 12, -1.5), (GUST0 + 15, 0)]
WINDY = {'r0', 'gr0', 'r6', 'gr6'}           # 有起風的場景
_windy_now = False                           # make_rig 建骨架時設定，leaves() 建葉子時讀
TWINKLES = (50, 84)                          # 紅果閃的格（兩顆輪流）
GRASS_A = np.array([76, 108, 32], dtype=np.float32)
GRASS_B = np.array([140, 164, 56], dtype=np.float32)
GRASS_EDGE = np.array([52, 78, 22], dtype=np.float32)
DUST_LIGHT = np.array([236, 226, 206], dtype=np.float32)
DUST_DARK = np.array([176, 156, 124], dtype=np.float32)
CLOUD_EDGE = np.array([214, 176, 108], dtype=np.float32)
DUST_EDGE = np.array([150, 128, 96], dtype=np.float32)
CRANE_DARK = np.array([70, 70, 82], dtype=np.float32)
RAIN = np.array([236, 242, 255], dtype=np.float32)
GOLD_EDGE = np.array([190, 112, 30], dtype=np.float32)
MIST_EDGE = {'r1': (186, 186, 196), 'gr1': (186, 186, 196), 'r2': (176, 176, 186), 'gr2': (176, 176, 186),
             'r4': (150, 146, 206), 'gr4': (150, 146, 206)}   # 霧、雲絲底下那條陰影，照各張雲的陰影色
ROCK_DARK = np.array([62, 58, 66], dtype=np.float32)
ROCK_LIGHT = np.array([126, 120, 128], dtype=np.float32)
# 付費造型換色時，這些特效顏色各算哪一種：0 亮、1 暖（金）、2 暗（見 造型風格/make_style_anims.py）。
# 原本的特效只有白、淡黃、金、琥珀，換成造型的亮色或暖色；這次加的草、葉子、碎石、仙鶴、塵土是深色或綠色，
# 不列出來的話會被當成最接近的金色，碎石變成金塊。葉子顏色每張不同，這裡放一般的深綠、亮綠當代表。
ENV_FX_KINDS = [(GRASS_A, 2), (GRASS_B, 1), (GRASS_EDGE, 2), (DUST_LIGHT, 0), (DUST_DARK, 2), (DUST_EDGE, 2),
                (CLOUD_EDGE, 2),   # 塵土、雲絮的邊算暗色：當暖色的話水墨造型會變成一圈圈印泥紅
                (CRANE_DARK, 2), (RAIN, 0), (ROCK_DARK, 2), (ROCK_LIGHT, 2), (GOLD_EDGE, 1),
                (np.array([186, 186, 196], np.float32), 0), (np.array([176, 176, 186], np.float32), 0),
                (np.array([150, 146, 206], np.float32), 0),
                (np.array([70, 100, 40], np.float32), 2), (np.array([140, 175, 70], np.float32), 1)]
# 飄落的葉子翻面的四個樣子（約 6 格長、帶深色邊；三格的版本放大三倍都看不到）
# o 深色邊、d 深綠、l 亮綠；每 3 格換一個樣子：正面、斜、側面（薄薄一條）、反斜
LEAF_SPRITES = [
    [".ooo..",
     "olllo.",
     "oldddo",
     ".oooo."],
    ["...oo",
     "..olo",
     ".oldo",
     "olddo",
     "oddo.",
     ".oo.."],
    ["oooo..",
     "oddlloo",
     ".ooooo."],
    ["oo...",
     "olo..",
     "oldo.",
     "oddlo",
     ".oddo",
     "..oo."],
]
# 仙鶴拍翅膀三個樣子：翅膀上、平、下（o 深灰的翅尖、x 白身體）
CRANE_SPRITES = [
    ["o.....o",
     ".o...o.",
     "..oxo..",
     "...xxxo"],
    ["ooo.ooo",
     "...xxxo"],
    ["...xxxo",
     "..oxo..",
     ".o...o.",
     "o.....o"],
]
# 每張的位置（168×210 格子上的座標，照背景量的）
LIANQI_LEAVES = {'r0': [(4, 8, 114), (52, 146, 106)], 'gr0': [(8, 8, 116), (58, 144, 108)]}   # (第幾格掉, x, y)
LIANQI_GROUND = 172                                    # 葉子落到這裡就淡掉
ZHUJI_STRIKE = {'r1': [28], 'gr1': [14, 24]}           # 出劍落定的格
ZHUJI_FEET = {'r1': [(51, 196), (107, 196)], 'gr1': [(58, 194), (110, 193)]}
ZHUJI_MIST = [(20, 58), (140, 70), (26, 96), (146, 112)]          # 薄霧中心：兩邊灰色的遠山、石階前（白天空上看不出霧）
JINDAN_WISPS = {'r2': [(150, 140), (140, 160), (20, 104), (154, 178)], 'gr2': [(150, 142), (140, 162), (16, 106), (152, 180)]}
YUANYING_PUFFS = [(44, 186), (130, 184), (60, 194), (116, 194), (34, 176), (140, 176)]
HUASHEN_OLD = {'r4': [(26, 38), (48, 24), (120, 22), (142, 36), (152, 62), (20, 70), (114, 46), (60, 44), (136, 20), (30, 56)],
               'gr4': [(26, 40), (50, 26), (122, 24), (150, 60), (20, 72), (60, 44), (30, 58)]}   # rig_r4 / rig_gr4 原本的星星
HUASHEN_METEOR = {'gr4': [(58, 150, 22, -4.4, 2.4, 10)]}           # (第幾格, x, y, vx, vy, 幾格)
HUASHEN_MIST = [(22, 168), (146, 160), (84, 196), (40, 186), (130, 190)]
DACHENG_RAYS = (88, 46, 54, 74)                                     # 大乘女光輪：中心 x, y、光芒從多遠畫到多遠
DUJIE_HITS = {'r6': [23], 'gr6': [12, 34]}


def gust(f):
    """起風時頭上葉子要多轉幾度（順時針＝往右吹）。"""
    return keys(f % N, GUST_KEYS)


def gust_rate(f):
    """起風那幾格，風每一格把飄著的東西往右推幾格。"""
    g = f % N - GUST0
    return 3.2 * math.sin(math.pi * g / 16.0) if 0 <= g < 16 else 0.0


def leaf_colors(base):
    h, s, v = hsv(base)
    g = (h > 52) & (h < 110) & (s > 0.38) & (YS < 80)
    if g.sum() < 10:
        return np.array([70, 110, 40], np.float32), np.array([140, 180, 70], np.float32)
    px_ = base[g]
    l = lum(px_)
    return px_[l <= np.percentile(l, 25)].mean(0), px_[l >= np.percentile(l, 75)].mean(0)


def berries(base):
    """頭上紅果裡兩顆的位置：最上面那顆和最左邊那顆。"""
    h, s, v = hsv(base)
    red = ((h < 14) | (h > 346)) & (s > 0.6) & (YS < 45)
    ys, xs = np.nonzero(red)
    if len(xs) < 4:
        return []
    return [(xs[ys.argmin()], ys.min() + 2), (xs.min() + 2, ys[xs.argmin()])]


def sprite(img, x, y, rows, cols, a=1.0):
    x0, y0 = int(round(x)) - len(rows[0]) // 2, int(round(y)) - len(rows) // 2
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch != '.':
                dot(img, x0 + c, y0 + r, cols[ch], a)


def draw_leaf(img, x, y, t, dark, light, a=1.0):
    sprite(img, x, y, LEAF_SPRITES[(t // 3) % 4], {'o': dark * 0.55, 'd': dark, 'l': light}, a)


def star(img, x, y, t):
    """紅果上閃一下：小十字 → 大的四角星 → 小十字。"""
    plus(img, x, y, GOLD, [0.7, 1.0, 0.6][t])
    if t == 1:
        for d in (-2, 2):
            dot(img, x + d, y, PALE, 0.9)
            dot(img, x, y + d, PALE, 0.9)
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            dot(img, x + dx, y + dy, GOLD, 0.45)


def mist(rg, spots, edge, amp=10, length=12):
    """一團團扁扁的雲霧在背景上左右慢慢飄、一濃一淡（一輪剛好來回一次，接得上）。畫在角色後面。
    第一版用光暈，白霧畫在淡色的畫上收色後整個消失；第二版畫成細長白線，像多米退過的風線。
    現在是扁的一團：白色身體、底下一條這張雲的陰影色，看起來是雲，不是線。length 是半寬。"""
    edge = np.array(edge, dtype=np.float32)

    def fx(img, f):
        for i, (x, y) in enumerate(spots):
            ph = i / float(len(spots))
            dx = amp * math.sin(TAU * (f / N + ph))
            a = 0.5 + 0.5 * math.sin(TAU * (f / N + ph + 0.25))
            if a < 0.2:
                continue
            a = min(1.0, a * 1.3)
            hw, hh = length * (0.8 + 0.2 * a), 2.6 + 1.2 * a
            for yy in range(int(-hh) - 1, int(hh) + 2):
                for xx in range(int(-hw) - 1, int(hw) + 2):
                    # 上緣鼓兩個包，像雲
                    top = hh * (0.75 + 0.25 * math.cos(xx / hw * math.pi * 2 + i))
                    e = (xx / hw) ** 2 + (yy / (top if yy < 0 else hh * 0.7)) ** 2
                    if e <= 0.75:
                        dot(img, x + dx + xx, y + yy, WHITE, a)
                    elif e <= 1.0 and yy >= 0:
                        dot(img, x + dx + xx, y + yy, edge, a * 0.9)
    rg.back.append(fx)


def puff(img, x, y, r, a, core, edge):
    """一團小雲（塵土）：中間實心、外面一圈邊。"""
    for dy in range(-5, 6):
        for dx in range(-6, 7):
            d = math.hypot(dx * 0.8, dy)
            if d <= r - 0.8:
                dot(img, x + dx, y + dy, core, a)
            elif d <= r + 0.3:
                dot(img, x + dx, y + dy, edge, a)


def berry_twinkle(rg, base):
    pts = berries(base)

    def offset(x, y, f):
        """(x, y) 那一格這一格被身體帶到哪裡：找蓋著它的最上面那個零件，照它的動作算位移。"""
        for p in reversed(rg.parts):
            if p.mask[y, x]:
                X, Y = np.array([x], np.float32), np.array([y], np.float32)
                for tr in p.chain(f):
                    X, Y = tr(X, Y)
                return x - float(X[0]), y - float(Y[0])
        return 0.0, 0.0

    def fx(img, f):
        for (bx, by), start in zip(pts, TWINKLES):
            t = f % N - start
            if 0 <= t < 3:
                dx, dy = offset(bx, by, f)
                star(img, bx + dx, by + dy, t)
    rg.front.append(fx)


def env_lianqi(rg, base, name):
    dark, light = leaf_colors(base)

    def fx(img, f):
        f %= N
        # 起風：地上捲起五根草屑飄過去
        t = f - GUST0
        if 0 <= t < 34:
            for j, (x0, y0) in enumerate([(10, 186), (22, 196), (4, 174), (30, 190), (16, 180)]):
                s = t - (0, 1, 3, 5, 7)[j]
                if not 0 <= s < 30:
                    continue
                x = x0 + 5.0 * s
                y = y0 - 10 * math.sin(min(s, 9) / 9 * math.pi / 2) + max(0, s - 9) * 0.9 + 2 * math.sin(s * 0.7)
                dx, dy = [(1, 0), (1, 1), (0, 1), (-1, 1)][(s // 2) % 4]
                a = min(1.0, (30 - s) / 6.0)
                for k, col in zip(range(-2, 3), (GRASS_EDGE, GRASS_EDGE, GRASS_A, GRASS_A, GRASS_B)):
                    dot(img, x + k * dx, y + k * dy, col, a)
        # 樹叢掉下來的葉子：慢慢擺著落到地上，起風那時候被推一把
        for i, (start, x0, y0) in enumerate(LIANQI_LEAVES.get(name, [])):
            t = (f - start) % N
            y = y0 + 1.6 * t
            if y > LIANQI_GROUND + 8:
                continue
            push = sum(gust_rate(start + k) for k in range(t))
            x = x0 + 4 * math.sin(TAU * t / 20.0 + i) + 0.2 * t + push
            fade = min(1.0, (LIANQI_GROUND + 8 - y) / 8.0)
            draw_leaf(img, x, y, t, dark, light, fade)
    rg.front.append(fx)


def env_zhuji(rg, base, name):
    mist(rg, ZHUJI_MIST, MIST_EDGE[name])
    strikes, feet = ZHUJI_STRIKE[name], ZHUJI_FEET[name]

    def dust(img, f):
        for hit in strikes:
            g = f % N - hit
            if not 0 <= g < 9:
                continue
            a = min(1.0, (9 - g) / 4.0)
            for fx_, fy in feet:
                for side in (-1, 1):
                    for k in range(2):          # 每隻腳往兩邊捲開兩團土
                        x = fx_ + side * (3 + k * 5 + g * (1.4 + 0.6 * k))
                        y = fy - 1 - g * 0.6 - k * 1.5
                        puff(img, x, y, min(3.2, 1.4 + g * 0.4) - k * 0.5, a, DUST_LIGHT, DUST_EDGE)
    rg.front.append(dust)


def env_jindan(rg, base, name):
    mist(rg, JINDAN_WISPS[name], MIST_EDGE[name], amp=9, length=9)

    def crane(img, f):
        f %= N
        x = 176 - 1.95 * f                       # 從右邊畫面外飛進來、一輪飛出左邊，接得上
        y = 22 + 3 * math.sin(TAU * f / 48.0)
        sprite(img, x, y, CRANE_SPRITES[(f // 2) % 3], {'o': CRANE_DARK, 'x': WHITE})
    rg.back.append(crane)


def env_yuanying(rg, base, name):
    def puffs(img, f):
        for i, (x0, y0) in enumerate(YUANYING_PUFFS):
            t = (f + i * 16) % N
            if t >= 28:
                continue
            side = -1 if x0 < 88 else 1
            x = x0 + side * 0.7 * t
            y = y0 - 0.25 * t
            r = min(4.2, 1.5 + t / 5.0)
            a = min(1.0, (28 - t) / 8.0, (t + 1) / 3.0)
            puff(img, x, y, r, a, WHITE, CLOUD_EDGE)
    rg.front.append(puffs)


def env_huashen(rg, base, name):
    # 多加的星星：從夜空裡挑，離原本的星星和彼此都至少 14 格
    sky = (base[..., 2] > base[..., 0] + 18) & (lum(base) < 190) & (YS < 120)
    rnd = random.Random(41 if name == 'r4' else 43)
    ys, xs = np.nonzero(shrink(sky, 2))
    order = rnd.sample(range(len(xs)), len(xs))
    taken, extra = list(HUASHEN_OLD[name]), []
    for k in order:
        p = (int(xs[k]), int(ys[k]))
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) >= 14 for q in taken):
            taken.append(p)
            extra.append(p)
        if len(extra) >= 9:
            break
    night(rg, base, extra, HUASHEN_METEOR.get(name, []))
    mist(rg, HUASHEN_MIST, MIST_EDGE[name], amp=12, length=12)


def env_dacheng(rg, base, name):
    if name == 'r5':
        rnd = random.Random(21)
        dust_ = [(rnd.uniform(8, 160), rnd.uniform(0, GH), rnd.uniform(0, 1)) for _ in range(22)]
        light = (lum(base) > 200).astype(np.float32)

        def gold(img, f):
            for i, (x0, y0, ph) in enumerate(dust_):
                y = (y0 + 2.1875 * f) % GH            # 一輪剛好落一個畫面高，接得上
                x = x0 + 3 * math.sin(TAU * (f / 32.0 + ph))
                xi, yi = int(round(x)), int(round(y))
                if not (0 <= xi < GW and 0 <= yi < GH) or not light[yi, xi]:
                    continue
                if (f + i * 3) % 8 < 2:            # 閃一下：深色邊的十字
                    for ddx, ddy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                        dot(img, x + ddx, y + ddy, GOLD_EDGE, 0.8)
                    plus(img, x, y, AMBER)
                else:
                    dot(img, x, y, AMBER)
                    dot(img, x + 1, y, GOLD_EDGE, 0.9)
                    dot(img, x, y + 1, GOLD_EDGE, 0.9)
        rg.back.append(gold)
    else:
        cx, cy, r0, r1 = DACHENG_RAYS
        light = (lum(base) > 205).astype(np.float32)

        def rays(img, f):
            """光輪外圈 12 道光芒，一道接一道輪流變亮，像在慢慢轉。只畫在原本就亮的天空，不蓋到雲和山。"""
            tmp = img.copy()
            for k in range(12):
                t = math.radians(k * 30 - 90)
                if math.sin(t) > 0.3:
                    continue
                lit = 0.5 + 0.5 * math.cos(TAU * (k / 12.0 - f / float(N) * 2))
                for r in range(r0, r1):
                    a = (0.25 + 0.6 * lit) * (1 - (r - r0) / float(r1 - r0 + 6))
                    dot(tmp, cx + r * math.cos(t), cy + r * math.sin(t), PALE, a)
                    dot(tmp, cx + r * math.cos(t) + 1, cy + r * math.sin(t), WHITE, a * 0.6)
            img[:] = img * (1 - light[..., None]) + tmp * light[..., None]
        rg.back.append(rays)


def env_dujie(rg, base, name):
    rnd = random.Random(31)
    drops = [(rnd.uniform(-40, GW), rnd.uniform(0, GH)) for _ in range(30)]
    hits = DUJIE_HITS[name]
    rocks = [(rnd.uniform(40, 130), rnd.uniform(-2.2, 2.2), rnd.uniform(4.5, 6.5)) for _ in range(7)]

    def rain(img, f):
        for x0, y0 in drops:
            y = (y0 + 4.375 * f) % GH                 # 一輪落兩個畫面高，接得上
            x = x0 + 0.3 * y
            for k in range(4):                       # 斜斜的一條，四格，頭亮尾淡
                dot(img, x - k * 0.6, y - k * 2, RAIN, 0.95 - k * 0.18)
        for hit in hits:
            g = f % N - hit
            if not 0 <= g < 16:
                continue
            for x0, vx, vy in rocks:                 # 雷打在山頂，碎石往上彈再掉回去
                x, y = x0 + vx * g, 184 - vy * g + 0.45 * g * g
                if y > 190:
                    continue
                sprite(img, x, y, [".oo", "oxo", "oo."] if g % 2 else ["oo.", "oxo", ".oo"], {'o': ROCK_DARK, 'x': ROCK_LIGHT})
    rg.front.append(rain)


ENV = {'r0': env_lianqi, 'gr0': env_lianqi, 'r1': env_zhuji, 'gr1': env_zhuji, 'r2': env_jindan, 'gr2': env_jindan,
       'r3': env_yuanying, 'gr3': env_yuanying, 'r4': env_huashen, 'gr4': env_huashen,
       'r5': env_dacheng, 'gr5': env_dacheng, 'r6': env_dujie, 'gr6': env_dujie}


def make_rig(name, base, blink, M, parts=False):
    global _windy_now
    plain = bool(os.environ.get('NO_AMBIENT'))     # 不加環境特效，跟加之前的版本比對用
    _windy_now = (name in WINDY) and not plain
    rg = (PARTS if parts else RIGS)[name](base, blink, M)
    _windy_now = False
    if not plain:
        ENV[name](rg, base, name)
        berry_twinkle(rg, base)
    return rg


# ---------- 煉氣 ----------
BUCKET =[(106, 128), (126, 126), (144, 134), (145, 150), (142, 170), (138, 180), (112, 180), (107, 168), (105, 148)]


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


CUFF_R0 = (104, 98, 127, 116)    # 煉氣男右手袖口那一圈（x0, y0, x1, y1）


def bucket_cut(bk_m, M):
    """從身體扣掉的水桶範圍。水桶遮罩為了切乾淨往外多長了幾格，貼著衣服那幾格其實是衣服；
    整塊扣掉的話水桶一盪開，那裡只剩背景層的白（多米 2026-11-18 抓到衣襬旁一條白線）。
    所以貼著衣服三格內、又在角色範圍裡的，留在身體上，被水桶擋住時由身體自己的衣服補。"""
    behind = bk_m & M & grow(M & ~bk_m, 3)
    return bk_m & ~behind


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
    arm_m, bk_m = arm_m & grow(M, 1), bk_m & grow(M, 1)   # 只留角色（多一格接住深色外框）：多切到的天空、石頭不能跟著手和桶被提上去（多米 2026-11-18）

    def P(f):
        return pose(sq=keys(f, [(18, 0), (22, 1), (24, -0.67), (27, -0.67), (31, 0.33), (35, 0)]))
    body, heady, _ = figure(rg, base, M, P, (40, 146, 112, 199), (158, 196), minus=lm | bucket_cut(arm_m | bk_m, M))
    lift = lambda f: keys(f % N, [(19, 0), (22, 2), (24, -6), (27, -6), (30, 1), (33, 0)])
    load_y = lambda f: heady(f) + lift(f)
    idle_swing = lambda f: 2.0 * round(1.2 * math.sin(TAU * f / 48.0))       # 平常桶自己輕輕晃
    bucket_parts(rg, body, arm_m, bk_m, lambda f: [shift(0, lift(f))], lambda f: idle_swing(f) + 1.3 * follow(load_y, f, 0.2, 1.0, 24))
    # 袖口疊在手臂上面：提桶時手臂往上收 6 格，要像收進袖子裡，不是蓋在袖子上
    rg.part('cuff', M & ~arm_m & ~bk_m & box(*CUFF_R0), None, body)
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
    arm_m, bk_m = arm_m & grow(M, 1), bk_m & grow(M, 1)   # 只留角色（多一格接住深色外框）：多切到的天空、石頭不能跟著桶盪

    def P(f):
        return pose(ln=0 if 64 <= f < 80 else 0.6 * SW[(f // 4) % 8])
    body, heady, PP = figure(rg, base, M, P, (40, 148, 112, 199), (160, 196), minus=lm | bucket_cut(arm_m | bk_m, M))
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
RIM_SATURATION = 0.30    # 金丹外框算「偏橘」的飽和度；光暈比這個淡


def core_mask(base, c, below=7, rim=False):
    """只有金丹那一顆。下面托著它的手指顏色一樣、又連在一起，所以高度要切在金丹底下，不然手指會跟著金丹飛走。
    below：切在金丹中心往下幾格。金丹女的金丹底下連著一條到掌心的細光，切太低那條光會跟著金丹繞圈、像在滴（多米 2026-11-18）。
    rim：再往外多帶兩格偏橘的外框。金丹女的金丹會左右繞圈，外框沒帶走就留在原地，像一段斷掉的棕色弧線（多米 2026-11-19 抓到）；
    淡色光暈不帶，不然金丹外面會多一圈硬邊。金丹男只上下浮，殘邊被金丹自己蓋住，不用。"""
    h, s, v = hsv(base)
    core = grow(flood(disc(c, 9) & (s > 0.42) & (YS <= c[1] + below - 1), c), 1)
    if rim:
        core |= grow(core, 2) & (s > RIM_SATURATION)
    return core & (YS <= c[1] + below)


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
    core = core_mask(base, c, below=4, rim=True)       # 金丹本體到第 64 列，底下那條細光留在手上
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


# ---------- 分層輸出（付費造型的動畫用，組塊 M2）----------
# 造型換色要知道每一格哪裡是角色、哪裡是背景、哪裡是特效。這裡照 Rig.frame 的疊法再走一次，
# 動作、時間、疊的順序都跟 Rig.frame 一樣，只是多記下每一格是從哪裡來的。成品動畫還是由 Rig.frame 產生，這裡不改它。
CHAR_MIN_PIECE = 8     # 跟 造型風格/ai_matte.py 的 MIN_PIECE 一樣


def fx_affine(fns, f, post=False):
    """把一串特效換成 out = img * T + C。特效都是「往某個顏色混 a」（點、線、光暈、閃白、變暗），疊幾層都還是這個形式，
    所以各餵一張全黑、全白的圖進去，就能把 T（底下透出來多少）和 C（特效貼上去的顏色乘上濃度）解出來。"""
    lo = np.zeros((GH, GW, 3), dtype=np.float32)
    hi = np.full((GH, GW, 3), 255.0, dtype=np.float32)
    for fn in fns:
        if post:
            lo, hi = fn(lo, f), fn(hi, f)
        else:
            fn(lo, f)
            fn(hi, f)
    return (hi - lo) / 255.0, lo


def layers(rg, A, f, fx=True):
    """第 f 格拆成幾層。A 是角色範圍（AI 去背的遮罩）。
    回傳 clean：沒有特效的畫面；char：這一格哪些格子是角色（零件搬過來的格子，原本的位置在 A 裡面才算，
    零件外面多切的那一圈背景色不算）；cover：哪些格子被零件蓋住（背景層的特效畫不到）；
    fx=True 時再加 back、front、post 三組 (T, C)，分別是角色後面、最上面、整張的特效。"""
    if not rg._built:
        rg.build()
    if rg.soft:
        raise ValueError('有柔性變形的骨架還沒支援分層輸出')
    union = rg.hole.copy() if rg.hole is not None else np.zeros((GH, GW), dtype=bool)
    for p in rg.parts:
        union |= p.mask
    closed = bool(rg._blink) and (f % N) in rg._blink[1]
    clean = (rg.bg_alt if closed else rg.bg).copy()
    char = A & ~union                 # 背景層裡沒被補掉、還留著原圖角色的格子
    cover = np.zeros((GH, GW), dtype=bool)
    for p in rg.parts:
        mask, tex = p.mask, (p.alt if closed else p.tex)
        X, Y = XS, YS
        for tr in p.chain(f):
            X, Y = tr(X, Y)
        sx, sy = np.floor(X + 0.5).astype(int), np.floor(Y + 0.5).astype(int)
        ok = (sx >= 0) & (sx < GW) & (sy >= 0) & (sy < GH)
        m = np.zeros((GH, GW), dtype=bool)
        m[ok] = mask[sy[ok], sx[ok]]
        clean[m] = tex[sy[m], sx[m]]
        char[m] = A[sy[m], sx[m]]
        cover |= m
    # 零件分開動的時候會切出一兩格離群的碎點（金丹女繞圈時金丹邊緣留在手上的兩格、葉子轉動切下的根鬚尖）。
    # 照 ai_matte.py 的規矩，小於 CHAR_MIN_PIECE 格的碎點當灰塵、不算角色；不然貼紙、霓虹會幫每顆碎點描一圈邊，一格一格閃
    from scipy import ndimage
    lab, n = ndimage.label(char, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(char, lab, range(1, n + 1))
        char &= np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= CHAR_MIN_PIECE])
    out = {'clean': clean, 'char': char, 'cover': cover}
    if fx:
        out['back'] = fx_affine(rg.back, f)
        out['front'] = fx_affine(rg.front, f)
        out['post'] = fx_affine(rg.post, f, post=True)
    return out


def build_rig(folder, name):
    """讀圖、建骨架。回傳 (骨架, 色盤, 角色範圍)。缺檔直接丟例外。"""
    base, pal = load(folder, name)
    if base is None:
        raise FileNotFoundError(os.path.join(folder, '%s_%dx%d.png' % (name, GW, GH)))
    blink, _ = load(folder, name, '_blink')
    M = np.asarray(Image.open(os.path.join(folder, '%s_%dx%d_mask.png' % (name, GW, GH)))) > 127
    return make_rig(name, base, blink, M), pal, M


def sheet_of(cells):
    """96 格排成 12×8 的格子圖。"""
    h, w = cells[0].shape[:2]
    out = np.zeros((h * (N // COLS), w * COLS) + cells[0].shape[2:], dtype=cells[0].dtype)
    for i, c in enumerate(cells):
        r, k = divmod(i, COLS)
        out[r * h:(r + 1) * h, k * w:(k + 1) * w] = c
    return out


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
        rg = make_rig(name, base, blink, M, use_parts)
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
        if not use_parts:
            # 每一格的角色範圍（白＝角色，零件掛在身上的道具、葉子都算），付費造型換色用
            chars = [layers(rg, M, f, fx=False)['char'] for f in range(N)]
            mout = os.path.join(outdir, '%s_anim%d%s_mask.png' % (name, N, tag))
            Image.fromarray(sheet_of([(c * 255).astype(np.uint8) for c in chars]), 'L').save(mout, optimize=True)
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
