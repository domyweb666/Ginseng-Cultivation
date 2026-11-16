"""像素立繪的小骨架：把一張圖切成幾個零件，每個零件每一格各自位移、旋轉、彎曲或起伏，再疊回去。

零件之間可以有父子關係（手臂帶著劍、身體帶著頭上的葉子），子零件會跟著父零件動。
所有變形都是「從輸出的格子回頭找原圖的格子」，只搬整格，不混色，所以顏色不會跑出色盤。
"""
import math

import numpy as np
from PIL import Image, ImageDraw

import pixelate2 as px

GW, GH = px.GW, px.GH
N = 48                       # 每條動畫的格數，一格 0.1 秒，一輪 4.8 秒
YS, XS = np.mgrid[0:GH, 0:GW].astype(np.float32)

GOLD = np.array([246, 207, 90], dtype=np.float32)
PALE = np.array([255, 244, 190], dtype=np.float32)
WHITE = np.array([255, 255, 255], dtype=np.float32)


# ---------- 遮罩 ----------
def poly(points):
    m = Image.new('L', (GW, GH), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in points], fill=255)
    return np.asarray(m) > 0


def box(x0, y0, x1, y1):
    m = np.zeros((GH, GW), dtype=bool)
    m[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = True
    return m


def lum(rgb):
    return rgb @ px.LW


def hsv(rgb):
    r, g, b = rgb[..., 0] / 255, rgb[..., 1] / 255, rgb[..., 2] / 255
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm, gm, bm = nz & (mx == r), nz & (mx == g) & (mx != r), nz & (mx == b) & (mx != r) & (mx != g)
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    return h * 60, s, mx


def leafy(rgb):
    """葉子的綠和果子的紅。"""
    h, s, v = hsv(rgb)
    green = (h > 52) & (h < 110) & (s > 0.38)
    red = ((h < 14) | (h > 346)) & (s > 0.6)
    return green | red


def pale(rgb, thr=236):
    return lum(rgb) > thr


def grow(mask, n=1):
    out = mask.copy()
    for _ in range(n):
        m = out.copy()
        m[1:, :] |= out[:-1, :]; m[:-1, :] |= out[1:, :]
        m[:, 1:] |= out[:, :-1]; m[:, :-1] |= out[:, 1:]
        out = m
    return out


def shrink(mask, n=1):
    return ~grow(~mask, n)


def close(mask, n=1):
    return shrink(grow(mask, n), n)


def flood(mask, *seeds):
    """只留跟 seeds（x, y）連在一起的那幾塊。"""
    out = np.zeros_like(mask)
    stack = [(y, x) for x, y in seeds if mask[y, x]]
    for y, x in stack:
        out[y, x] = True
    while stack:
        cy, cx = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < GH and 0 <= nx < GW and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                stack.append((ny, nx))
    return out


def cut(base, points, bg=None, seeds=None):
    """照多邊形切一個零件：多邊形裡面，扣掉從外面連進來的背景色；有給 seeds 就只留連著 seeds 的那一塊。"""
    P = poly(points)
    bg = pale(base) if bg is None else bg
    outside = ~P
    while True:
        nxt = outside | (grow(outside) & bg)
        if (nxt == outside).all():
            break
        outside = nxt
    m = P & ~outside
    return flood(m, *seeds) if seeds else m


def inpaint(rgb, hole, known=None):
    """把 hole 用 known 的顏色一圈一圈往裡補。known 沒給就是 hole 以外全部。"""
    out = rgb.copy()
    known = (~hole) if known is None else (known & ~hole)
    unknown = hole.copy()
    while unknown.any():
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
        known = known | fill
    return out


# ---------- 變形（都是回頭找原圖座標）----------
def shift(dx, dy):
    return lambda X, Y: (X - dx, Y - dy)


def rot(pivot, deg):
    """繞支點轉 deg 度，順時針為正。"""
    th = math.radians(deg)
    c, s = math.cos(th), math.sin(th)

    def f(X, Y):
        dx, dy = X - pivot[0], Y - pivot[1]
        return c * dx + s * dy + pivot[0], -s * dx + c * dy + pivot[1]
    return f


def bend(pivot, deg, length, power=1.0):
    """離支點越遠轉得越多，到 length 轉滿 deg 度。葉子、鬚、流蘇、飄帶尾巴用。"""
    def f(X, Y):
        dx, dy = X - pivot[0], Y - pivot[1]
        a = np.radians(deg) * np.clip(np.hypot(dx, dy) / length, 0, 1) ** power
        c, s = np.cos(a), np.sin(a)
        return c * dx + s * dy + pivot[0], -s * dx + c * dy + pivot[1]
    return f


def wave(origin, along, amp, wavelength, phase, grow_len, power=1.0):
    """沿著 along 方向（度）的布料，垂直方向起伏；離 origin 越遠擺得越大，波往尾端走。"""
    ux, uy = math.cos(math.radians(along)), math.sin(math.radians(along))

    def f(X, Y):
        s = (X - origin[0]) * ux + (Y - origin[1]) * uy
        g = np.clip(s / grow_len, 0, 1) ** power
        d = amp * g * np.sin(phase - 2 * math.pi * s / wavelength)
        return X + d * uy, Y - d * ux
    return f


def squash(y0, y1, dy):
    """y0 以上整塊移 dy 格，y0 到 y1 之間漸漸歸零（中間會多一列或少一列），y1 以下不動。呼吸用。"""
    def f(X, Y):
        w = np.clip((y1 - Y) / float(y1 - y0), 0, 1)
        return X, Y - dy * w
    return f


def lean(pivot, deg, length):
    """腳不動，越往上斜得越多。重心移動、出招時身體跟著帶。"""
    def f(X, Y):
        a = np.radians(deg) * np.clip((pivot[1] - Y) / length, 0, 1)
        return X - np.tan(a) * (pivot[1] - Y), Y
    return f


# ---------- 柔性變形 ----------
# 不切零件，直接在合成好的畫面上推：每個區域有一張 0 到 1 的權重圖，邊緣漸漸歸零，所以不會有接縫。
# 背景複雜、切不乾淨的東西（飄帶、長髮、雲、破掉的衣角）用這個。回傳的是「這一格每個位置要往哪裡推幾格」。
def feather(mask, r=3):
    w = mask.astype(np.float32)
    for _ in range(2):
        for ax in (0, 1):
            acc = np.zeros_like(w)
            for d in range(-r, r + 1):
                s = np.roll(w, d, axis=ax)
                if ax == 0:
                    if d > 0: s[:d, :] = 0
                    if d < 0: s[d:, :] = 0
                else:
                    if d > 0: s[:, :d] = 0
                    if d < 0: s[:, d:] = 0
                acc += s
            w = acc / (2 * r + 1)
    return w


def f_shift(W, dx, dy):
    return W * dx, W * dy


def f_squash(W, y0, y1, dy):
    return W * 0, W * dy * np.clip((y1 - YS) / float(y1 - y0), 0, 1)


def f_wave(W, along, amp, wavelength, phase, origin=(0, 0)):
    ux, uy = math.cos(math.radians(along)), math.sin(math.radians(along))
    s = (XS - origin[0]) * ux + (YS - origin[1]) * uy
    d = W * amp * np.sin(phase - 2 * math.pi * s / wavelength)
    return -d * uy, d * ux


def f_bend(W, pivot, deg, length, power=1.0):
    dx, dy = XS - pivot[0], YS - pivot[1]
    a = np.radians(deg) * np.clip(np.hypot(dx, dy) / length, 0, 1) ** power
    c, s = np.cos(a), np.sin(a)
    return W * (c * dx - s * dy - dx), W * (s * dx + c * dy - dy)


def f_lean(W, pivot, deg, length):
    h = np.clip(pivot[1] - YS, 0, None)
    a = np.radians(deg) * np.clip(h / length, 0, 1)
    return W * np.tan(a) * h, W * 0


# ---------- 時間 ----------
def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def keys(f, pts):
    """關鍵格內插。pts 是 [(格, 值), ...]，格要遞增；頭尾以外用最近的值。兩個關鍵格之間用緩入緩出。"""
    if f <= pts[0][0]:
        return pts[0][1]
    for (f0, v0), (f1, v1) in zip(pts, pts[1:]):
        if f <= f1:
            return v0 + (v1 - v0) * ease((f - f0) / float(f1 - f0))
    return pts[-1][1]


def cyc(f, period, phase=0.0):
    return math.sin(2 * math.pi * (f / float(period) + phase))


def ring(f, start, amp, period, decay, soft=False):
    """從 start 那一格開始的餘震：一邊擺一邊變小。出招之後葉子、袖子的回彈。
    soft=True 是從零開始盪出去（被帶動的東西），False 是一開始就在最大（被打到的東西）。"""
    t = f - start
    if t < 0:
        return 0.0
    w = 2 * math.pi * t / float(period)
    return amp * math.exp(-t / float(decay)) * (math.sin(w) if soft else math.cos(w))


def breath(f, period=24, up=(4, 14)):
    """呼吸：一個週期裡有一段是吸氣（回傳 1），其餘是 0。"""
    return 1 if up[0] <= (f % period) < up[1] else 0


# ---------- 姿勢（照像素 B-roll 的 motion.js：預備、出手、回彈，一拍一拍地演）----------
# 姿勢是 {dx, dy, sq, ln}：dx、dy 是整個人的位移，sq 正的是壓扁（頭往下沉）、負的是拉長，ln 是身體傾斜幾度。
# 單位不是格，是「一份」，畫的時候再乘上 U 格。壓扁是把身體中段壓短，頭和臉不變形。
U = 3


def pose(dx=0.0, dy=0.0, sq=0.0, ln=0.0):
    return {'dx': dx, 'dy': dy, 'sq': sq, 'ln': ln}


def padd(*ps):
    out = pose()
    for p in ps:
        for k in out:
            out[k] += p.get(k, 0)
    return out


def seq(f, a, vals):
    """從第 a 格開始，一格一個值；範圍外是 0。"""
    i = f - a
    return vals[i] if 0 <= i < len(vals) else 0


def breathe(f, beat=8, ramp=3):
    """呼吸：一拍吸（往上拉長 1 份）、一拍吐，吸和吐各花 ramp 格。回傳 0 到 1。"""
    g = f % (2 * beat)
    if g < beat:
        return min(1.0, (g + 1) / float(ramp))
    return max(0.0, 1.0 - (g - beat + 1) / float(ramp))


def follow(val, f, k=0.35, w=1.3, span=18):
    """被帶著動的東西（葉子、頭髮、流蘇、水桶）：把 val 每一格的變化當成推了一下，各自盪幾下再停。
    val 要是以 N 為週期的函式。回傳值的單位跟 val 一樣。"""
    s = 0.0
    for j in range(span):
        v = val(f - j) - val(f - j - 1)
        if v:
            s += v * math.exp(-k * j) * math.cos(w * j)
    return s


def f_flap(W, pivot, amount, length, power=1.5):
    """葉子兩邊的尖端一起往下垂（amount 正）或往上翹（負），越靠外動越多。"""
    return W * 0, W * amount * np.clip(np.abs(XS - pivot[0]) / float(length), 0, 1) ** power


# ---------- 骨架 ----------
class Part:
    def __init__(self, name, mask, move=None, parent=None):
        self.name, self.mask, self.move, self.parent = name, mask, move, parent
        self.tex = None

    def chain(self, f):
        own = self.move(f) if self.move else []
        return (self.parent.chain(f) if self.parent else []) + list(own)


class Rig:
    def __init__(self, base):
        self.base = base
        self.parts = []
        self.back = []      # 畫在角色後面的特效 fn(畫面, 格)
        self.front = []     # 畫在最上面的特效
        self.post = []      # 整張的處理（閃白、震動）fn(畫面, 格) -> 畫面
        self.soft = []      # 柔性變形 fn(格) -> [(DX, DY), ...]
        self.regions = {}   # 名字 -> 權重圖，只給檢查圖用
        self._blink = None  # (閉眼圖, 哪幾格閉眼)
        self._built = False

    def region(self, name, mask, r=3):
        """登記一個柔性變形的區域，回傳它的權重圖。"""
        W = feather(mask, r)
        self.regions[name] = W
        return W

    def blink(self, img, frames):
        """眨眼直接畫進動畫：frames 這幾格換成閉眼圖（跟底圖只差眼睛那一塊）。頭會大幅移動，眨眼圖沒辦法另外疊。"""
        self._blink = (img, set(frames))

    def part(self, name, mask, move=None, parent=None):
        p = Part(name, mask.copy(), move, parent)
        self.parts.append(p)
        return p

    def build(self):
        union = np.zeros((GH, GW), dtype=bool)
        for p in self.parts:
            union |= p.mask
        self.bg = inpaint(self.base, union)
        for i, p in enumerate(self.parts):
            above = np.zeros((GH, GW), dtype=bool)
            for q in self.parts[i + 1:]:
                above |= q.mask
            hole = p.mask & above
            p.tex = inpaint(self.base, hole, p.mask) if hole.any() else self.base
            p.alt = p.tex
            if self._blink:
                diff = np.abs(self._blink[0] - self.base).sum(-1) > 0
                p.alt = p.tex.copy()
                p.alt[diff & ~hole] = self._blink[0][diff & ~hole]
        self._built = True

    def frame(self, f):
        """先在原圖上做柔性變形（頭髮、葉子、布料還在原本的位置時先推好），再把零件切下來照姿勢擺。"""
        if not self._built:
            self.build()
        if self.soft:
            DX = np.zeros((GH, GW), dtype=np.float32)
            DY = np.zeros((GH, GW), dtype=np.float32)
            for fn in self.soft:
                for dx, dy in fn(f):
                    DX += dx
                    DY += dy
            wx = np.clip(np.floor(XS - DX + 0.5), 0, GW - 1).astype(int)
            wy = np.clip(np.floor(YS - DY + 0.5), 0, GH - 1).astype(int)
            warp = lambda a: a[wy, wx]
        else:
            warp = lambda a: a
        out = warp(self.bg).copy()
        for fx in self.back:
            fx(out, f)
        closed = bool(self._blink) and (f % N) in self._blink[1]
        for p in self.parts:
            mask, tex = warp(p.mask), warp(p.alt if closed else p.tex)
            X, Y = XS, YS
            for tr in p.chain(f):
                X, Y = tr(X, Y)
            sx, sy = np.floor(X + 0.5).astype(int), np.floor(Y + 0.5).astype(int)
            ok = (sx >= 0) & (sx < GW) & (sy >= 0) & (sy < GH)
            m = np.zeros((GH, GW), dtype=bool)
            m[ok] = mask[sy[ok], sx[ok]]
            out[m] = tex[sy[m], sx[m]]
        for fx in self.front:
            fx(out, f)
        for fx in self.post:
            out = fx(out, f)
        return out

    def frames(self):
        return [self.frame(f) for f in range(N)]

    def debug(self, path, marks=()):
        """把每個零件的遮罩塗上不同顏色、放大四倍存圖，檢查切得對不對。"""
        tint = [(255, 0, 0), (0, 120, 255), (0, 200, 0), (255, 0, 255), (255, 140, 0), (0, 220, 220), (140, 0, 255), (120, 120, 0),
                (255, 90, 160), (0, 90, 90)]
        img = self.base.copy()
        for i, p in enumerate(self.parts):
            c = np.array(tint[i % len(tint)], dtype=np.float32)
            img[p.mask] = img[p.mask] * 0.45 + c * 0.55
        for W in self.regions.values():
            inside = W > 0.5
            edge = inside & ~shrink(inside, 1)
            img[edge] = (0, 0, 0)
        S = 4
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((GW * S, GH * S), Image.NEAREST)
        d = ImageDraw.Draw(im)
        for x in range(0, GW, 20):
            d.line([(x * S, 0), (x * S, GH * S)], fill=(0, 0, 0))
            d.text((x * S + 2, 1), str(x), fill=(0, 0, 0))
        for y in range(0, GH, 20):
            d.line([(0, y * S), (GW * S, y * S)], fill=(0, 0, 0))
            d.text((1, y * S + 1), str(y), fill=(0, 0, 0))
        for (x, y) in marks:
            d.line([(x * S - 6, y * S), (x * S + 6, y * S)], fill=(255, 255, 255), width=3)
            d.line([(x * S, y * S - 6), (x * S, y * S + 6)], fill=(255, 255, 255), width=3)
            d.line([(x * S - 5, y * S), (x * S + 5, y * S)], fill=(0, 0, 0), width=1)
            d.line([(x * S, y * S - 5), (x * S, y * S + 5)], fill=(0, 0, 0), width=1)
        for name, W in self.regions.items():
            ys, xs = np.where(W > 0.5)
            if len(xs):
                d.text((xs.min() * S + 3, ys.min() * S + 2), name, fill=(0, 0, 0))
        for i, p in enumerate(self.parts):
            d.rectangle([2, GH * S - 14 * (i + 1) - 2, 120, GH * S - 14 * i - 2], fill=tint[i % len(tint)])
            d.text((4, GH * S - 14 * (i + 1) - 1), p.name, fill=(255, 255, 255))
        im.save(path)


# ---------- 畫上去的特效 ----------
def dot(rgb, x, y, col, a=1.0):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < GW and 0 <= y < GH and a > 0:
        a = min(1.0, a)
        rgb[y, x] = rgb[y, x] * (1 - a) + col * a


def plus(rgb, x, y, col, a=1.0):
    for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
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


def glow(rgb, cx, cy, r, amt, col, only=None):
    w = np.clip(1 - np.hypot(XS - cx, YS - cy) / r, 0, 1) ** 2 * amt
    if only is not None:
        w = w * only
    rgb[:] = rgb * (1 - w[..., None]) + col * w[..., None]
