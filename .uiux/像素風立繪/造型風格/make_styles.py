"""把 168x210 像素立繪轉成多種付費造型風格（試做，給畫布看）。"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

# 水彩典藏 2026-11-18 多米決定拿掉（水彩圖做不了動畫），所以不再讀水彩原圖
AIMASK = Path(__file__).parent / "aimask"
SRC = None                       # 統一色盤資料夾，main() 從命令列設定；別的程式 import 時自己傳 src 給 load()


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


def load(code, src=None):
    im = Image.open(Path(src or SRC) / f"{code}_168x210.png").convert("RGB")
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


def style_sticker(rgb, mask, bgc="#F2E6CC", dot="#E6D6B4", wrap_shadow=True):
    """wrap_shadow：陰影用 np.roll 往右下推，角色碰到右邊界的（r2–r6、gr3、gr5、gr6）會從左邊界繞出一條三格寬的陰影。
    靜態圖已經是這樣（預設 True 不變）；動畫傳 False，不然那條會跟著呼吸上下跳（2026-11-18 組塊 M2 發現）。"""
    h, w = mask.shape
    m = Image.fromarray((mask * 255).astype(np.uint8))
    white = np.asarray(m.filter(ImageFilter.MaxFilter(7))) > 127
    dark = np.asarray(m.filter(ImageFilter.MaxFilter(9))) > 127
    if wrap_shadow:
        shadow = np.roll(np.roll(dark, 4, axis=0), 3, axis=1)
    else:
        shadow = np.zeros_like(dark)
        shadow[4:, 3:] = dark[:-4, :-3]
    yy, xx = np.mgrid[0:h, 0:w]
    out = np.broadcast_to(hexs(bgc)[0], (h, w, 3)).copy()
    out[((yy % 8) == 0) & ((xx % 8) == 0)] = hexs(dot)[0]
    out[shadow] = hexs("#CDB78E")[0]
    out[dark] = hexs("#3A2A1C")[0]
    out[white] = hexs("#FFFDF7")[0]
    out[mask] = rgb[mask]
    return out


def chunky_small(rgb):
    """粗像素的前半段：縮成一半、拉回對比與飽和度（縮小會把線條平均掉）。"""
    im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    small = np.asarray(im.resize((84, 105), Image.BOX)).astype(np.float32)
    g = small.mean(axis=2, keepdims=True)
    return Image.fromarray(np.clip((small - g) * 1.35 + (g - 128) * 1.25 + 128, 0, 255).astype(np.uint8))


def style_chunky(rgb, mask, palette=None):
    """palette：給一張 P 模式的圖就照它的色盤收色、不抖色（動畫每格共用同一份色盤才不會閃）；沒給就每張自己挑 20 色。"""
    small = chunky_small(rgb)
    if palette is None:
        q = small.quantize(colors=20, method=Image.Quantize.MEDIANCUT)
    else:
        q = small.quantize(palette=palette, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB").resize((168, 210), Image.NEAREST)).astype(np.float32)


def style_celadon(rgb, mask):
    """青花瓷：白瓷底、角色只剩鈷藍一色，底下一條格紋像瓷盤的邊。"""
    from scipy import ndimage
    # 角色內部的小縫補起來，背景色才不會從袖子裡透出來
    mask = ndimage.binary_fill_holes(mask)
    l = lum(rgb)
    char = posterize_map(l, hexs("#0E1E4E", "#1F3B86", "#3A63B8", "#7F9FD6", "#C9D7F0", "#F4F7FC"))
    bg = posterize_map(l, hexs("#DCE3EE", "#E8EDF4", "#F1F4F9", "#F8FAFC"))
    out = np.where(mask[..., None], char, bg)
    h, w = mask.shape
    yy, xx = np.mgrid[0:h, 0:w]
    band = (yy >= h - 14) & (yy < h - 4) & ~mask
    out[band] = hexs("#C9D7F0")[0]
    out[band & ((xx // 4 + yy // 4) % 2 == 0)] = hexs("#3A63B8")[0]
    return out


def style_sunset(rgb, mask):
    """赤霞夕照：上紫下橘一層層的晚霞、一條金色地平線，角色染暖色、外緣描金光。"""
    from scipy import ndimage
    mask = ndimage.binary_fill_holes(mask)
    h, w = mask.shape
    yy = np.mgrid[0:h, 0:w][0] / h
    sky = posterize_map(1 - yy, hexs("#F3A25A", "#E3735A", "#B9506E", "#7E3A7A", "#4A2A66", "#2A1B4A"))
    sky[(yy > 0.80) & (yy < 0.83)] = hexs("#FFD27A")[0]
    l = lum(rgb)
    char = posterize_map(l, hexs("#1E0E1E", "#4A1E30", "#83344A", "#C25E4E", "#EE9A5E", "#FFD9A0"))
    out = np.where(mask[..., None], char, sky)
    edge = mask & ~ndimage.binary_erosion(mask, border_value=0)
    out[edge] = out[edge] * 0.3 + hexs("#FFD27A")[0] * 0.7
    return out


def style_neon(rgb, mask):
    """霓虹：暗底、角色紫粉，外面一圈青色亮邊。"""
    from scipy import ndimage
    mask = ndimage.binary_fill_holes(mask)
    # 亮邊沿「封口後」的外形描：袖子和衣襬之間那條通到外面的細縫不描，不然袖子裡會多一條青線
    # 補 | mask：角色碰到圖邊時，closing 會把邊上那排削掉，亮邊就會蓋到角色身上
    solid = ndimage.binary_fill_holes(ndimage.binary_closing(mask, iterations=2) | mask)
    l = lum(rgb)
    bg = posterize_map(l, hexs("#07040F", "#0E0820", "#160C30"))
    char = posterize_map(l, hexs("#120A24", "#2C1650", "#5A2A8A", "#9A4AC8", "#E07AE8", "#FFD6FA"))
    out = np.where(mask[..., None], char, bg)
    # 亮邊圈住的縫（髮帶之間、法杖和袍子之間）用最深的紫，留黑底看起來像角色破洞
    out[solid & ~mask] = hexs("#2C1650")[0]
    ring = ndimage.binary_dilation(solid, iterations=2) & ~solid
    glow = ndimage.binary_dilation(solid, iterations=4) & ~solid & ~ring
    out[glow] = hexs("#0E3A4A")[0]
    out[ring] = hexs("#3FF2FF")[0]
    return out


def style_jade(rgb, mask):
    """翠玉：整隻像綠玉雕的，深紅褐絨布底，頭上紅果換成金色像鑲金。"""
    from scipy import ndimage
    mask = ndimage.binary_fill_holes(mask)
    l = lum(rgb)
    char = posterize_map(l ** 0.85, hexs("#0D2A1F", "#1C4D36", "#2E7A55", "#4FA67A", "#8FD1A8", "#DDF5E4"))
    bg = posterize_map(l, hexs("#1A1014", "#2A1920", "#3A222B", "#4B2C36"))
    out = np.where(mask[..., None], char, bg)
    out[reds(rgb) & mask] = hexs("#C9A24A")[0]
    return out


STYLES = {
    "ink": style_ink, "gold": style_gold, "moon": style_moon, "puppet": style_puppet,
    "handheld": style_handheld, "sticker": style_sticker, "chunky": style_chunky,
    # 2026-11-18 多米從五個候選挑了這三種，再加翠玉湊滿選造型頁十二格（原版加十一種）
    "celadon": style_celadon, "sunset": style_sunset, "neon": style_neon, "jade": style_jade,
}


def save(arr, path):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(path)


def main():
    global SRC
    SRC = Path(sys.argv[1])          # 統一色盤資料夾
    OUT = Path(sys.argv[2])
    OUT.mkdir(parents=True, exist_ok=True)

    # 一、金丹男、金丹女各八種（原版加七種付費）
    for code in ("r2", "gr2"):
        rgb, mask = load(code, SRC)
        save(rgb, OUT / f"{code}_original.png")
        for name, fn in STYLES.items():
            save(fn(rgb, mask), OUT / f"{code}_{name}.png")

    # 二、每種風格七境界一排，男 sheet_{風格}.png、女 sheet_{風格}_f.png，1 倍、間隔 12
    GAP = 12
    for prefix, suffix in (("r", ""), ("gr", "_f")):
        codes = [f"{prefix}{i}" for i in range(7)]
        for name in ["original", *STYLES]:
            sheet = Image.new("RGBA", (168 * 7 + GAP * 6, 210), (0, 0, 0, 0))
            for i, c in enumerate(codes):
                rgb, mask = load(c, SRC)
                arr = rgb if name == "original" else STYLES[name](rgb, mask)
                sheet.paste(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), (i * (168 + GAP), 0))
            sheet.save(OUT / f"sheet_{name}{suffix}.png")

    # 三、app 用的單張：男女十四張 × 每種付費風格，檔名 {境界代碼}-{風格}.png（2026-11-18 組塊 M1）
    APP = OUT / "app"
    APP.mkdir(exist_ok=True)
    for prefix in ("r", "gr"):
        for i in range(7):
            code = f"{prefix}{i}"
            rgb, mask = load(code, SRC)
            for name, fn in STYLES.items():
                save(fn(rgb, mask), APP / f"{code}-{name}.png")

    # 四、動畫相容性檢查：鎏金套在動畫格子圖上（換色系風格整張套即可）
    anim = Image.open(SRC / "r2_anim96.png").convert("RGB")
    print("anim size", anim.size)
    print("done", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
