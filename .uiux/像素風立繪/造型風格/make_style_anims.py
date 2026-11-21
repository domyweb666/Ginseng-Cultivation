"""十一種付費造型的待機動畫（組塊 M2）：14 個境界 × 11 種造型 = 154 條，每條 12×8 共 96 格，跟原版動畫同一套動作。

做法：
  - 掌機四色（handheld）、粗像素（chunky）：本來就不分角色背景，直接把原版動畫逐格套換色函式。
    粗像素原本每張自己挑 20 色，動畫逐格挑會閃，所以整條共用同一份色盤（照靜態圖挑的那份）、不抖色。
  - 其他九種：用 animate.layers() 把每一格拆成
      角色（零件搬過來的格子，原本的位置在 AI 去背範圍裡才算；道具、葉子也是零件，一樣算）、
      背景（固定用背景層，每格一模一樣）、
      特效（角色後面的光、最上面的火花光環閃電花瓣光點、整張的閃白變暗）。
    角色＋背景照 make_styles.py 的同一個函式換色（描邊、陰影、月光邊都跟著那一格的角色範圍算），
    特效分三種疊回去（每一種的濃度、時間都照原版）：
      淡的光暈（濃度 < SOFT）：先照在原色畫面上，再跟角色背景一起換色（直接畫成亮色會變硬邊圓盤）；
      亮的火花、閃電、光點、光環、花瓣：畫成那個造型自己的亮色或暖色（FXCOL），濃度收成 1/4 一階，像素感不會糊掉；
      整張的閃白、變暗：照原本濃度往造型的亮色、暗色混，不收階。
    背景層的特效（燈籠、星星、佛光）只畫在純背景上，不會蓋到描邊。

B 方案（2026-11-19）：招牌動作那幾格（煉氣男女是整條）換成 AI 影片縮回的像素格，跟 app 原版一樣。見 use_b_video。
影片格哪些是人蔘本體用 AI 去背（水桶修圖實驗/B_影片/video_matte.py，要先跑過），光另外平塗成造型的亮色，其他丟掉。

檢查（每條都跑，不過就丟例外）：
  - 拆層後照原本的疊法重組、收色，要跟原版 _anim96.png 每一格完全一樣（證明拆層沒改到動畫）。
  - B 方案：B6 要跟 app 裡的原版一樣；影片格用遮罩和沒疊特效的那份重組，要跟 B6 一樣。
  - 背景：角色範圍、描邊範圍（ZONE）、特效以外的格子，96 格都要等於「沒有角色的純背景」換色後的樣子。

用法：python make_style_anims.py [只做哪幾個代號，逗號分隔] [只做哪幾種造型，逗號分隔]
      python make_style_anims.py --check [造型,…]    產生檢查圖（動畫檢查/）
輸出：動畫_造型/{代號}-{造型}Anim.png，並放進 app 的 PortraitStyles/{代號}-{造型}Anim.imageset/
"""
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
PIX = HERE.parent
sys.path.insert(0, str(PIX))
sys.path.insert(0, str(HERE))
import animate as an          # noqa: E402
import make_styles as ms      # noqa: E402
import pixelate2 as px        # noqa: E402
from rig import GW, GH, N, COLS, GOLD, PALE, WHITE   # noqa: E402

FOLDER = HERE / "動畫_新去背"          # 動畫用的像素圖、閉眼圖、角色範圍、原版動畫
STATIC_SRC = PIX / "統一色盤"           # 靜態造型圖用的像素圖（跟 FOLDER 裡的是同一張，下面會比對）
OUT = HERE / "動畫_造型"
REPO = PIX.parent.parent
ASSETS = REPO / "ios" / "Rencan" / "Resources" / "Assets.xcassets"
APP_STYLES = ASSETS / "PortraitStyles"
APP_ORIG = ASSETS / "Portraits"
BDIR = PIX / "水桶修圖實驗" / "B_影片"     # B 方案影片格（見 use_b_video）
CODES = [f"{p}{i}" for p in ("r", "gr") for i in range(7)]
DIRECT = {"handheld", "chunky"}

# 特效換成的顏色：亮（白、淡黃、閃白）、暖（金、琥珀）、暗（變暗那幾格）。None ＝ 用原色（貼紙的角色本來就是原色）
FXCOL = {
    "ink": ("#FBF8F1", "#B23A2A", "#1E1B18"),      # 亮的留白像紙、金的用印泥紅
    "gold": ("#FFF0B8", "#EBC35A", "#120B05"),
    "moon": ("#E8EEFF", "#AFC3FF", "#05081A"),     # 月光是冷的，金也換成淡藍
    "puppet": ("#FFF1D0", "#FFC870", "#1C0804"),
    "sticker": None,
    "celadon": ("#C9D7F0", "#3A63B8", "#0E1E4E"),  # 白瓷上用淡青、金的換鈷藍
    "sunset": ("#FFF0C8", "#FFD27A", "#1E0E1E"),
    "neon": ("#D8FFFF", "#3FF2FF", "#07040F"),
    "jade": ("#DDF5E4", "#C9A24A", "#1A1014"),     # 金的跟頭上鑲金的紅果同色
}
# 描邊、陰影往角色外面長多少格（背景檢查要扣掉這一圈）
ZONE = {"ink": 0, "gold": 0, "moon": 0, "puppet": 0, "celadon": 0, "sunset": 0, "jade": 0,
        "neon": 7, "sticker": 8, "handheld": 1, "chunky": 3}

# 換色函式在動畫裡要多傳的參數：貼紙的陰影不要從左邊界繞出來（見 make_styles.style_sticker）
STYLE_KW = {"sticker": {"wrap_shadow": False}}

# 特效原本用的顏色（白、淡黃、金、琥珀），加上 2026-11-18 環境特效用的草、葉子、碎石、仙鶴、塵土等（animate.ENV_FX_KINDS）
KEYS = np.array([WHITE, PALE, GOLD, an.AMBER] + [c for c, _ in an.ENV_FX_KINDS], dtype=np.float32)
KEY_KIND = [0, 0, 1, 1] + [k for _, k in an.ENV_FX_KINDS]           # 0 亮、1 暖、2 暗
POST_KEYS = np.array([an.FLASH, [0, 0, 0]], dtype=np.float32)
POST_KIND = [0, 2]                                                  # 閃白當亮、變暗當暗


def hex3(h):
    return ms.hexs(h)[0]


def cells_of(path):
    im = Image.open(path)
    if im.size != (GW * COLS, GH * (N // COLS)):
        raise ValueError(f"{path} 尺寸 {im.size} 不對")
    a = np.asarray(im.convert("RGB")) if im.mode != "L" else np.asarray(im)
    return [a[(i // COLS) * GH:(i // COLS + 1) * GH, (i % COLS) * GW:(i % COLS + 1) * GW] for i in range(N)]


def u8(a):
    return np.clip(a, 0, 255).astype(np.uint8)


def zone_of(char, r):
    z = char if r == 0 else ndimage.binary_dilation(char, structure=np.ones((3, 3)), iterations=r)
    return ndimage.binary_fill_holes(z)


def map_fx(col, kind_keys, kinds, style):
    """特效每一格的顏色換成造型的顏色：找最接近的原色，看它是亮、暖還是暗。"""
    if FXCOL[style] is None:
        return col
    d = ((col[:, None, :] - kind_keys[None]) ** 2).sum(-1)
    k = np.array(kinds)[d.argmin(1)]
    table = np.array([hex3(h) for h in FXCOL[style]], dtype=np.float32)
    return table[k]


STEP = 4     # 火花、光暈的濃度收成 1/4 一階
SOFT = 0.5   # 濃度低於這個的算淡光暈，先照在原色畫面上再換色（見 render）


def blend(img, layer, where, style, post=False):
    """把一組特效 (T, C) 照原本的濃度疊上去，顏色換成造型的。回傳疊了特效的格子。
    火花、光暈（post=False）的濃度收成 0、1/4、1/2、3/4、1 五階：原版是收回色盤，這裡如果也收回造型那幾個顏色，
    淡淡的光暈會整片跳成別的顏色（皮影的腳下多一個暗色圓盤），所以改成一階一階往特效的顏色混，光暈像原版一樣一圈一圈。
    整張的閃白、變暗（post=True）照原本濃度混，不收：收的話整張會塌成一兩個顏色（皮影、霓虹閃白那格整片變平）。"""
    T, C = layer
    if np.abs(T - T[..., :1]).max() > 1e-4:
        raise ValueError("特效的濃度三個顏色不一樣，不是單純的混色")
    a = 1 - T[..., 0]
    col_all = C / np.maximum(a, 1e-6)[..., None]
    if not post:
        a = np.round(a * STEP) / STEP
    sel = where & (a > 1e-6)
    if not sel.any():
        return sel
    col = map_fx(col_all[sel], POST_KEYS if post else KEYS, POST_KIND if post else KEY_KIND, style)
    img[sel] = img[sel] * (1 - a[sel][:, None]) + col * a[sel][:, None]
    return sel


def load_code(code):
    rg, pal, A = an.build_rig(str(FOLDER), code)
    # 靜態造型圖用統一色盤的像素圖和 aimask；動畫用的要是同一份，第 0 格才會跟靜態圖一致
    rgb_s, mask_s = ms.load(code, STATIC_SRC)
    if not (np.asarray(rgb_s) == rg.base).all() or not (mask_s == A).all():
        raise ValueError(f"{code}：動畫用的像素圖或角色範圍跟靜態造型圖用的不一樣")
    pal_lab = px.rgb2lab(pal.astype(np.float32))
    q = lambda a: pal[px.nearest(px.rgb2lab(np.clip(a, 0, 255).reshape(-1, 3)), pal_lab).reshape(GH, GW)].astype(np.float32)
    orig = cells_of(FOLDER / f"{code}_anim96.png")
    L = [an.layers(rg, A, f) for f in range(N)]
    # 1. 拆層後重組，要跟原版一模一樣
    for f, l in enumerate(L):
        x = np.where(l["cover"][..., None], l["clean"], rg.bg * l["back"][0] + l["back"][1])
        x = x * l["front"][0] + l["front"][1]
        x = x * l["post"][0] + l["post"][1]
        bad = (q(x).astype(np.uint8) != orig[f]).any(-1).sum()
        if bad:
            raise ValueError(f"{code} 第 {f} 格：拆層重組跟原版差 {bad} 格")
    # 2. 角色範圍要跟 animate.py 存的 _anim96_mask.png 一樣
    saved = cells_of(FOLDER / f"{code}_anim96_mask.png")
    for f, l in enumerate(L):
        if not ((saved[f] > 127) == l["char"]).all():
            raise ValueError(f"{code} 第 {f} 格：角色範圍跟 _anim96_mask.png 不一樣，先重跑 animate.py")
    if not (rg.bg_alt == rg.bg).all():
        raise ValueError(f"{code}：閉眼那幾格的背景層跟平常不一樣，背景沒辦法每格固定")
    use_b_video(code, rg, A, q, orig, L)
    return dict(rg=rg, A=A, q=q, orig=orig, L=L, BG=q(rg.bg), rgb_s=rgb_s)


# 影片格裡不是人蔘本體的格子，跟背景差這麼多（Lab 距離）以上、又沒有比背景暗超過 GLOW_DARKER 的才算光（金光、光帶、雷光、劍光）。
# 差一點點的是影片把背景重畫得不太一樣，變暗的是影子、水漬，都丟掉（見 use_b_video）。
# 只看「比背景亮」不行：金丹女的金色光帶畫在淺色的天上，沒有比較亮，整條會不見（2026-11-21 試過）
GLOW_DIFF = 22
GLOW_DARKER = 10
GLOW_MIN_PIECE = 6     # 比這小的光當雜點丟掉
# 光佔到整格這麼多成，就是影片整片閃白的那一格（渡劫男被雷打中）：AI 在一片白裡認不出身體，
# 照上面的分法會是一大塊平塗的亮色蓋住半個人。這種格子角色改用原圖，整格蓋一層 FLASH_COVER 濃的亮色
FLASH_AREA = 0.25
FLASH_COVER = 0.75
# 煉氣男的影片把水桶從腰邊舉到肩上再潑出去，原本水桶擋住的石階、草地整片露出來。
# 背景層在那裡是補畫的一片淡色，跟影片畫出來的石階對不起來，亮一點的草地就被當成光、塗成亮色黏在衣襬旁邊
# （2026-11-21 多米在赤霞夕照圈出來的那幾塊）；右邊的燈籠、左邊的招牌被影片重畫得亮一點，也有幾條細的。
# 煉氣女的水桶一直提在原位，沒有露出這麼大一片，所以沒事。
# 這個代號的動作裡沒有光，只有水，所以多做兩件事（見 use_b_video）：
#   1. 「光」只留水色的。水是藍紫色（藍不比紅、綠低），殘塊是米黃或近白（藍比紅低 5 以上）。
#      量過 251 塊，兩群中間空著，門檻放在 WATER_BLUE
#   2. 程式動畫畫在人蔘原本站的範圍裡的特效不畫：那是水桶在腰邊時濺出來的三點水，影片裡桶已經舉走了
# 不能改成「落在原本範圍裡的光都丟」套到所有代號：金丹飛進丹田、元嬰、渡劫的雷光本來就畫在身體前面，
# 照丟會少一大塊（統計過，金丹男一格最多少 700 格）
WATER_ONLY = {"r0"}
WATER_BLUE = -3       # 一塊光的平均色，藍減掉紅綠裡大的那個，不低於這個才算水
OLD_SPOT_GROW = 2     # 原本的範圍往外多算幾格


def lab_of(rgb):
    return px.rgb2lab(np.asarray(rgb, dtype=np.float32).reshape(-1, 3)).reshape(GH, GW, 3)


def use_b_video(code, rg, A, q, orig, L):
    """B 方案（2026-11-19）：app 原版動畫的招牌動作換成 AI 影片縮回的像素格（video_splice.py 出的 _anim96_B6），付費造型也要跟著換。
    影片格拆不出零件，所以那幾格的角色範圍用 video_splice 另存的遮罩、沒疊特效的畫面用另存的 _B6_clean，
    背景照舊用 rg.bg（每格一樣）、特效照舊用 animate.layers() 給的，換色流程不用改。
    動畫_新去背/{代號}_anim96.png 是程式動畫，上面那兩個檢查要用它，不能拿 B6 蓋掉。
    原地改 orig 和 L 的影片那幾格；影片格另外多 glow（當成光、不描邊的格子）和 full（video_splice 的遮罩，不去背的造型用）。"""
    spec = json.loads((BDIR / f"{code}_B6.json").read_text(encoding="utf-8"))
    start, count = spec["start"], spec["frames"]
    if not (0 <= start and 0 < count and start + count <= N):
        raise ValueError(f"{code}_B6.json 的接格範圍不對：{spec}")
    sheet = cells_of(BDIR / f"{code}_anim96_B6.png")
    clean = cells_of(BDIR / f"{code}_anim96_B6_clean.png")
    mask = cells_of(BDIR / f"{code}_anim96_B6_mask.png")
    app = cells_of(APP_ORIG / f"{code}Anim.imageset" / f"{code}Anim.png")
    # 影片每一格的 AI 去背（video_matte.py）：一格裡角色佔幾成，過半才算
    matte = cells_of(BDIR / f"{code}_anim96_B6_aimask.png")
    bg_lab = lab_of(rg.bg)
    for f in range(N):
        if not (sheet[f] == app[f]).all():
            raise ValueError(f"{code} 第 {f} 格：{code}_anim96_B6.png 跟 app 裡的原版不一樣，先確認哪個才是對的")
        video = start <= f < start + count
        if not video and not (sheet[f] == orig[f]).all():
            raise ValueError(f"{code} 第 {f} 格：不是影片的格子，B6 卻跟程式動畫不一樣")
        if not video:
            continue
        img = clean[f].astype(np.float32)
        char = mask[f] > 127
        l = L[f]
        # 照 video_splice 的疊法重組，要跟 B6 一模一樣（證明沒疊特效的那份和遮罩是對的）
        Tb, Cb = l["back"]
        x = np.where(char[..., None], img, img * Tb + Cb)
        x = x * l["front"][0] + l["front"][1]
        x = x * l["post"][0] + l["post"][1]
        bad = (q(x).astype(np.uint8) != sheet[f]).any(-1).sum()
        if bad:
            raise ValueError(f"{code} 第 {f} 格：影片格拆層重組跟 B6 差 {bad} 格")
        # video_splice 的遮罩是「跟背景層不一樣的格子」，影片的光、水花、影子、被重畫得不太一樣的背景都在裡面。
        # 全部當角色的話：光被描邊補洞變成一大塊色塊（2026-11-19）；背景的殘塊換色後黏在人蔘旁邊，
        # 赤霞夕照最明顯（2026-11-21 多米真機看到「沒去背乾淨」）。所以分三種：
        #   身體：AI 去背說是角色的。這一格跟原圖一樣的格子（還沒動、收尾換回原圖的）直接用原圖的角色範圍，
        #         跟程式動畫那幾格才接得起來
        #   光（glow）：不是身體、跟背景差很多又沒有變暗的。用造型的角色配色上色，不描邊、不補洞（見 paint）
        #   其他：背景被影片畫得不太一樣而已，丟掉，換色時那裡就是造型的底
        same = (clean[f] == rg.base).all(-1)
        wanted = np.where(same, A, matte[f] >= 128)
        # AI 去背說是角色、顏色卻跟背景層一樣的格子（char 是「跟背景層不一樣」）：
        #   在人蔘原本站的範圍（A）裡的算身體：白袍疊在白雲上、金丹飛進丹田最亮那一點，顏色都跟背景一樣，
        #   不算的話袍子和身體正中央會破洞，底色一點一點透出來
        #   不在 A 裡的，整塊被角色包住才算；碰得到角色外面的不算
        #   （化神女背後的月亮、元嬰女法杖旁的雲，AI 會多拿，那些本來就是沒動的背景）
        body = wanted & (char | A)
        same_as_bg = wanted & ~body
        blobs, n = ndimage.label(same_as_bg)
        if n:
            near_outside = ndimage.binary_dilation(~wanted, structure=np.ones((3, 3)))
            open_blobs = np.unique(blobs[near_outside & same_as_bg])
            body |= same_as_bg & ~np.isin(blobs, open_blobs)
        pieces, n = ndimage.label(body, structure=np.ones((3, 3)))
        if n:
            sizes = ndimage.sum(body, pieces, range(1, n + 1))
            body &= np.isin(pieces, [i + 1 for i, s in enumerate(sizes) if s >= an.CHAR_MIN_PIECE])
        away = lab_of(img) - bg_lab
        other = char & ~body & (away[..., 0] > -GLOW_DARKER)
        glow = other & (np.linalg.norm(away, axis=-1) > GLOW_DIFF)
        # 光帶是半透明的，收色後深深淺淺，照門檻切會切成一圈碎點：先把一格寬的缺口接起來，再丟掉太小的碎點
        glow = ndimage.binary_closing(glow, structure=np.ones((3, 3))) & other
        pieces, n = ndimage.label(glow, structure=np.ones((3, 3)))
        if n:
            sizes = ndimage.sum(glow, pieces, range(1, n + 1))
            glow &= np.isin(pieces, [i + 1 for i, s in enumerate(sizes) if s >= GLOW_MIN_PIECE])
        if code in WATER_ONLY:
            pieces, n = ndimage.label(glow, structure=np.ones((3, 3)))
            if n:
                idx = range(1, n + 1)
                r, g, b = (ndimage.mean(img[..., k], pieces, idx) for k in range(3))
                glow &= np.isin(pieces, [i + 1 for i in range(n) if b[i] - max(r[i], g[i]) >= WATER_BLUE])
            # 提把中間的洞也算進去：三點水花中間那一點剛好落在洞裡
            old = ndimage.binary_fill_holes(ndimage.binary_dilation(A, iterations=OLD_SPOT_GROW))
            gone = (old & ~body)[..., None]
            Tf, Cf = l["front"]
            l = dict(l, front=(np.where(gone, 1.0, Tf).astype(Tf.dtype), np.where(gone, 0.0, Cf).astype(Cf.dtype)))
        # 影片格沒有零件，被角色蓋住的就是角色本身（背景層的特效畫不到這裡，跟 video_splice 一樣）
        L[f] = dict(l, clean=img, char=body, glow=glow, full=char, cover=char)
        if glow.sum() > FLASH_AREA * GH * GW:
            L[f] = dict(l, clean=rg.base.astype(np.float32), char=A.copy(), glow=np.zeros((GH, GW), bool),
                        full=char, cover=char, flash=FLASH_COVER)
        orig[f] = sheet[f]


def render(d, style):
    """回傳 96 格（uint8）、每格疊了特效的格子、每格的描邊範圍，以及純背景。"""
    fn = ms.STYLES[style]
    L = d["L"]
    zones = [zone_of(l["char"], ZONE[style]) for l in L]
    if style in DIRECT:
        kw = {}
        if style == "chunky":
            kw["palette"] = ms.chunky_small(d["rgb_s"]).quantize(colors=20, method=Image.Quantize.MEDIANCUT)
        pure = u8(fn(d["BG"], np.zeros((GH, GW), bool), **kw))
        frames, fxs = [], []
        for f, l in enumerate(L):
            fx = (l["back"][0][..., 0] < 1 - 1e-6) & ~l["cover"] | (l["front"][0][..., 0] < 1 - 1e-6) | (l["post"][0][..., 0] < 1 - 1e-6)
            # 原版動畫裡，零件外面多切的那一圈背景色會跟著葉子、道具動（離角色最多兩格）；換成固定的背景層，背景才每格一樣
            # 這兩種不去背，影片格裡跟背景不一樣的整塊都留著（水花、影子也是畫面的一部分）
            fx = fx | (l.get("full", l["char"]) & ~l["char"])
            rin = d["orig"][f].astype(np.float32)
            keep = l["char"] | fx
            rin[~keep] = d["BG"][~keep]
            frames.append(u8(fn(rin, l["char"], **kw)))
            if style == "chunky":     # 縮一半再放大：一格特效會影響同一塊 2×2
                fx = ndimage.binary_dilation(fx, structure=np.ones((3, 3)), iterations=2)
            fxs.append(fx)
        return frames, fxs, zones, pure
    kw = STYLE_KW.get(style, {})
    pure = u8(fn(d["BG"].copy(), np.zeros((GH, GW), bool), **kw))
    ALL = np.ones((GH, GW), bool)
    frames, fxs = [], []
    for l in L:
        char, glow = l["char"], glow_of(l)
        rin = np.where((char | glow)[..., None], d["q"](l["clean"]), d["BG"])
        img = paint(fn, rin, char, glow, kw, style)
        bgonly = (u8(img) == pure).all(-1) & ~char      # 純背景：背景層的特效只畫在這裡，不蓋到描邊
        (Tb, Cb), (Tf, Cf) = l["back"], l["front"]
        ab, af = 1 - Tb[..., 0], 1 - Tf[..., 0]
        # 淡的光暈（燈籠、腳下的雷光、佛光、背後的光）當成光照在原色的畫面上，再跟角色背景一起換色：
        # 直接畫成造型的亮色會變成一塊硬邊的圓盤、一閃一閃（渡劫腳下、水墨變成紅圓盤）
        soft_b = ~l["cover"] & (ab > 1e-6) & (ab < SOFT)
        soft_f = (af > 1e-6) & (af < SOFT)
        if soft_b.any() or soft_f.any():
            pre = rin.copy()
            pre[soft_b] = pre[soft_b] * Tb[soft_b] + Cb[soft_b]
            pre[soft_f] = pre[soft_f] * Tf[soft_f] + Cf[soft_f]
            img = paint(fn, pre, char, glow, kw, style)
        # 亮的（火花、閃電、光點、光環、花瓣）照原本的濃度畫成造型的亮色
        s1 = blend(img, l["back"], bgonly & (ab >= SOFT), style)
        s2 = blend(img, l["front"], af >= SOFT, style)
        s3 = blend(img, l["post"], ALL, style, post=True)
        flash = l.get("flash", 0)
        if flash:     # 影片整片閃白的那一格（見 use_b_video）
            bright = an.FLASH if FXCOL[style] is None else hex3(FXCOL[style][0])
            img = img * (1 - flash) + bright * flash
            s3 = ALL
        frames.append(u8(img))
        fxs.append(soft_b | soft_f | s1 | s2 | s3 | glow)
    return frames, fxs, zones, pure


def glow_of(l):
    """影片格當成光的格子（use_b_video）；程式動畫的格子沒有。"""
    return l.get("glow", np.zeros((GH, GW), bool))


def paint(fn, rin, char, glow, kw, style):
    """角色＋背景換色，描邊、陰影、補洞都只照身體算（光算進角色的話，金丹女那圈光帶會被補成實心的一大塊）。
    光（glow）的格子平塗成造型自己的亮色（FXCOL 的第一個，跟程式動畫的火花、閃白同一個顏色）。
    原本是照角色的配色、依明暗上色，光帶深深淺淺像沒去乾淨的殘塊；分亮色暖色兩種塗也試過，
    水墨的光帶邊緣會冒出一點一點印泥紅，像髒點（2026-11-21）。
    貼紙的角色是原色，光也留原色。不能當背景換：貼紙、皮影、金箔的背景是固定色，光會整個不見。"""
    img = fn(rin.copy(), char.copy(), **kw).astype(np.float32)
    if not glow.any():
        return img
    if FXCOL[style] is None:
        img[glow] = rin[glow]
        return img
    img[glow] = hex3(FXCOL[style][0])
    return img


def verify(code, style, frames, fxs, zones, pure):
    """背景（角色、描邊、特效以外）每一格都要等於純背景。回傳 (檢查到的背景格數合計, 96 格都沒被角色和特效碰過的格數)。"""
    total = 0
    never = np.ones((GH, GW), bool)
    for f in range(N):
        bgm = ~zones[f] & ~fxs[f]
        bad = (frames[f][bgm] != pure[bgm]).any(-1).sum()
        if bad:
            raise ValueError(f"{code}-{style} 第 {f} 格：背景有 {bad} 格跟純背景不一樣")
        total += bgm.sum()
        never &= bgm
    stack = np.stack(frames)
    if (stack[:, never] != stack[0:1, never]).any():
        raise ValueError(f"{code}-{style}：從沒被角色和特效碰過的背景格子，96 格不一樣")
    return int(total), int(never.sum())


def save_sheet(frames, path):
    sheet = an.sheet_of(frames)
    cols = np.unique(sheet.reshape(-1, 3), axis=0)
    if len(cols) <= 256:
        # 顏色不多就存成色盤圖（跟原版一樣），檔案小很多；存完讀回來比對，一格都不能變
        key = sheet[..., 0].astype(np.int64) * 65536 + sheet[..., 1].astype(np.int64) * 256 + sheet[..., 2]
        ck = cols[:, 0].astype(np.int64) * 65536 + cols[:, 1].astype(np.int64) * 256 + cols[:, 2]
        idx = np.searchsorted(ck, key).astype(np.uint8)
        im = Image.fromarray(idx, "P")
        im.putpalette(cols.reshape(-1).tolist())
    else:
        im = Image.fromarray(sheet, "RGB")
    im.save(path, optimize=True)
    back = np.asarray(Image.open(path).convert("RGB"))
    if not (back == sheet).all():
        raise ValueError(f"{path} 存檔後讀回來不一樣")
    return len(cols)


def install(code, style, src):
    """放進 app：Contents.json 照原版 {代號}Anim.imageset 的寫法，只換檔名。"""
    name = f"{code}-{style}Anim"
    ref = json.loads((APP_ORIG / f"{code}Anim.imageset" / "Contents.json").read_text(encoding="utf-8"))
    files = [im for im in ref["images"] if "filename" in im]
    if len(files) != 1:
        raise ValueError(f"原版 {code}Anim 的 Contents.json 不是只有一張圖")
    files[0]["filename"] = f"{name}.png"
    d = APP_STYLES / f"{name}.imageset"
    d.mkdir(exist_ok=True)
    shutil.copyfile(src, d / f"{name}.png")
    raw = (APP_ORIG / f"{code}Anim.imageset" / "Contents.json").read_text(encoding="utf-8")
    text = raw.replace(f'"{code}Anim.png"', f'"{name}.png"')
    if json.loads(text) != ref:
        raise ValueError("Contents.json 換檔名失敗")
    (d / "Contents.json").write_text(text, encoding="utf-8", newline="")


CHECK = HERE / "動畫檢查"
PICK = [0, 12, 24, 36, 48, 60, 72, 84]
CHECK_CODES = ["r1", "r3", "r5", "gr0", "gr2", "gr4", "gr6"]   # 男女各至少三個境界（另外 r2、r6 在總覽裡看）


def check_sheets(styles, codes=CHECK_CODES):
    """逐格放大檢查圖：每種造型挑幾個境界，抽 0、12…84 格放大五倍排成 4×2；再每種造型拼一張十四條第 0 格＋第 40 格的總覽。"""
    from PIL import ImageDraw
    CHECK.mkdir(exist_ok=True)
    S, G = 5, 10
    for style in styles:
        for code in codes:
            cells = cells_of(OUT / f"{code}-{style}Anim.png")
            im = Image.new("RGB", (4 * (GW * S + G) - G, 2 * (GH * S + G + 24) - G), (40, 40, 40))
            d = ImageDraw.Draw(im)
            for k, f in enumerate(PICK):
                x, y = (k % 4) * (GW * S + G), (k // 4) * (GH * S + G + 24)
                d.text((x + 4, y + 6), f"{code}-{style}  frame {f}", fill=(255, 255, 255))
                im.paste(Image.fromarray(cells[f]).resize((GW * S, GH * S), Image.NEAREST), (x, y + 24))
            im.save(CHECK / f"{style}_{code}_x5.png", optimize=True)
        im = Image.new("RGB", (7 * (2 * GW + 4 + G) - G, 2 * (GH + 20 + G)), (40, 40, 40))
        d = ImageDraw.Draw(im)
        for row, prefix in enumerate(("r", "gr")):
            for i in range(7):
                code = f"{prefix}{i}"
                cells = cells_of(OUT / f"{code}-{style}Anim.png")
                x, y = i * (2 * GW + 4 + G), row * (GH + 20 + G)
                d.text((x + 2, y + 4), f"{code}  f0 | f40", fill=(255, 255, 255))
                im.paste(Image.fromarray(cells[0]), (x, y + 20))
                im.paste(Image.fromarray(cells[40]), (x + GW + 4, y + 20))
        im.save(CHECK / f"總覽_{style}.png", optimize=True)
        print("check", style, flush=True)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        check_sheets(sys.argv[2].split(",") if len(sys.argv) > 2 else list(ms.STYLES))
        return
    codes = sys.argv[1].split(",") if len(sys.argv) > 1 and sys.argv[1] else CODES
    styles = sys.argv[2].split(",") if len(sys.argv) > 2 else list(ms.STYLES)
    for s in styles:
        if s not in ms.STYLES:
            raise KeyError(s)
    OUT.mkdir(exist_ok=True)
    report = {}
    for code in codes:
        d = load_code(code)
        for style in styles:
            frames, fxs, zones, pure = render(d, style)
            checked, never = verify(code, style, frames, fxs, zones, pure)
            out = OUT / f"{code}-{style}Anim.png"
            ncol = save_sheet(frames, out)
            install(code, style, out)
            static = np.asarray(Image.open(APP_STYLES / f"{code}-{style}.imageset" / f"{code}-{style}.png").convert("RGB"))
            diff0 = float((frames[0] != static).any(-1).mean())
            report[f"{code}-{style}"] = dict(bytes=out.stat().st_size, colors=ncol, bg_checked=checked, bg_never_touched=never,
                                             fx_px=int(sum(f.sum() for f in fxs)), frame0_vs_static=round(diff0, 4))
            print(code, style, report[f"{code}-{style}"], flush=True)
        # 每個代號一份報告（可以分幾個程式同時跑不同代號，不會互相蓋掉）
        (OUT / "報告").mkdir(exist_ok=True)
        part = {k: v for k, v in report.items() if k.startswith(code + "-")}
        (OUT / "報告" / f"{code}.json").write_text(json.dumps(part, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
