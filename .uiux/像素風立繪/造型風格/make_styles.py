"""把 168x210 像素立繪轉成多種付費造型風格（試做，給畫布看）。"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

SRC = Path(sys.argv[1])          # 統一色盤資料夾
WATER = Path(sys.argv[2])        # img 資料夾（水彩原圖）
OUT = Path(sys.argv[3])
AIMASK = Path(__file__).parent / "aimask"
OUT.mkdir(parents=True, exist_ok=True)


def hexs(*hs):
    return np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in hs], dtype=np.float32)


def lum(rgb):
    return (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0


def gradmap(l, stops):
    """luminance 0..1 → 平滑插值的色帶。"""
    n = len(stops) - 1
    x = np.clip(l, 0, 1) * n
    i = np.clip(np.floor(x).astype(int), 0, n - 1)
    t = (x - i)[..., None]
    return stops[i] * (1 - t) + stops[i + 1] * t


def posterize_map(l, stops):
    """luminance → 分級（不插值），保持像素感。"""
    n = len(stops)
    i = np.clip((l * n).astype(int), 0, n - 1)
    return stops[i]


def load(code):
    im = Image.open(SRC / f"{code}_168x210.png").convert("RGB")
    rgb = np.asarray(im).astype(np.float32)
    # 角色範圍改用 ai_matte.py 的 AI 去背（2026-11-18）；GrabCut 版分不出白袍和雲，補規則越補越壞
    m = Image.open(AIMASK / f"{code}_168x210_aimask.png").convert("L")
    return rgb, np.asarray(m) > 127


def reds(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r > 150) & (g < 95) & (b < 85) & (r > g * 1.9)


def style_ink(rgb, mask):
    l = lum(rgb)
    char = posterize_map(l, hexs("#1E1B18", "#3F3A35", "#6E675F", "#A39C91", "#DAD3C6"))
    bg = posterize_map(l, hexs("#BDB4A3", "#D3CBBC", "#E4DED2", "#F1ECE2"))
    out = np.where(mask[..., None], char, bg)
    out[reds(rgb) & mask] = hexs("#B23A2A")[0]
    return out


def style_gold(rgb, mask):
    l = lum(rgb)
    char = posterize_map(l ** 0.9, hexs("#2A1606", "#5C3810", "#93601C", "#C9922E", "#EBC35A", "#FFF0B8"))
    bg = posterize_map(l, hexs("#120B05", "#24170A", "#3A2610", "#553918"))
    return np.where(mask[..., None], char, bg)


def style_moon(rgb, mask, seed=7):
    l = lum(rgb)
    bg = posterize_map(l, hexs("#05081A", "#0B1334", "#15214E", "#22336E", "#3A4F8E"))
    rng = np.random.default_rng(seed)
    stars = (rng.random(l.shape) > 0.985) & ~mask
    bg[stars] = hexs("#E8EEFF")[0]
    char = rgb * np.array([0.72, 0.80, 1.02]) + np.array([4, 8, 26])
    # 月光邊：角色左上緣提亮
    # 只描外輪廓：用補洞後的範圍算，手和水桶之間的小縫才不會被描成白邊（煉氣男的手）
    from scipy import ndimage
    outer = ndimage.binary_fill_holes(mask)
    edge = mask & (~np.roll(outer, 1, axis=1) | ~np.roll(outer, 1, axis=0))
    char[edge] = char[edge] * 0.4 + hexs("#DDE6FF")[0] * 0.6
    return np.where(mask[..., None], np.clip(char, 0, 255), bg)


def style_puppet(rgb, mask):
    h, w = mask.shape
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w * 0.5) / w) ** 2 + ((yy - h * 0.42) / h) ** 2)
    glow = posterize_map(1 - np.clip(d * 1.6, 0, 1), hexs("#2B1007", "#51200C", "#7E3612", "#B0561C", "#D9822C", "#F0A845"))
    l = lum(rgb)
    char = posterize_map(l, hexs("#1C0804", "#5A1A0C", "#8E2A14", "#BC4722", "#DE7A3C", "#F3B36A"))
    return np.where(mask[..., None], char, glow)


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def style_handheld(rgb, mask):
    l = lum(rgb)
    h, w = l.shape
    dither = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] * 0.22
    return posterize_map(np.clip(l + dither, 0, 0.999), hexs("#1B2A1A", "#3C6233", "#87A84D", "#CFE09A"))


def style_sticker(rgb, mask, bgc="#F2E6CC", dot="#E6D6B4"):
    h, w = mask.shape
    m = Image.fromarray((mask * 255).astype(np.uint8))
    white = np.asarray(m.filter(ImageFilter.MaxFilter(7))) > 127
    dark = np.asarray(m.filter(ImageFilter.MaxFilter(9))) > 127
    shadow = np.roll(np.roll(dark, 4, axis=0), 3, axis=1)
    yy, xx = np.mgrid[0:h, 0:w]
    out = np.broadcast_to(hexs(bgc)[0], (h, w, 3)).copy()
    out[((yy % 8) == 0) & ((xx % 8) == 0)] = hexs(dot)[0]
    out[shadow] = hexs("#CDB78E")[0]
    out[dark] = hexs("#3A2A1C")[0]
    out[white] = hexs("#FFFDF7")[0]
    out[mask] = rgb[mask]
    return out


def style_chunky(rgb, mask):
    im = Image.fromarray(rgb.astype(np.uint8))
    small = np.asarray(im.resize((84, 105), Image.BOX)).astype(np.float32)
    # 縮小會把線條平均掉，拉回對比與飽和度
    g = small.mean(axis=2, keepdims=True)
    small = np.clip((small - g) * 1.35 + (g - 128) * 1.25 + 128, 0, 255).astype(np.uint8)
    q = Image.fromarray(small).quantize(colors=20, method=Image.Quantize.MEDIANCUT).convert("RGB")
    return np.asarray(q.resize((168, 210), Image.NEAREST)).astype(np.float32)


STYLES = {
    "ink": style_ink, "gold": style_gold, "moon": style_moon, "puppet": style_puppet,
    "handheld": style_handheld, "sticker": style_sticker, "chunky": style_chunky,
}


def watercolor(code, size=(168, 210)):
    im = Image.open(WATER / f"{code}.webp").convert("RGB")
    w, h = im.size
    tw = int(h * 4 / 5)
    if tw <= w:
        left = (w - tw) // 2
        im = im.crop((left, 0, left + tw, h))
    else:
        th = int(w * 5 / 4)
        im = im.crop((0, 0, w, th))
    return im.resize(size, Image.LANCZOS)


def save(arr, path):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(path)


# 一、金丹男九種
rgb, mask = load("r2")
save(rgb, OUT / "r2_original.png")
for name, fn in STYLES.items():
    save(fn(rgb, mask), OUT / f"r2_{name}.png")
watercolor("r2", (336, 420)).save(OUT / "r2_watercolor.png")

# 二、每種風格七境界一排（男），1 倍、間隔 12
GAP = 12
codes = [f"r{i}" for i in range(7)]
for name in ["original", "watercolor", *STYLES]:
    sheet = Image.new("RGBA", (168 * 7 + GAP * 6, 210), (0, 0, 0, 0))
    for i, c in enumerate(codes):
        if name == "watercolor":
            tile = watercolor(c)
        else:
            rgb, mask = load(c)
            arr = rgb if name == "original" else STYLES[name](rgb, mask)
            tile = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        sheet.paste(tile, (i * (168 + GAP), 0))
    sheet.save(OUT / f"sheet_{name}.png")

# 三、動畫相容性檢查：鎏金套在動畫格子圖上（換色系風格整張套即可）
anim = Image.open(SRC / "r2_anim96.png").convert("RGB")
print("anim size", anim.size)
print("done", sorted(p.name for p in OUT.iterdir()))
