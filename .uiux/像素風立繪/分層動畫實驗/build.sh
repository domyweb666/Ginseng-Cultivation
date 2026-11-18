#!/usr/bin/env bash
# 圖層 → PSD → Rigby2D 綁骨與動畫 → 渲染角色 → 合成成品（特效在 fx.py，直接畫在像素格上）
# 用法：bash build.sh <圖層資料夾> <背景.png> <工作資料夾> <Rigby2D 原始碼資料夾> <設定.json> <輸出檔名前綴>
# 圖層資料夾要有：roots_L roots_R legwear topwear head eyes_closed leaves objects handwear arm_R（.png，同尺寸透明底）
# 設定.json 見 rig_build.py 開頭
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAYERS="$1"; BG="$2"; WORK="$3"; RIGBY="$4"; CFG="$(cd "$(dirname "$5")" && pwd)/$(basename "$5")"; NAME="$6"
WH=$(python -c "import json,sys;c=json.load(open(sys.argv[1],encoding='utf-8'));print(c['width'],c['height'])" "$CFG"); W=${WH% *}; H=${WH#* }
R="node $RIGBY/bin/rigby.js"
mkdir -p "$WORK/raw" && cd "$WORK"

# 1. 每層裁到自己的範圍，存成 raw，再拼成 PSD（圖層由下到上）
python - "$LAYERS" raw <<'EOF'
import json, sys
import numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
order = ['roots_L', 'roots_R', 'legwear', 'topwear', 'head', 'eyes_closed', 'leaves', 'objects', 'arm_R', 'handwear']   # 袖口疊在手上面，手才像收進袖子
man = []
for n in order:
    a = np.asarray(Image.open(f'{src}/{n}.png').convert('RGBA'))
    ys, xs = np.nonzero(a[..., 3])
    if len(xs) == 0:
        raise SystemExit(f'圖層是空的：{n}')
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    c = np.ascontiguousarray(a[y0:y1, x0:x1]); c[c[..., 3] == 0] = 0
    open(f'{out}/{n}.bin', 'wb').write(c.tobytes())
    man.append(dict(name=n, left=int(x0), top=int(y0), right=int(x1), bottom=int(y1)))
json.dump(dict(width=a.shape[1], height=a.shape[0], layers=man), open(f'{out}/manifest.json', 'w'))
EOF
node "$HERE/make_psd.mjs" "$RIGBY" raw lianqi.psd
$R import-psd lianqi.psd -f

# 2. 骨架、把圖層掛到骨頭上、待機動畫
python "$HERE/rig_build.py" . "$CFG"
$R call batch_edit --args-file bones.json
python -I "$HERE/patch_rigby.py" lianqi_b.rigby lianqi_c.rigby patch.json
$R call batch_edit --args-file anim.json
$R call set_output --path lianqi_d.rigby --fps 20 --width $W --height $H --background transparent \
  --framing fixed --frame_x 0 --frame_y $((H / 2)) --frame_scale 1

# 3. 渲染（RTX 上的無頭 Chromium），透明底；特效不走 Rigby2D，合成時由 fx.py 直接畫在像素格上
rm -rf out
$R render lianqi_d.rigby -a idle --out out/ --format png --engine chromium -f

# 4. 合成到實驗資料夾，附上跟 app 現在的待機動畫對照
python "$HERE/compose.py" "$BG" out "$HERE" "$NAME" "$HERE/../../../ios/Rencan/Resources/Assets.xcassets/Portraits/r0Anim.imageset/r0Anim.png"
