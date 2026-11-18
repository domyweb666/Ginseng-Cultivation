"""煉氣男的特效，直接畫在 168×210 的像素格上（跟 animate.py 一樣的做法，不用 Rigby2D 的粒子）。

每個特效都對應動畫裡的一個動作（時間軸看 rig_build.py：一格 0.15 秒，64 格一輪）：
- 2.0～3.0 秒起風 → 地上四根草屑被捲起來飄過去
  （原本還有幾道風線，多米說不明顯、疊在角色上像破圖，2026-11-18 拿掉）
- 6.8 秒掂完水桶、放下來 → 桶口濺出幾滴水
- 一直都在 → 背景燈籠的光慢慢閃（燈籠本來就在背景上）
- 沒有大動作的空檔（5 秒、9 秒）→ 紅果閃一下

位置都是這張原圖版在格子上的座標；換角色要重抓。
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from rig import GOLD, PALE, dot, glow, plus  # noqa: E402  共用 app 立繪的畫點工具與色票

FRAME_S = 0.15
LANTERN = (142, 86)            # 背景燈籠中心
RIM = (123, 143)               # 桶口中間
BERRY_TWINKLES = [((90, 9), 33), ((79, 14), 60)]   # (位置, 第幾格開始閃)
# 背景是亮的（白天空、淺石階），白色和淡金畫上去會看不見：水滴帶一格深藍邊、草屑用深綠
WATER = np.array([214, 238, 250], dtype=np.float32)
WATER_EDGE = np.array([104, 160, 196], dtype=np.float32)
GRASS_A = np.array([84, 116, 36], dtype=np.float32)
GRASS_B = np.array([140, 164, 56], dtype=np.float32)
LANTERN_FLICKER = [.25, .45, .35, .5, .3, .45, .25, .4, .5, .35, .3, .45]

# 草屑：(出發點, 第幾格出發)；往右飄、先被捲高再慢慢落，一邊翻
GRASS = [((10, 166), 13), ((22, 182), 14), ((4, 150), 16), ((30, 172), 18)]


def back(img, f):
    """畫在角色後面（背景上）的。"""
    glow(img, LANTERN[0], LANTERN[1], 11, LANTERN_FLICKER[(f // 2) % len(LANTERN_FLICKER)], PALE)


def front(img, f):
    """畫在角色前面的。"""
    for (x0, y0), start in GRASS:
        t = f - start
        if 0 <= t < 40:
            x = x0 + 4.2 * t
            y = y0 - 9 * math.sin(min(t, 10) / 10 * math.pi / 2) + max(0, t - 10) * 0.9 + 2 * math.sin(t * 0.7)
            spin = t % 4          # 翻：橫、斜、直、斜，四格長
            dx, dy = [(1, 0), (1, 1), (0, 1), (-1, 1)][spin]
            dot(img, x - dx, y - dy, GRASS_A)
            dot(img, x, y, GRASS_A)
            dot(img, x + dx, y + dy, GRASS_B)
            dot(img, x + 2 * dx, y + 2 * dy, GRASS_B)

    t = f - 45                    # 6.8 秒桶放下來往前盪，水從桶口往外濺
    if 0 <= t < 5:
        for k in (-1, 0, 1):
            x = RIM[0] + 6 + k * (2 + 2 * t)
            y = RIM[1] - 1 - 4 * t + 1.2 * t * t
            dot(img, x, y, WATER, 1 - t * 0.15)
            dot(img, x, y + 1, WATER_EDGE, 1 - t * 0.15)

    for (x, y), start in BERRY_TWINKLES:
        t = f - start
        if 0 <= t < 3:
            plus(img, x, y, GOLD, [0.6, 1.0, 0.5][t])
