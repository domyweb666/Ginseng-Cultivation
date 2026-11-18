"""方案 B 第二輪：15 秒影片（首尾都是原圖）平均攤成 96 格，比兩個模型。

跟 video_to_pixels.py 的差別只有取格：那支是 5 秒影片每 0.15 秒取一張、嵌在第 18 格起；
這支是整支 15 秒平均攤進 96 格（第 k 格取 15 秒 × k / 96 那一刻），一輪播 96 × 0.15 = 14.4 秒，比原影片快不到 4%。
縮放對位、防閃（動過的範圍、黏住、貼回原圖）都沿用那支的做法與參數。

用法：python video15_to_pixels.py 影片.mp4 名字 [影片2.mp4 名字2 ...]
輸出（都在這個資料夾）：
  {名字}_anim96.png   12×8 格子圖，跟 app 讀的格式一樣
  {名字}_一輪.gif      放大 3 倍，一格 0.15 秒
  {名字}_接縫.png      最後 3 格接第一格 3 格，看循環接回去會不會跳
  兩支以上時另出 對照_15秒.gif（左右並排）
"""
import glob
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

import video_to_pixels as V
from video_to_pixels import A, px, GH, GW, grow, shrink, lab, sample

HERE = V.HERE
S, GAP = 3, 8


def extract(video, name):
    out = os.path.join(HERE, 'frames_' + name)
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-vsync', '0', os.path.join(out, 'f%04d.png')], check=True)
    files = sorted(glob.glob(os.path.join(out, 'f*.png')))
    if not files:
        raise RuntimeError('影片抽不出任何一格：' + video)
    return files


def to_cells(files, base, pal, pal_lab):
    quant = lambda rgb: pal[px.nearest(px.rgb2lab(np.clip(rgb, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)].astype(np.float32)
    first = np.asarray(Image.open(files[0]).convert('RGB')).astype(np.float32)
    h, w = first.shape[:2]
    best = None
    for sx in np.arange(w / GW - 0.12, w / GW + 0.121, 0.02):
        for sy in np.arange(h / GH - 0.12, h / GH + 0.121, 0.02):
            for ox in range(-6, 7, 2):
                for oy in range(-6, 7, 2):
                    same = (np.abs(quant(sample(first, sx, sy, ox, oy)) - base).sum(-1) == 0).mean()
                    if best is None or same > best[0]:
                        best = (same, sx, sy, ox, oy)
    print('  影片', w, 'x', h, '格數', len(files), '對位', tuple(round(float(v), 3) for v in best))
    _, sx, sy, ox, oy = best

    # 平均攤開：第 k 格取第 k/96 的位置；最後一格不取到片尾（片尾就是原圖，等於第 0 格）
    raw = []
    for k in range(A.N):
        f = files[int(k * len(files) / A.N)]
        raw.append(quant(sample(np.asarray(Image.open(f).convert('RGB')).astype(np.float32), sx, sy, ox, oy)))

    base_lab = lab(base)
    region = np.zeros((GH, GW), bool)
    for q in raw:
        region |= grow(shrink(np.linalg.norm(lab(q) - base_lab, axis=-1) > V.MOVED, 1), 1)
    region = grow(region, V.REGION_GROW)
    cells, prev = [], base.copy()
    for q in raw:
        near_base = np.linalg.norm(lab(q) - base_lab, axis=-1) < V.STICKY
        steady = np.linalg.norm(lab(q) - lab(prev), axis=-1) < V.STICKY
        cur = np.where(steady[..., None], prev, q)
        cur = np.where(near_base[..., None], base, cur)
        cur = np.where(region[..., None], cur, base)
        cells.append(cur)
        prev = cur
    print('  動過的範圍', int(region.sum()), '格（全圖', GH * GW, '）')
    return cells


def big(c):
    return np.kron(c, np.ones((S, S, 1))).astype(np.uint8)


def save_outputs(name, cells, pal, pal_lab):
    idx = np.zeros((GH * (A.N // A.COLS), GW * A.COLS), np.uint8)
    for i, fr in enumerate(cells):
        r, cc = divmod(i, A.COLS)
        idx[r * GH:(r + 1) * GH, cc * GW:(cc + 1) * GW] = px.nearest(px.rgb2lab(fr.reshape(-1, 3)), pal_lab).reshape(GH, GW)
    im = Image.fromarray(idx, 'P')
    im.putpalette(pal.reshape(-1).tolist())
    im.save(os.path.join(HERE, name + '_anim96.png'), optimize=True)

    frames = [Image.fromarray(big(c)) for c in cells]
    frames[0].save(os.path.join(HERE, name + '_一輪.gif'), save_all=True, append_images=frames[1:], duration=150, loop=0)

    seam = [cells[-3], cells[-2], cells[-1], cells[0], cells[1], cells[2]]
    strip = np.full((GH * S, (GW * S + GAP) * len(seam), 3), 40, np.uint8)
    for j, c in enumerate(seam):
        strip[:, j * (GW * S + GAP):j * (GW * S + GAP) + GW * S] = big(c)
    Image.fromarray(strip).save(os.path.join(HERE, name + '_接縫.png'))


def main():
    args = sys.argv[1:]
    if not args or len(args) % 2:
        raise SystemExit('用法：python video15_to_pixels.py 影片.mp4 名字 [影片2.mp4 名字2 ...]')
    base, pal = A.load(V.FOLDER, 'r0')
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    runs = []
    for video, name in zip(args[0::2], args[1::2]):
        if not os.path.isfile(video):
            raise SystemExit('找不到影片：' + video)
        print(name)
        cells = to_cells(extract(video, name), base, pal, pal_lab)
        save_outputs(name, cells, pal, pal_lab)
        runs.append(cells)
    if len(runs) > 1:
        gif = []
        for i in range(A.N):
            canvas = np.full((GH * S, (GW * S + GAP) * len(runs) - GAP, 3), 40, np.uint8)
            for j, cells in enumerate(runs):
                canvas[:, j * (GW * S + GAP):j * (GW * S + GAP) + GW * S] = big(cells[i])
            gif.append(Image.fromarray(canvas))
        gif[0].save(os.path.join(HERE, '對照_15秒.gif'), save_all=True, append_images=gif[1:], duration=150, loop=0)


if __name__ == '__main__':
    main()
