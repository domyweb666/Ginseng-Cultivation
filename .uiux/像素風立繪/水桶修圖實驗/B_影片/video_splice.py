"""方案 B 定案做法（多米 2026-11-19 選）：影片只生 6 秒招牌動作，接進 app 現在那條程式動畫。

為什麼不生 15 秒：H3 做完一個動作大約 4、5 秒，15 秒的影片後半都站著不動，等於花錢買空白（多米抓到的）。
為什麼不把 6 秒攤成 96 格：會變慢動作，提桶、水花都慢下來（0.5 倍慢放早就被退過）。

做法：
  1. 影片每 0.15 秒取一張（app 的播放速度），6 秒剛好 40 格；縮回 168×210、收色盤、防閃都跟 video15_to_pixels.py 同一套。
  2. 塞進程式動畫的第 START 格起，換掉程式做的那段招牌動作。程式動畫前 48 格身體是「低」的那一拍，
     影片首尾都是原圖，接回去只差葉子被風帶的一兩格，不會整個人跳。
  3. 影片那幾格照樣疊上同一格的環境特效（落葉、草屑、燈火……），特效才不會在動作那 6 秒消失：
     特效寫成 out = img × T + C（animate.fx_affine），角色前面的（front）、整張的（post）直接疊；
     角色後面的（back）只疊在不是角色的格子上。
  4. 角色遮罩（付費造型換色用）：跟背景層差得夠多的格子算角色，太小的碎點不算（跟 animate.layers 同一個規矩）。

用法：python video_splice.py 影片.mp4 代號 [START]
輸出：{代號}_anim96_B6.png、{代號}_anim96_B6_mask.png、{代號}_B6_一輪.gif、{代號}_B6_接縫.png（都在這個資料夾）
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

import video15_to_pixels as P
from video15_to_pixels import A, GH, GW, V, px

CLIP_FRAMES = 40       # 6 秒 ÷ 0.15 秒
DEFAULT_START = 0      # 程式動畫第 0 格就是原圖，從這裡接最不會跳
CHAR_LAB = 10          # 跟背景層差多少（Lab 距離）才算角色


def main():
    if len(sys.argv) < 3:
        raise SystemExit('用法：python video_splice.py 影片.mp4 代號 [START]')
    video, name = sys.argv[1], sys.argv[2]
    start = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_START
    if not os.path.isfile(video):
        raise SystemExit('找不到影片：' + video)
    if not 0 <= start <= A.N - CLIP_FRAMES:
        raise SystemExit('START 要在 0 到 %d 之間' % (A.N - CLIP_FRAMES))

    rg, pal, mask = A.build_rig(V.FOLDER, name)
    base, _ = A.load(V.FOLDER, name)
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    quant = lambda rgb: pal[px.nearest(px.rgb2lab(np.clip(rgb, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)].astype(np.float32)

    files = P.extract(video, name + '_B6')
    # H3 出的片子是一秒 24 張，長度會比要的多一點（6 秒出 6.58 秒），所以照張數算時間，不照片長平分
    picks = [int(round(k * V.STEP_S * V.FPS)) for k in range(CLIP_FRAMES)]
    clip = P.to_cells(files, base, pal, pal_lab, picks)

    frames = [f.astype(np.float32) for f in rg.frames()]
    bg_lab = P.lab(rg.bg)
    sheet_cells, mask_cells = [], []
    old_mask = np.asarray(Image.open(os.path.join(V.FOLDER, name + '_anim96_mask.png')).convert('L')) > 127
    for f in range(A.N):
        r, c = divmod(f, A.COLS)
        k = f - start
        if 0 <= k < CLIP_FRAMES:
            img = clip[k].copy()
            lay = A.layers(rg, mask, f)
            char = np.linalg.norm(P.lab(img) - bg_lab, axis=-1) > CHAR_LAB
            labels, n = ndimage.label(char, structure=np.ones((3, 3)))
            if n:
                sizes = ndimage.sum(char, labels, range(1, n + 1))
                char &= np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= A.CHAR_MIN_PIECE])
            T, C = lay['back']
            behind = img * T + C
            img = np.where(char[..., None], img, behind)
            for key in ('front', 'post'):
                T, C = lay[key]
                img = img * T + C
            sheet_cells.append(quant(img))
            mask_cells.append(char)
        else:
            sheet_cells.append(quant(frames[f]))
            mask_cells.append(old_mask[r * GH:(r + 1) * GH, c * GW:(c + 1) * GW])

    idx = A.sheet_of([px.nearest(px.rgb2lab(cell.reshape(-1, 3)), pal_lab).reshape(GH, GW).astype(np.uint8) for cell in sheet_cells])
    im = Image.fromarray(idx, 'P')
    im.putpalette(pal.reshape(-1).tolist())
    im.save(os.path.join(P.HERE, name + '_anim96_B6.png'), optimize=True)
    Image.fromarray((A.sheet_of(mask_cells) * 255).astype(np.uint8)).save(os.path.join(P.HERE, name + '_anim96_B6_mask.png'))

    gif = [Image.fromarray(P.big(cell)) for cell in sheet_cells]
    gif[0].save(os.path.join(P.HERE, name + '_B6_一輪.gif'), save_all=True, append_images=gif[1:], duration=150, loop=0)
    # 接縫：影片進場前後、出場前後各三格
    picks = [start - 2, start - 1, start, start + 1, None, start + CLIP_FRAMES - 2, start + CLIP_FRAMES - 1,
             start + CLIP_FRAMES, start + CLIP_FRAMES + 1]
    strip = np.full((GH * P.S, (GW * P.S + P.GAP) * len(picks), 3), 40, np.uint8)
    for j, f in enumerate(picks):
        if f is not None:
            strip[:, j * (GW * P.S + P.GAP):j * (GW * P.S + P.GAP) + GW * P.S] = P.big(sheet_cells[f % A.N])
    Image.fromarray(strip).save(os.path.join(P.HERE, name + '_B6_接縫.png'))
    print('接在第', start, '到', start + CLIP_FRAMES - 1, '格')


if __name__ == '__main__':
    main()
