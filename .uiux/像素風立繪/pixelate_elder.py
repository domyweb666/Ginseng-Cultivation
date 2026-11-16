"""把長老圖轉成像素圖，沿用 14 張境界立繪那份 72 色色盤（不重算，免得 14 張的顏色跟著變）。

用法：python pixelate_elder.py <elder.png> <統一色盤資料夾>
色盤從 <統一色盤資料夾>/r0_168x210.png 讀出來，輸出 <統一色盤資料夾>/elder_168x210.png。
"""
import os
import sys

import numpy as np
from PIL import Image

import pixelate2 as px


def main():
    src, out = sys.argv[1], sys.argv[2]
    ref = Image.open(os.path.join(out, 'r0_%dx%d.png' % (px.GW, px.GH)))
    if ref.mode != 'P':
        raise SystemExit('r0 不是調色盤格式，讀不到共用色盤')
    pal = np.array(ref.getpalette()[:px.NCOL * 3], dtype=np.uint8).reshape(-1, 3)
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    a = px.cells(src)
    idx = px.nearest(px.rgb2lab(a.reshape(-1, 3)), pal_lab).reshape(px.GH, px.GW)
    idx = px.cleanup(idx, pal_lab)
    px.save(idx, pal, os.path.join(out, 'elder_%dx%d.png' % (px.GW, px.GH)))
    print('elder colours', len(set(idx.ravel().tolist())))


if __name__ == '__main__':
    main()
