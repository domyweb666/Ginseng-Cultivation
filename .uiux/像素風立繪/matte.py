"""把 14 張立繪的角色從背景切出來，存成跟像素圖同樣格數的遮罩（白 = 角色）。

動畫要分三層疊（背景一層、角色一層、特效一層），角色移動時背景才不會跟著動，所以要先知道哪些格子是角色。
做法：在水彩原圖上用 GrabCut。每張給一個粗略的輪廓（OUTLINE，圈住整個人含衣服飄帶道具，不用準），
輪廓外一定是背景、頭和軀幹中間一定是角色，其餘讓它照顏色分。分錯的地方用 FG、BG 補幾塊「這裡一定是／一定不是」。
座標都是 168x210 的格子座標。

用法：python matte.py <Portraits 資料夾> <統一色盤資料夾> [檢查圖資料夾] [只做哪幾張]
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

from rig import GW, GH, poly, box, grow, shrink, leafy, close

NAMES = ['r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'gr0', 'gr1', 'gr2', 'gr3', 'gr4', 'gr5', 'gr6']
# 頭和軀幹的中間：一定是角色
CORE = [(74, 38), (96, 38), (102, 60), (104, 84), (108, 100), (110, 134), (62, 134), (60, 100), (64, 84), (66, 60)]
OUTLINE = {
    'r0': [(60, 0), (110, 0), (140, 20), (140, 62), (118, 62), (130, 88), (130, 112), (148, 130), (148, 184), (104, 184), (112, 200), (40, 200),
           (40, 162), (44, 130), (34, 120), (32, 60), (26, 60), (26, 20)],
    'gr0': [(60, 0), (110, 0), (140, 20), (140, 60), (120, 60), (134, 90), (134, 112), (148, 130), (148, 184), (106, 184), (112, 200), (40, 200),
            (40, 166), (30, 150), (30, 60), (26, 60), (26, 20)],
    'r1': [(58, 0), (110, 0), (140, 20), (140, 36), (160, 34), (160, 50), (140, 90), (128, 112), (132, 146), (132, 166), (126, 200), (30, 200),
           (30, 166), (24, 148), (24, 128), (40, 118), (32, 112), (30, 60), (24, 60), (24, 20)],
    'gr1': [(58, 0), (110, 0), (140, 20), (140, 36), (160, 34), (160, 50), (140, 90), (130, 112), (134, 148), (134, 168), (126, 200), (28, 200),
            (30, 168), (26, 148), (26, 130), (34, 120), (30, 112), (30, 60), (24, 60), (24, 20)],
    'r2': [(56, 0), (108, 0), (134, 16), (134, 44), (150, 44), (158, 60), (158, 84), (168, 100), (168, 158), (120, 160), (114, 192), (42, 192),
           (40, 160), (0, 158), (0, 112), (24, 96), (28, 60), (20, 58), (20, 16)],
    'gr2': [(52, 0), (108, 0), (134, 16), (134, 46), (152, 46), (160, 62), (160, 86), (168, 100), (168, 162), (120, 164), (116, 192), (42, 192),
            (40, 164), (0, 160), (0, 110), (18, 96), (20, 70), (36, 48), (20, 50), (20, 16)],
    'r3': [(78, 0), (98, 0), (132, 12), (134, 34), (164, 36), (166, 100), (168, 120), (168, 160), (150, 170), (150, 196), (112, 200), (56, 200),
           (52, 172), (20, 168), (0, 150), (0, 118), (18, 100), (22, 84), (30, 76), (28, 58), (50, 50), (34, 40), (36, 12)],
    'gr3': [(78, 0), (98, 0), (128, 12), (130, 34), (164, 36), (166, 100), (168, 118), (168, 162), (150, 172), (150, 196), (112, 200), (56, 200),
            (52, 174), (20, 170), (0, 154), (0, 112), (22, 98), (28, 84), (26, 60), (40, 44), (32, 36), (34, 12)],
    'r4': [(70, 0), (96, 0), (120, 14), (118, 40), (108, 46), (168, 50), (168, 158), (120, 160), (104, 170), (100, 190), (64, 190), (56, 170),
           (24, 160), (0, 150), (0, 48), (60, 48), (28, 36), (30, 12)],
    'gr4': [(72, 0), (96, 0), (118, 14), (116, 40), (108, 44), (168, 50), (168, 160), (120, 162), (106, 170), (102, 188), (64, 188), (56, 170),
            (24, 165), (0, 150), (0, 48), (56, 44), (34, 36), (36, 12)],
    'r5': [(70, 0), (100, 0), (126, 14), (126, 44), (110, 50), (168, 50), (168, 150), (140, 165), (112, 170), (106, 196), (58, 196), (52, 170),
           (20, 160), (0, 145), (0, 55), (56, 50), (44, 44), (44, 14)],
    'gr5': [(70, 0), (100, 0), (122, 14), (122, 44), (112, 50), (168, 50), (168, 150), (140, 168), (112, 172), (106, 194), (58, 194), (52, 172),
            (20, 165), (0, 150), (0, 60), (40, 48), (40, 14)],
    'r6': [(70, 2), (100, 2), (126, 20), (124, 56), (112, 62), (120, 78), (146, 80), (168, 96), (168, 150), (140, 158), (120, 165), (118, 186),
           (44, 186), (42, 165), (15, 160), (0, 140), (0, 55), (50, 60), (30, 52), (32, 22)],
    'gr6': [(70, 2), (98, 2), (122, 20), (122, 52), (112, 58), (120, 78), (146, 80), (168, 96), (168, 150), (140, 160), (120, 168), (118, 186),
            (48, 186), (44, 168), (15, 165), (0, 150), (0, 50), (46, 46), (38, 40), (40, 18)],
}
FG = {}   # 名稱 -> [多邊形, ...]：一定是角色
BG = {    # 名稱 -> [多邊形, ...]：一定是背景
    'r2': [[(30, 188), (140, 188), (140, 210), (30, 210)]],
    'gr2': [[(30, 186), (140, 186), (140, 210), (30, 210)]],
    'r5': [[(30, 193), (140, 193), (140, 210), (30, 210)]],
    'r4': [[(0, 158), (60, 158), (64, 210), (0, 210)], [(104, 158), (168, 158), (168, 210), (100, 210)], [(60, 188), (104, 188), (104, 210), (60, 210)]],
    'gr4': [[(0, 168), (62, 160), (66, 210), (0, 210)], [(106, 160), (168, 160), (168, 210), (104, 210)], [(60, 186), (108, 186), (108, 210), (60, 210)]],
    'gr5': [[(30, 193), (140, 193), (140, 210), (30, 210)]],
    'r6': [[(30, 184), (140, 184), (140, 210), (30, 210)]],
    'gr6': [[(30, 184), (140, 184), (140, 210), (30, 210)]],
}
# 名稱 -> [(x0, y0, x1, y1), ...]：這些框裡接近白色、沒有彩度的格子一定是背景（頭旁邊被根鬚圍住的白底、腿中間的雲）
PALE_BG = {
    'r0': [(100, 40, 132, 100)], 'gr0': [(100, 40, 134, 100)], 'r1': [(104, 40, 128, 92)], 'gr1': [(104, 40, 128, 92)],
    'r2': [(100, 38, 124, 80)], 'gr2': [(100, 38, 124, 80)], 'r4': [(54, 152, 112, 192)], 'gr4': [(54, 156, 112, 190)],
}
SKY = ('r4', 'gr4')                               # 夜空的藍一定是背景
WHITE_BG = ('r0', 'gr0', 'r1', 'gr1', 'r2', 'gr2')    # 背景是白紙：跟外面連著的純白一定是背景


def load_src(folder, n):
    """跟 pixelate2.py 一樣置中裁成 4:5。"""
    im = Image.open(os.path.join(folder, n + '.imageset', n + '.png')).convert('RGB')
    w, h = im.size
    nw = int(round(h * GW / GH))
    x0 = (w - nw) // 2
    return np.asarray(im.crop((x0, 0, x0 + nw, h)))


def up(mask, shape):
    return cv2.resize(mask.astype(np.uint8), (shape[1], shape[0]), interpolation=cv2.INTER_NEAREST) > 0


def matte(src, base, n):
    outline = poly(OUTLINE[n])
    core = poly(CORE) | close(box(20, 0, 140, 60) & leafy(base), 1)
    m = np.full(src.shape[:2], cv2.GC_PR_BGD, np.uint8)
    m[up(grow(outline, 2), src.shape)] = cv2.GC_PR_FGD
    m[~up(grow(outline, 8), src.shape)] = cv2.GC_BGD
    m[up(shrink(core, 2), src.shape)] = cv2.GC_FGD
    for p in FG.get(n, []):
        m[up(poly(p), src.shape)] = cv2.GC_FGD
    for p in BG.get(n, []):
        m[up(poly(p), src.shape)] = cv2.GC_BGD
    f = src.astype(np.float32)
    for bx in PALE_BG.get(n, []):
        pale = (f.min(-1) > 198) & (f.max(-1) - f.min(-1) < 48)
        m[up(box(*bx), src.shape) & pale & (m != cv2.GC_FGD)] = cv2.GC_BGD
    if n in SKY:
        m[(f[..., 2] > f[..., 0] + 22) & (f @ np.array([0.299, 0.587, 0.114], dtype=np.float32) < 185) & (m != cv2.GC_FGD)] = cv2.GC_BGD
    if n in WHITE_BG:
        # 接近純白、而且一路連到輪廓外面的，是白紙背景（被頭和手圍住的白領子不算）
        white = ((f.min(-1) > 230) & (f.max(-1) - f.min(-1) < 18)).astype(np.uint8)
        cnt, lab = cv2.connectedComponents(white, connectivity=4)
        outside = np.unique(lab[(m == cv2.GC_BGD) & (white > 0)])
        m[np.isin(lab, outside) & (white > 0) & (m != cv2.GC_FGD)] = cv2.GC_BGD
    # 細的東西（根鬚、飄帶）GrabCut 容易漏掉，留在背景層會變成不會動的殘影。照顏色補「這裡一定是角色」：
    inside = up(outline, src.shape) & (m != cv2.GC_BGD)
    yy = np.arange(src.shape[0], dtype=np.float32)[:, None] * GH / src.shape[0] + np.zeros(src.shape[:2], np.float32)
    xx = np.arange(src.shape[1], dtype=np.float32)[None, :] * GW / src.shape[1] + np.zeros(src.shape[:2], np.float32)
    mx, mn = f.max(-1), f.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    lumi = f @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    if n in WHITE_BG:      # 白底上的人蔘黃
        hue_ok = (f[..., 0] >= f[..., 1]) & (f[..., 1] > f[..., 2]) & (f[..., 1] > 0.55 * f[..., 0])
        m[inside & hue_ok & (sat > 0.45) & (mx > 150)] = cv2.GC_FGD
    if n in SKY:           # 被夜空包住的亮東西是飄帶（周圍一大半是藍天才算，圓頂外面的白紙不算）
        sky = ((f[..., 2] > f[..., 0] + 22) & (lumi < 185)).astype(np.float32)
        around = cv2.blur(sky, (61, 61))
        m[inside & (yy > 40) & (yy < 92) & (lumi > 205) & (around > 0.5)] = cv2.GC_FGD
    if n in ('r5', 'gr5'):  # 淡金色的光裡，顏色濃的是衣服和飄帶
        m[inside & (yy < 150) & (sat > 0.5) & (lumi < 225)] = cv2.GC_FGD
    if n in ('r6', 'gr6'):  # 烏雲前面有顏色的是破掉的衣角
        m[inside & (xx < 60) & (yy < 140) & (sat > 0.35) & (lumi > 90)] = cv2.GC_FGD
        m[inside & (xx > 148) & (yy > 100) & (yy < 170) & (sat > 0.35) & (lumi > 90)] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(src, cv2.COLOR_RGB2BGR), m, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    # 只留最大的那一塊，把洞補起來的小碎片不管
    cnt, lab, stats, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    if cnt > 2:
        keep = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        big = stats[keep, cv2.CC_STAT_AREA]
        fg = np.isin(lab, [i for i in range(1, cnt) if stats[i, cv2.CC_STAT_AREA] > 0.02 * big]).astype(np.uint8)
    small = cv2.resize(fg.astype(np.float32), (GW, GH), interpolation=cv2.INTER_AREA) >= 0.5
    return fg > 0, small


def main():
    src_dir, out = sys.argv[1], sys.argv[2]
    dbg = sys.argv[3] if len(sys.argv) > 3 else None
    only = sys.argv[4].split(',') if len(sys.argv) > 4 else NAMES
    for n in only:
        src = load_src(src_dir, n)
        base = np.asarray(Image.open(os.path.join(out, '%s_%dx%d.png' % (n, GW, GH))).convert('RGB')).astype(np.float32)
        fg, small = matte(src, base, n)
        Image.fromarray((small * 255).astype(np.uint8)).save(os.path.join(out, '%s_%dx%d_mask.png' % (n, GW, GH)))
        print(n, round(float(small.mean()), 3))
        if dbg:
            S = 4
            b = np.asarray(Image.fromarray(base.astype(np.uint8)).resize((GW * S, GH * S), Image.NEAREST)).astype(np.float32)
            mk = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((GW * S, GH * S), Image.NEAREST)) > 0
            cut = b.copy()
            cut[~mk] = cut[~mk] * 0.2 + np.array([255, 0, 255]) * 0.8
            away = b.copy()
            away[mk] = away[mk] * 0.2 + np.array([0, 200, 255]) * 0.8
            Image.fromarray(np.concatenate([cut, away], 1).astype(np.uint8)).save(os.path.join(dbg, 'mt_%s.png' % n))


if __name__ == '__main__':
    main()
