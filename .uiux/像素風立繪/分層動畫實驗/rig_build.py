"""產生 Rigby2D 要吃的 JSON：骨架、把圖層掛到骨頭上的 patch、待機動畫。特效不走 Rigby2D，在 fx.py。

用法：python rig_build.py <工作資料夾> <設定.json>
設定.json：{"width": 圖寬, "height": 圖高, "pivots": {"leaf": [x, y], "arm": [...], "bucket": [...]}}
pivots 是各骨頭轉軸在圖上的位置：葉子轉莖的根部、前臂轉袖口開口、木桶轉手握的提把。
座標：圖上 (px, py) → Rigby (px - W/2, H - py)，原點在畫布底部中央、y 往上；角度逆時針為正。
"""
import json
import math
import os
import sys

LOOP = 9.6   # 一輪秒數
# (骨頭, 父骨頭)：木桶掛在前臂底下，手提起來桶跟著走
BONES = [('leaf', 'root'), ('arm', 'root'), ('bucket', 'arm')]
SLOT_BONE = {'leaves': 'leaf', 'arm_R': 'arm', 'objects': 'bucket'}
BONE_ROTATION = 90   # 骨頭都朝上

# 多米 2026-11-18：「拆成小部件了，動作幅度大一點」。身體、衣服、頭、根鬚照舊不動，大動作給葉子、前臂、木桶。
# 2 秒一陣風從左邊吹來（往右＝順時針＝負角度）：葉子大幅被吹歪、盪回來
LEAF = [(0, 0), (2.0, 0), (2.5, -13), (3.3, 8), (4.0, -5), (4.6, 2.5), (5.2, 0), (LOOP, 0)]
# 5.6 秒掂一次水桶：手先往下沉（預備）、往上收進袖子把桶提起來、停一下、放下（往上為正，單位是原圖像素，6 像素＝1 格）
# 跟 app 舊版 rig_r0 的掂水桶一樣：手臂上收 6 格、袖口不動
ARM_LIFT = [(0, 0), (5.6, 0), (5.85, -8), (6.15, 36), (6.5, 36), (6.75, -6), (7.0, 0), (LOOP, 0)]
# 木桶：起風時小晃；提起來時幾乎不晃，放下後大幅盪幾下才停
BUCKET = [(0, 0), (2.5, 0), (3.0, -4), (3.7, 3), (4.3, -1.5), (4.9, 0),
          (5.85, 0), (6.15, -3), (6.5, 2), (6.75, 8), (7.15, -6), (7.55, 3.5), (7.95, -1.5), (8.35, 0), (LOOP, 0)]
# 眨眼：閉眼那層平常藏著，(時間, 藏不藏)；第二次等桶停了再眨
BLINK = [(0, True), (1.2, False), (1.35, True), (8.7, False), (8.85, True), (9.15, False), (9.3, True)]


def rot_keys(bone, seq):
    return [{"op": "set_bone_key", "animation": "idle", "bone": bone, "channel": "rotate",
             "time": round(t, 3), "value": v, "curve": "easeInOut"} for t, v in seq]


def main(work, config_path):
    cfg = json.load(open(config_path, encoding='utf-8'))
    W, H = cfg['width'], cfg['height']
    missing = [b for b, _ in BONES if b not in cfg.get('pivots', {})]
    if missing:
        raise SystemExit(f'設定檔少了骨頭位置：{missing}')
    world = {'root': (0.0, 0.0)}
    world.update({b: (cfg['pivots'][b][0] - W / 2, H - cfg['pivots'][b][1]) for b, _ in BONES})

    def dump(name, obj):
        with open(os.path.join(work, name), 'w', encoding='utf-8') as f:
            json.dump(obj, f, ensure_ascii=False, indent=1)

    bones = []
    for name, parent in BONES:
        dx, dy = world[name][0] - world[parent][0], world[name][1] - world[parent][1]
        if parent == 'root':
            x, y, rotation = dx, dy, BONE_ROTATION
        else:   # 換到父骨頭的座標（父骨頭轉了 90 度）
            c, s = math.cos(math.radians(-BONE_ROTATION)), math.sin(math.radians(-BONE_ROTATION))
            x, y, rotation = c * dx - s * dy, s * dx + c * dy, 0
        bones.append({"op": "add_bone", "name": name, "parent": parent, "x": x, "y": y, "rotation": rotation, "length": 60})
    dump('bones.json', {"path": "lianqi.rigby", "output": "lianqi_b.rigby", "overwrite": True, "operations": bones})
    dump('patch.json', {"reparent": SLOT_BONE, "top": {"textureFilter": "nearest"}})

    ops = [{"op": "add_animation", "name": "idle"}]
    ops += rot_keys('leaf', LEAF)
    # 平移照父骨頭（root，沒轉）的方向算，往上就是 y（實測：填 x 會往右移）
    ops += [{"op": "set_bone_key", "animation": "idle", "bone": "arm", "channel": "translate",
             "time": round(t, 3), "x": 0, "y": v, "curve": "easeInOut"} for t, v in ARM_LIFT]
    ops += rot_keys('bucket', BUCKET)
    # 根鬚不動：細根鬚整塊轉，邊上會一格一格跳，看起來像破圖（多米 2026-11-18）
    for t, hide in BLINK:
        k = {"op": "set_attachment_key", "animation": "idle", "slot": "eyes_closed", "time": t}
        k.update({"hide": True} if hide else {"attachment": "eyes_closed"})
        ops.append(k)
    dump('anim.json', {"path": "lianqi_c.rigby", "output": "lianqi_d.rigby", "overwrite": True, "operations": ops})


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
