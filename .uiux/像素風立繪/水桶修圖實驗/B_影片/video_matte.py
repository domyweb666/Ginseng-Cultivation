"""B 方案影片格的 AI 去背：付費造型換色要知道影片每一格哪些是人蔘本體。

為什麼要另外做：video_splice.py 存的 _B6_mask 是「跟背景層差得夠多的格子」，
影片裡的光、水花、影子、被影片重畫過一點點的背景都會被算進去。換成赤霞夕照這種整片換底的造型，
這些就變成角色顏色的殘塊黏在人蔘旁邊（多米 2026-11-21 真機看到的「沒去背乾淨」）。
所以影片用到的每一張都跑一次 rembg（跟靜態圖 ai_matte.py 同一個 BiRefNet），
照 video_splice 的對位縮成 168×210，一格裡角色佔幾成存成灰階。怎麼跟 _B6_mask 合在一起看 make_style_anims.use_b_video。

BiRefNet 在這台沒有顯示卡，一張大約 11 秒，14 支影片共七百多張，要跑一兩個小時。
可以同時開幾個程式跑不同代號（環境變數 OMP_NUM_THREADS 控制一個程式用幾條執行緒）。

用法：python video_matte.py 代號 [代號…]
要先跑過 video_splice.py（用它留下的 frames_{代號}_B6/ 和 {代號}_B6.json）。
輸出：{代號}_anim96_B6_aimask.png（12×8 格，灰階 0 到 255＝那一格有幾成是角色；不是影片的格子是黑的）
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image
from rembg import new_session, remove

import video15_to_pixels as P
from video15_to_pixels import A, GH, GW, V, px

MODEL = 'birefnet-general'   # isnet 在影片格上會把光帶算進來、把飄帶切碎（2026-11-21 五張對照過）
EDGE = 32                    # 取格子前影片四邊各墊幾點；對位的位移最多差 6 點加上比例的誤差，32 夠了


def main():
    names = sys.argv[1:]
    if not names:
        raise SystemExit('用法：python video_matte.py 代號 [代號…]')
    session = new_session(MODEL)
    for name in names:
        with open(os.path.join(P.HERE, name + '_B6.json'), encoding='utf-8') as fp:
            spec = json.load(fp)
        start, clip_frames = spec['start'], spec['frames']
        files = sorted(glob.glob(os.path.join(P.HERE, 'frames_' + name + '_B6', 'f*.png')))
        if not files:
            raise SystemExit('找不到 frames_%s_B6，先跑 video_splice.py' % name)
        base, pal = A.load(V.FOLDER, name)
        pal_lab = px.rgb2lab(pal.astype(np.float32))
        quant = lambda rgb: pal[px.nearest(px.rgb2lab(np.clip(rgb, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)].astype(np.float32)
        first = np.asarray(Image.open(files[0]).convert('RGB')).astype(np.float32)
        _, sx, sy, ox, oy = P.find_mapping(first, base, quant)
        # 取哪幾張要跟 video_splice.py 一模一樣
        picks = [int(round(k * V.STEP_S * V.FPS)) for k in range(clip_frames - 1)] + [len(files) - 1]
        cells = [np.zeros((GH, GW), np.uint8) for _ in range(A.N)]
        for k, index in enumerate(picks):
            im = Image.open(files[min(index, len(files) - 1)]).convert('RGB')
            alpha = remove(im, session=session, only_mask=True)
            # 一格對到影片上 sx×sy 點的一塊，取那一塊的平均。
            # 對位的位移可能是負的（元嬰男），PIL 不收負的框：四邊先各墊 EDGE 點（照邊緣的值延伸）再取
            padded = Image.fromarray(np.pad(np.asarray(alpha), EDGE, mode='edge'))
            left, top = ox + EDGE, oy + EDGE
            small = padded.resize((GW, GH), Image.BOX, box=(left, top, left + GW * sx, top + GH * sy))
            cells[start + k] = np.asarray(small)
            print(name, k + 1, '/', len(picks), flush=True)
        Image.fromarray(A.sheet_of(cells)).save(os.path.join(P.HERE, name + '_anim96_B6_aimask.png'), optimize=True)
        print(name, '完成', flush=True)


if __name__ == '__main__':
    main()
