"""用 rembg（AI 去背）重做 168×210 角色範圍，取代 matte.py 的 GrabCut 版。

GrabCut 分不出白袍、淡金袍和後面的雲（多米 2026-11-18 抓到元嬰左手、大乘袍角、煉氣男手臂旁的天空）。
在水彩原圖上去背，裁切跟 pixelate2.py 一樣置中 4:5，再縮成 168×210。

兩個模型各有錯，逐張放大看過後照 CHOICE 挑：
- birefnet-general：大多數最準；但金丹男手上的金丹會被切掉、化神女背後的月亮會被算進角色
- isnet-general-use：渡劫男女被暴風雲騙（葉子、衣服切掉），但金丹男、化神男是對的
- moon：化神女專用，兩個聯集再照顏色扣掉月亮（見 moon_mask）

用法：python ai_matte.py <水彩原圖資料夾> <輸出資料夾> [代號,代號…]
輸出：{代號}_168x210_aimask.png（白＝角色）
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from rembg import new_session, remove
from scipy import ndimage

GW, GH = 168, 210
ALPHA_KEEP = 0.5  # 縮小後一格裡超過一半是角色才算角色
BIREF, ISNET = "birefnet-general", "isnet-general-use"
CHOICE = {"r2": ISNET, "r4": ISNET, "gr4": "moon"}  # 沒列的用 BIREF
# 模型多拿進來的背景，逐張看過指定位置（x0, y0, x1, y1，168×210 格）：
# 元嬰女法杖右上的兩團雲（原本用兩模型交集去掉，結果連袖子一起扣掉，多米 2026-11-18 抓到）
# 法杖頭右半到 x 149、y 78，框不能碰到，分兩塊框雲
DROP_BOX = {"gr3": [(150, 58, 168, 92), (143, 80, 168, 110), (138, 88, 143, 100)]}  # 右、下邊界不含
PIXEL_DIR = Path(__file__).resolve().parent.parent / "統一色盤"
MIN_PIECE = 8  # 比這小的離群碎點當灰塵；金丹（約 110 格）、飄帶末端（17 格）都比它大

src_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
codes = sys.argv[3].split(",") if len(sys.argv) > 3 else [f"{s}{i}" for s in ("r", "gr") for i in range(7)]
out_dir.mkdir(parents=True, exist_ok=True)
sessions = {}


def crop45(im):
    w, h = im.size
    if w / h > GW / GH:
        nw = int(round(h * GW / GH))
        x0 = (w - nw) // 2
        return im.crop((x0, 0, x0 + nw, h))
    nh = int(round(w * GH / GW))
    y0 = (h - nh) // 2
    return im.crop((0, y0, w, y0 + nh))


def small_mask(im, model):
    if model not in sessions:
        sessions[model] = new_session(model)
    alpha = remove(im, session=sessions[model], only_mask=True)
    small = np.asarray(alpha.resize((GW, GH), Image.BOX)).astype(np.float32) / 255.0
    return small >= ALPHA_KEEP


def moon_mask(im, code):
    """化神女：isnet 把半透明飄帶切成細條，BiRefNet 飄帶完整但把背後的月亮也拿進來。
    兩個取聯集，再照像素圖的顏色扣掉月亮：深藍的月面（上半段），和葉子周圍淡紫到白的月亮外光（頭部以外的上段）。"""
    mask = small_mask(im, BIREF) | small_mask(im, ISNET)
    px = np.asarray(Image.open(PIXEL_DIR / f"{code}_168x210.png").convert("RGB")).astype(np.float32)
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    ys, xs = np.mgrid[0:GH, 0:GW]
    moon_face = (b - r > 45) & (lum < 175) & (ys < 112)
    moon_glow = (((b > g + 8) & (b >= r - 5)) | (px.min(-1) > 240)) & (ys < 48)
    head = (xs >= 55) & (xs <= 100) & (ys >= 25)      # 頭上的花、髮飾也是白和淡紫，留著
    mask &= ~moon_face & ~(moon_glow & ~head)
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    return mask & np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= MOON_MIN_PIECE])


MOON_MIN_PIECE = 30  # 扣掉月亮外光後留下的零星碎點


for code in codes:
    found = [src_dir / f"{code}{ext}" for ext in (".webp", ".png") if (src_dir / f"{code}{ext}").exists()]
    if not found:
        raise FileNotFoundError(src_dir / code)
    im = crop45(Image.open(found[0]).convert("RGB"))
    choice = CHOICE.get(code, BIREF)
    if choice == "moon":
        mask = moon_mask(im, code)
    else:
        mask = small_mask(im, choice)
    for x0, y0, x1, y1 in DROP_BOX.get(code, []):
        mask[y0:y1, x0:x1] = False
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    mask &= np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= MIN_PIECE])
    Image.fromarray((mask * 255).astype(np.uint8)).save(out_dir / f"{code}_168x210_aimask.png")
    print(code, choice, int(mask.sum()))
