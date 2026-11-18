# Handoff: 分層動畫實驗（煉氣男）做完，下一步試「ChatGPT 拆部件」或「重畫成 T-pose」再用 Rigby2D 綁骨

> 產出時間：2026-11-18 21:15。分支 main。
> 上一份交接（上架只差多米在網頁填四張表再送審）備份在 `.vibe/handoff/archive/HANDOFF-2026-11-18-1945-上架.md`，那件事還沒完，見最後一節。

## ✅ 這次完成了什麼
- 試了一條新的立繪動畫流程，拿煉氣男做：Codex 拆背景與角色 → see-through 拆圖層 → 自己補切頭部 → Rigby2D 命令列綁骨、做待機動畫 → Python 畫特效 → 縮回 168×210 合成。
- 做了兩版：Codex 重畫版、原圖版。多米看的是原圖版，現在的成品是 `煉氣男_原圖版_像素_放大6倍.gif`。
- 依多米回饋改了六輪：
  - 特效不用 Rigby2D 粒子，改 `fx.py` 直接畫在像素格上。
  - 根鬚不擺。
  - 風線拿掉，只留飄過的草屑。
  - 修頭頂破圖：頭輪廓被分進葉子層，起風時被扯走。
  - 加大動作：葉子吹歪 13 度；5.6 秒掂一次水桶，手往上收進袖子 36 像素。
  - 桶放下後盪幾下，桶口濺水。
- 寫成可以重跑的腳本：`split_layers.py`、`rig_build.py`、`build.sh`、`fx.py`、`compose.py`、`make_psd.mjs`、`patch_rigby.py`，加上設定檔 `設定_原圖版.json`。
- 記憶新增 `layered-animation-experiment-2026-11.md`，並在 `pixel-animation-follow-broll-motion.md` 補了這次的回饋：細根鬚別轉、不要柔邊粒子、不要風線、亮背景特效要帶深色邊。Codex 額度那則改成「ChatGPT Go＋重置券」。

## 🚧 還沒做完／待決定
- 多米還沒對「動作加大」那版表態。最後一輪的 ask 是「這個幅度可以嗎？」，他沒回答就轉去下一個做法了。
- 實驗資料夾 `.uiux/像素風立繪/分層動畫實驗/`（32 MB）還沒 commit。多米沒說要 commit，別自己 commit。
- 動畫一輪 64 格，app 的格子圖是 96 格（12×8）。要換進 app 得先對齊格數，還沒做。

## ⏭️ 下一步從哪繼續（多米要的對照實驗，下一個對話做）
多米 21:20 講清楚的流程，是兩條路的對照實驗，不是二選一：
1. 從原圖開始（煉氣男：`給多米/煉氣男_放大6倍_1008x1260.png`）。
2. 讓 ChatGPT 拆成背景和角色。這次已經做過，可以直接沿用 `分層動畫實驗/素材/codex版/codex_背景.png`；角色要重畫，所以不必沿用角色圖。
3. 讓 ChatGPT 把角色重畫成好拆的姿勢，透明背景。我建議 A-pose：手往斜下張開 30 到 45 度，木桶不拿在手上、另外放旁邊。理由跟多米說過了：
   - 手不擋身體，兩條路都好拆。
   - 擺回扠腰、提桶的自然姿勢只要轉 30 度左右；T-pose 要轉將近 80 度，像素會鋸齒。
   - 多米還沒表態要 A-pose 還是 T-pose，開工前先問。參考圖是 `C:\Users\fcharlie\Downloads\萌系人參精靈T字站姿.png`。
4. 拿重畫好的同一張角色圖，分兩條路拆：
   - 路 A：see-through 拆圖層，照這次的 `split_layers.py` 做法補切頭部。
   - 路 B：再叫 ChatGPT 生一張「這隻角色的拆分部件」，透明背景，所有部件畫在同一張紙上，包含小物件（木桶，別的角色有劍等等）。拿回來後自己照連通區塊切開，對位回 A-pose 的位置，存成 PSD。
5. 兩條路都用 Rigby2D 綁骨做同一套待機動畫，並排做成對照 GIF，讓多米看哪條好。

開工前的準備：
- 先讀這份交接、`.uiux/像素風立繪/分層動畫實驗/說明.md`、記憶 `codex-cli-image-pipeline.md`。用 Codex 叫 ChatGPT 生圖的指令格式、resume 方式、`-m gpt-5.6-terra`、英文路徑工作資料夾，都在那則記憶裡。
- ChatGPT 直接出透明 PNG 可以用。我原本以為多米給的參考圖有殘邊，查過是看錯：完全透明的地方沒有顏色。
- 它的透明度有兩個特性：角色本身大多落在 225 到 254，邊緣有一圈很淡的半透明（透明度 1 到 30）。所以處理時要把透明度二值化，128 以上算實色。
- 路 B 的提示詞要寫清楚四件事：
  - 每個部件分開擺，不重疊，彼此留空白。
  - 被擋住的地方要畫完整，例如袖子裡那段手臂、葉子底下的頭頂。
  - 尺寸、畫風、顏色要跟重畫的那張一樣。
  - 部件清單：葉子連紅果、頭（含臉）、閉眼的臉或眼睛、左右根鬚、上衣、左手、右手（袖子和袖口以下的手分開）、雙腿、木桶。
- 路 B 最大的風險是對位：ChatGPT 生出來的部件大小、角度不一定跟全身圖對得上。要用全身圖逐塊比對，找位置和縮放，對不上就要寫出差多少。
- 兩條路的動畫都沿用這次的流程：`make_psd.mjs` → `rigby import-psd` → `rig_build.py` 加骨頭與關鍵影格 → render → `compose.py`＋`fx.py`。A-pose 多了一個動作：要先用骨頭把手轉回扠腰、提桶的姿勢。
- 生圖會用 Codex 額度，每張約 2.5 萬 token；這次總共要 2 到 3 張。開工前跟多米講一聲。

## 📌 關鍵決策（這次定下來的，別再爭）
- 特效不用 Rigby2D 粒子，一律在 168×210 格子上用 `rig.py` 的 dot、plus、glow 畫。
- 細長的部位（根鬚）不轉；會動的只有葉子、手、道具這種實心大塊。身體、衣服、頭不動，不上下跳，一格 0.15 秒，一輪 9.6 秒。
- 不畫風線，風用飄過的草屑、葉子表現。
- 手的動作用「袖口不動、手往上收進袖子」，不轉整隻手臂。
- 用原圖拆比讓 Codex 重畫好，角色大小和像素跟 app 一致。背景用 Codex 生的那張縮回 1008×1260，原本的「只有背景」是拉長像素補洞，不能用。

## 📂 下個會話最重要的檔案
- `.uiux/像素風立繪/分層動畫實驗/說明.md`：完整流程、修過的問題、重跑指令。
- `.uiux/像素風立繪/分層動畫實驗/split_layers.py`、`rig_build.py`、`fx.py`、`build.sh`、`設定_原圖版.json`
- `.uiux/像素風立繪/分層動畫實驗/素材/原圖版/`：十層圖層、see-through 原始輸出、Rigby2D 專案檔。
- `.uiux/像素風立繪/codex/chroma_compose.py`：洋紅底去背。
- `.uiux/像素風立繪/rig.py`、`animate.py`：app 現在的立繪動畫與特效工具。
- `C:\Users\fcharlie\Downloads\萌系人參精靈T字站姿.png`：多米給的 T-pose 參考。

## 🧰 環境（都在這次會話的 scratchpad，重開機可能不見）
- scratchpad：`C:/Users/fcharlie/AppData/Local/Temp/claude/eda59dc9cc016bc6/b0b70767-889b-4c28-9058-f9522ceab87b/scratchpad/`
  - `seethrough/`：repo 和 venv。uv 開 Python 3.12，torch 2.8 cu128，模型快取在 `~/.cache/huggingface`。
    - 跑法：`venv/Scripts/python.exe inference/scripts/inference_psd.py --srcp <png> --save_dir <dir> --save_to_psd --group_offload`
    - 要在 repo 根目錄跑，加 `PYTHONUTF8=1`。一張圖約 11 分鐘。
  - `rigby/src/`：Rigby2D 原始碼，已經 `npm install`，也裝了 playwright chromium。指令是 `node rigby/src/bin/rigby.js`。
  - `orig/`：原圖版的去背角色、背景、圖層、see-through 輸出。
  - `rig3/`：最新一次的 Rigby2D 工作檔與渲染格。
- scratchpad 不見的話：see-through 照 `說明.md` 最後一節重裝；Rigby2D 重新 clone，再 `npm install`、`npx playwright install chromium`。

## Rigby2D 踩過的坑（做新做法會再遇到）
- 座標換算：原點在畫布底部中央，y 往上。圖上 (px, py) → (px − W/2, H − py)。
- 骨頭的平移照父骨頭的方向算。父骨頭是 root 時，往上就是 y，正值。
- additive 粒子在透明底上渲不出來（反正不用了）。
- 命令列不能把圖層掛到別根骨頭上，要用 `patch_rigby.py` 改 `.rigby`（它是 ZIP）。
- 動畫的「顯示圖片」關鍵影格會蓋掉預設的隱藏設定。
- 渲染 20fps、每 3 格取 1 格，就是 0.15 秒一格。最後一張跟第一張一樣，要丟掉。
- GIF 存檔會把相鄰重複的格合併，抽格檢查前要先照 duration 展開，不然會對錯格。

## 上架那件事（另一條線，沒動）
- 照備份的上一份交接：多米要在 App Store Connect 網頁填四張表（App 隱私問卷、醫療器材聲明、兩份合規表），填完再跑 `gh workflow run asc.yml --ref main -f mode=submit -f build=34`。
- 根目錄 `OVERNIGHT.md` 的「早上摘要」有完整步驟。

## 🗑️ 雜訊（下次別再討論）
- see-through 換種子救不了人蔘頭：種子 7 連頭都沒認出來，直接報錯。
- Codex 版成品還是舊的 Rigby2D 粒子，沒重做，也不用再做。
- 「提把圈裡透出背景草叢」這件事照常理就該這樣，不是 bug。
