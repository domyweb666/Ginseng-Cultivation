# 洋紅底的角色格 → 去背 → 疊到背景 → 合成動畫（原樣一份、像素格一份）
import sys, glob, os
from PIL import Image, ImageFilter
import numpy as np
src, bgp, out, ms = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
W, H = 1008, 1260
os.makedirs(out, exist_ok=True)
bg = Image.open(bgp).convert('RGBA').resize((W, H), Image.LANCZOS)
def key(im):
    a = np.asarray(im.convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = np.minimum(r, b) - g                      # 洋紅的程度
    solid = (mag > 90) & (np.abs(r - b) < 90)
    alpha = np.where(solid, 0, 255).astype('uint8')
    # 邊緣一圈帶洋紅的也去掉
    m = Image.fromarray(alpha).filter(ImageFilter.MinFilter(3))
    edge = (np.asarray(m) == 0) & (alpha == 255) & (mag > 35)
    alpha[edge] = 0
    # 淡淡的靈氣是白色疊在洋紅上，顏色落在洋紅到白的連線上：照綠色的量算透明度，顏色還原成白
    line = (r > 200) & (b > 200) & (np.abs(r - b) < 50) & (g < 215)
    soft = np.clip((g - 30) / 190.0, 0, 1)
    alpha = np.where(line, (soft * 255).astype('uint8'), alpha)
    rgb = a.copy()
    rgb[line] = (250, 252, 255)
    rgba = np.dstack([rgb.astype('uint8'), alpha])
    return Image.fromarray(rgba, 'RGBA')
files = sorted(glob.glob(os.path.join(src, 'step2_frame_*.png')))
print('frames', len(files))
frames = []
for f in files:
    im = Image.open(f)
    k = key(im).resize((W, H), Image.LANCZOS)
    ys, xs = np.nonzero(np.asarray(k)[..., 3] > 127)
    print(os.path.basename(f), im.size, 'opaque %', round(float((np.asarray(k)[..., 3] > 0).mean()) * 100, 1), 'bbox', (xs.min(), ys.min(), xs.max(), ys.max()))
    k.save(os.path.join(out, 'cut_' + os.path.basename(f)))
    frames.append(k)
comps = [Image.alpha_composite(bg, f).convert('RGB') for f in frames]
comps[0].save(os.path.join(out, 'comp.webp'), save_all=True, append_images=comps[1:], duration=ms, loop=0, quality=88, method=4)
small = [c.resize((168, 210), Image.BOX) for c in comps]
strip = Image.new('RGB', (168 * len(small), 210))
for i, s in enumerate(small): strip.paste(s, (168 * i, 0))
pal = strip.quantize(colors=72, method=Image.MEDIANCUT, dither=Image.NONE)
q = [s.quantize(palette=pal, dither=Image.NONE) for s in small]
q[0].save(os.path.join(out, 'pixel.gif'), save_all=True, append_images=q[1:], duration=ms, loop=0)
cols = 6; tw = 220; th = round(tw * H / W); rows = -(-len(comps) // cols)
sheet = Image.new('RGB', (tw * cols, th * rows), 'white')
for k, c in enumerate(comps): sheet.paste(c.resize((tw, th), Image.LANCZOS), ((k % cols) * tw, (k // cols) * th))
sheet.save(os.path.join(out, 'sheet.png'))
arr = [np.asarray(c).astype(int) for c in comps]
print('step %', [round(float((np.abs(arr[i] - arr[i - 1]).sum(axis=2) > 24).mean()) * 100, 1) for i in range(len(arr))])
print('sizes', {n: os.path.getsize(os.path.join(out, n)) for n in ('comp.webp', 'pixel.gif')})
