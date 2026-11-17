"""用 rembg（AI 去背）重做 168×210 角色範圍，取代 matte.py 的 GrabCut 版。

GrabCut 分不出白袍、淡金袍和後面的雲（多米 2026-11-18 抓到元嬰左手、大乘袍角、煉氣男手臂旁的天空）。
在水彩原圖上去背，裁切跟 pixelate2.py 一樣置中 4:5，再縮成 168×210。

兩個模型各有錯，逐張放大看過後照 CHOICE 挑：
- birefnet-general：大多數最準；但金丹男手上的金丹會被切掉、化神女背後的月亮會被算進角色
- isnet-general-use：渡劫男女被暴風雲騙（葉子、衣服切掉），但金丹、化神那幾張是對的
- and：兩個都說是角色才算（元嬰女右邊的雲只有一邊會拿）

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
CHOICE = {"r2": ISNET, "r4": ISNET, "gr4": ISNET, "gr3": "and"}  # 沒列的用 BIREF
# 兩個模型都拿進來的背景碎片，逐張看過指定位置（x0, y0, x1, y1，168×210 格）：元嬰女右緣那一條雲
DROP_BOX = {"gr3": [(140, 110, 168, 136)]}
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


for code in codes:
    found = [src_dir / f"{code}{ext}" for ext in (".webp", ".png") if (src_dir / f"{code}{ext}").exists()]
    if not found:
        raise FileNotFoundError(src_dir / code)
    im = crop45(Image.open(found[0]).convert("RGB"))
    choice = CHOICE.get(code, BIREF)
    if choice == "and":
        mask = small_mask(im, BIREF) & small_mask(im, ISNET)
    else:
        mask = small_mask(im, choice)
    for x0, y0, x1, y1 in DROP_BOX.get(code, []):
        mask[y0:y1, x0:x1] = False
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    mask &= np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= MIN_PIECE])
    Image.fromarray((mask * 255).astype(np.uint8)).save(out_dir / f"{code}_168x210_aimask.png")
    print(code, choice, int(mask.sum()))
