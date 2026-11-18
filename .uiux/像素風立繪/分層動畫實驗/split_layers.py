"""see-through 輸出 ＋ 去背角色 → Rigby2D 要的十層。

用法：python split_layers.py <角色透明底.png> <see-through 輸出資料夾（含 topwear.png 等）> <圖層輸出資料夾> <設定.json>

see-through 對人蔘只拆得出身體（上衣、雙手、腿、木桶），頭、葉子、根鬚都會漏掉，所以：
- 身體四層用 see-through 的，看得到的地方換回原圖像素，被擋住的地方才用它補畫的。
- 原圖扣掉身體四層「看得到的部分」，剩下的照位置切成葉子、頭、左右根鬚；腿邊零碎的細根鬚歸腿。
- 閉眼那層照設定裡的眼睛框手畫（開心瞇眼的弧線）。

設定.json 要有的欄位（都是圖上座標）：
  neck_y：莖接頭頂那條線，以上全算葉子
  leaf_side_y：兩側葉尖最低到哪；這條線以上、頭寬範圍外的綠色算葉子
  head_x：[左, 右]，頭頂的寬度
  roots_split_x：左右根鬚的分界
  legs_y：這條線以下零碎的歸腿
  eyes：[[x0, y0, x1, y1], [x0, y0, x1, y1]]
  forearm：[x 最小, y 最小]，提桶那隻手袖口以下的部分（拆成 arm_R，會往上收進袖子）
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

BODY = ['topwear', 'handwear', 'legwear', 'objects']
SAME_COLOR = 90          # 跟原圖差多少以內算「同一個像素」
BROWN = (110, 62, 32, 255)


def grow(m, k):
    return np.asarray(Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.MaxFilter(k))) > 0


def shrink(m, k):
    return np.asarray(Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.MinFilter(k))) > 0


def main(char_path, st_dir, out_dir, cfg_path):
    cfg = json.load(open(cfg_path, encoding='utf-8'))
    for key in ['neck_y', 'leaf_side_y', 'head_x', 'roots_split_x', 'legs_y', 'eyes', 'forearm']:
        if key not in cfg:
            raise SystemExit(f'設定檔少了 {key}')
    os.makedirs(out_dir, exist_ok=True)
    o = np.asarray(Image.open(char_path).convert('RGBA')).astype(int)
    H, W = o.shape[:2]
    oa = o[..., 3] > 0
    Y, X = np.mgrid[0:H, 0:W]
    S = max(W, H); px, py = (S - W) // 2, (S - H) // 2   # see-through 先補成正方形再縮

    def back(n):
        p = os.path.join(st_dir, n + '.png')
        if not os.path.exists(p):
            raise SystemExit(f'找不到 see-through 的 {n}.png')
        im = Image.open(p).convert('RGBA').resize((S, S), Image.LANCZOS)
        return np.asarray(im.crop((px, py, px + W, py + H))).astype(int)

    layers, visible, seen = {}, np.zeros((H, W), bool), {}
    for n in BODY:
        l = back(n); a = l[..., 3] > 128
        same = oa & a & (np.abs(o[..., :3] - l[..., :3]).sum(-1) < SAME_COLOR)
        layers[n] = [np.where(same[..., None], o[..., :3], l[..., :3]), a]
        seen[n] = same
        visible |= same
        print(f'{n}: 面積 {a.mean() * 100:.1f}%，其中 {same.sum() / max(1, a.sum()) * 100:.0f}% 用原圖像素')

    rest = oa & ~grow(visible, 3)
    r, g = o[..., 0], o[..., 1]
    # 紅果只在莖以上認：頭輪廓的深橘也符合「紅」，在兩側被當成紅果分進葉子層，起風時會被扯走變碎點
    greenish = (g > r - 15) | ((r > 150) & (g < 110) & (Y < cfg['neck_y']))
    hx0, hx1 = cfg['head_x']
    leaf = rest & ((Y < cfg['neck_y']) | ((Y < cfg['leaf_side_y']) & ((X < hx0) | (X > hx1)) & greenish))
    leaf |= rest & shrink(grow(leaf, 11), 11)          # 葉面上的亮點也算葉子，不然風一吹會破洞
    # 上一行補洞會把夾在葉子旁邊的頭頂輪廓（深橘）也吃進來，起風時被葉子扯走，頭邊變成碎點（多米 2026-11-18）。
    # 莖以下只留葉子的顏色，其餘還給頭。
    head_edge = leaf & (Y >= cfg['neck_y'] - 15) & ~greenish
    leaf &= ~head_edge
    print(f'葉子層裡的頭頂輪廓還給頭：{int(head_edge.sum())} 個像素')

    low = rest & ~leaf & (Y > cfg['legs_y'])
    layers['legwear'][1] = layers['legwear'][1] | low
    layers['legwear'][0] = np.where(low[..., None], o[..., :3], layers['legwear'][0])

    head_all = rest & ~leaf & ~low
    head = grow(shrink(head_all, 31), 31) & head_all   # 粗的是頭，細的是根鬚
    head = grow(head, 5) & head_all
    hair = head_all & ~head
    # 根鬚只留根鬚的黃；夾在衣服、手邊沒被 see-through 認走的碎布歸上衣（不動），不然會跟著根鬚擺
    b = o[..., 2]
    root_color = (r > 170) & (g > 100) & (b < 150) & (r - b > 100)
    scraps = hair & ~root_color
    hair &= root_color
    layers['topwear'][1] = layers['topwear'][1] | scraps
    layers['topwear'][0] = np.where(scraps[..., None], o[..., :3], layers['topwear'][0])
    print(f'根鬚裡的碎布歸上衣：{int(scraps.sum())} 個像素')
    cx = cfg['roots_split_x']
    parts = {'leaves': leaf, 'head': head, 'roots_L': hair & (X < cx), 'roots_R': hair & (X >= cx)}

    # 提桶那隻手：只拆袖口以下的手（膚色），提桶時整塊往上收進袖子裡；袖口和袖子留在雙手層、疊在手上面不動。
    # 整隻手臂或連袖口一起轉都不行：袖子看得到的部分被分給上衣了，手臂層的袖子是破的，一動就撕開。
    # 袖口以下的全部算手；不挑膚色，挑了會把手上的亮部和陰影留在原地，一提起來就變碎點
    fx0, fy0 = cfg['forearm']
    forearm = layers['handwear'][1] & (X >= fx0) & (Y >= fy0)

    # see-through 補畫的部分只該藏在別的零件後面。上衣補了「被腿擋住的裙子內側」，可是上衣疊在腿上面，
    # 補的那塊就會蓋住腿。所以補畫的像素不准蓋到「不會動的部位在原圖上看得到的像素」；
    # 木桶、前臂、葉子會動，它們後面的補畫要留著。
    for n in BODY:
        static_seen = head | low | scraps
        for m in BODY:
            if m != n and m != 'objects':
                static_seen = static_seen | (seen[m] & ~forearm)
        painted = layers[n][1] & ~seen[n]
        drop = painted & static_seen
        layers[n][1] = layers[n][1] & ~drop
        print(f'{n}：拿掉蓋到別層的補畫 {int(drop.sum())} 個像素')

    # 身體四層邊上那圈（扣頭部時多擴的 3 格）原本靠補畫蓋住，拿掉後會破洞：用原圖像素補進上衣（不動）
    covered = np.zeros((H, W), bool)
    for m in list(parts.values()) + [a for _, a in layers.values()]:
        covered |= m
    holes = oa & ~covered
    layers['topwear'][1] = layers['topwear'][1] | holes
    layers['topwear'][0] = np.where(holes[..., None], o[..., :3], layers['topwear'][0])

    forearm &= layers['handwear'][1]
    layers['arm_R'] = [layers['handwear'][0], forearm]
    layers['handwear'][1] = layers['handwear'][1] & ~forearm
    print(f'前臂（袖口＋手）：{int(forearm.sum())} 個像素')

    for n, m in parts.items():
        save(o[..., :3], m, os.path.join(out_dir, n + '.png'))
    for n, (rgb, a) in layers.items():
        save(rgb, a, os.path.join(out_dir, n + '.png'))
    save_eyes(o, cfg['eyes'], W, os.path.join(out_dir, 'eyes_closed.png'))

    union = np.zeros((H, W), bool)
    for m in list(parts.values()) + [a for _, a in layers.values()]:
        union |= m
    print(f'原圖有、九層都沒有的像素：{int((oa & ~union).sum())}')


def save(rgb, mask, path):
    Image.fromarray(np.dstack([rgb, np.where(mask, 255, 0)]).astype('uint8'), 'RGBA').save(path)


def save_eyes(o, boxes, W, path):
    cell = W / 168            # 一個像素格在這張圖上多寬
    ov = np.zeros(o.shape, np.uint8)
    for x0, y0, x1, y1 in boxes:
        ring = np.concatenate([o[y0 - 8:y0 - 2, x0:x1, :3].reshape(-1, 3), o[y1 + 2:y1 + 6, x0:x1, :3].reshape(-1, 3)])
        ov[y0 - 1:y1 + 2, x0 - 1:x1 + 2, :3] = np.median(ring, axis=0).astype(np.uint8)
        ov[y0 - 1:y1 + 2, x0 - 1:x1 + 2, 3] = 255
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + cell * 0.6
        for k, dy in zip(range(-2, 3), [1, 0, -0.6, 0, 1]):   # 往上彎的弧＝開心瞇眼
            xa, ya = int(cx + k * cell - cell / 2), int(cy + dy * cell - cell / 2)
            ov[ya:ya + int(cell) + 1, xa:xa + int(cell) + 1] = BROWN
    Image.fromarray(ov, 'RGBA').save(path)


if __name__ == '__main__':
    main(*sys.argv[1:5])
