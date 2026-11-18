"""分層動畫實驗的最後一步：背景（不動）＋角色（Rigby2D 渲染）＋特效（fx.py 直接畫在像素格上）疊成成品。

用法：python compose.py <背景.png> <角色格資料夾> <輸出資料夾> <檔名前綴> [對照用的舊格子圖]
角色是 20fps 渲染的，一輪 9.6 秒共 193 張（最後一張等於第一張）；每 3 張取 1 張，變成一格 0.15 秒、64 格。
特效不用 Rigby2D 的粒子：柔邊光點疊在像素圖上很突兀（多米 2026-11-18），改成跟 app 立繪一樣一格一格畫。
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

import fx

GW, GH = 168, 210          # app 立繪的像素格
SHOW = 6                   # 放大倍數，給人看用
STEP = 3                   # 20fps → 每格 0.15 秒
FRAME_MS = 150


def load_frames(folder):
    files = sorted(glob.glob(os.path.join(folder, '*.png')))
    if len(files) < 2:
        raise SystemExit(f'找不到格子：{folder}')
    return files[:-1][::STEP]   # 丟掉跟第一張一樣的最後一張


def to_cells(rgba):
    """高解析 RGBA → 168×210：每格取正中央那一點（整格平均會把像素邊糊掉）。"""
    small = np.asarray(rgba.resize((GW, GH), Image.NEAREST)).astype(np.float32)
    return small[..., :3], small[..., 3] >= 128


def main():
    bg_path, char_dir, out_dir, name = sys.argv[1:5]
    old_sheet = sys.argv[5] if len(sys.argv) > 5 else None
    os.makedirs(out_dir, exist_ok=True)
    char_files = load_frames(char_dir)
    W, H = Image.open(char_files[0]).size
    bg_hi = Image.open(bg_path).convert('RGB').resize((W, H), Image.LANCZOS)
    bg_cells = np.asarray(bg_hi.resize((GW, GH), Image.NEAREST)).astype(np.float32)

    hi, cells = [], []
    for f, cf in enumerate(char_files):
        ch = Image.open(cf).convert('RGBA')
        hi.append(Image.alpha_composite(bg_hi.convert('RGBA'), ch).convert('RGB').resize((W * 9 // 10, H * 9 // 10), Image.LANCZOS))
        # 三層：背景（不動）→ 背景上的特效 → 角色 → 角色前的特效
        rgb, mask = to_cells(ch)
        px = bg_cells.copy()
        fx.back(px, f)
        px = np.where(mask[..., None], rgb, px)
        fx.front(px, f)
        cells.append(np.clip(px, 0, 255).astype('uint8'))

    # 共用一套色盤、不抖色。72 色時根鬚邊的淡黃會被併進背景草地的黃綠，所以放到 160 色
    strip = Image.fromarray(np.concatenate(cells, axis=1))
    pal = strip.quantize(colors=160, method=Image.MEDIANCUT, dither=Image.NONE)
    q = [Image.fromarray(c).quantize(palette=pal, dither=Image.NONE) for c in cells]
    big = [x.resize((GW * SHOW, GH * SHOW), Image.NEAREST) for x in q]
    big[0].save(os.path.join(out_dir, f'{name}_像素_放大6倍.gif'), save_all=True, append_images=big[1:], duration=FRAME_MS, loop=0)
    q[0].save(os.path.join(out_dir, f'{name}_像素_168x210.gif'), save_all=True, append_images=q[1:], duration=FRAME_MS, loop=0)
    hi[0].save(os.path.join(out_dir, f'{name}_高解析_無特效.webp'), save_all=True, append_images=hi[1:], duration=FRAME_MS, loop=0, quality=85, method=4)

    cols = 8
    sheet = Image.new('RGB', (GW * cols, GH * (len(q) // cols)))
    for i, x in enumerate(q):
        sheet.paste(x.convert('RGB'), ((i % cols) * GW, (i // cols) * GH))
    sheet.save(os.path.join(out_dir, f'{name}_格子圖.png'))

    if old_sheet:
        compare(old_sheet, q, bg_cells, out_dir, name)
    print('frames', len(q), 'out', out_dir)


def compare(old_sheet, new_frames, bg_cells, out_dir, name):
    """舊的 app 待機動畫（96 格、一格 0.15 秒）跟新的並排，都放大 3 倍；新的 64 格循環播。"""
    old = Image.open(old_sheet).convert('RGBA')
    cols = old.width // GW
    n_old = cols * (old.height // GH)
    s = 3
    frames = []
    for i in range(n_old):
        r, c = divmod(i, cols)
        o = old.crop((c * GW, r * GH, (c + 1) * GW, (r + 1) * GH))
        o = Image.alpha_composite(Image.fromarray(bg_cells.astype('uint8')).convert('RGBA'), o) if o.getextrema()[3][0] < 255 else o
        n = new_frames[i % len(new_frames)].convert('RGB')
        canvas = Image.new('RGB', (GW * s * 2 + 12, GH * s + 28), (24, 28, 34))
        canvas.paste(o.convert('RGB').resize((GW * s, GH * s), Image.NEAREST), (0, 28))
        canvas.paste(n.resize((GW * s, GH * s), Image.NEAREST), (GW * s + 12, 28))
        d = ImageDraw.Draw(canvas)
        d.text((8, 8), 'now in app', fill=(230, 230, 230))
        d.text((GW * s + 20, 8), 'see-through + Rigby2D', fill=(246, 207, 90))
        frames.append(canvas)
    frames[0].save(os.path.join(out_dir, f'{name}_對照_現在vs新流程.gif'), save_all=True, append_images=frames[1:], duration=FRAME_MS, loop=0)


if __name__ == '__main__':
    main()
