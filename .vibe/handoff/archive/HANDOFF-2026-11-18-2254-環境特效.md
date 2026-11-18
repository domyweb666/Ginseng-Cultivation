# Handoff: 待機動畫加上照背景配的環境特效，已換進 app 並 commit，還沒 push

> 產出時間：2026-11-18 22:54。分支 main，本機領先 origin 四個 commit（含這份交接），都沒 push。
> 上一份交接（分層動畫實驗）備份在 `.vibe/handoff/archive/HANDOFF-2026-11-18-2115-分層動畫.md`。

## ✅ 這次完成了什麼

A-pose 對照實驗（多米看完選了 app 原本的動畫，這條線先停）：
- 叫 Codex 把煉氣男重畫成 A-pose，木桶放旁邊。
- 同一張圖拆兩條路，用同一套 Rigby2D 骨架做待機動畫，做成三欄對照 GIF：
  - 路 A：see-through 拆圖層。
  - 路 B：Codex 生拆分部件表，再自動對位回全身圖。
- 東西都在 `.uiux/像素風立繪/分層動畫實驗/A-pose對照/`，有自己的 `說明.md`。
- 多米看完說「還是覺得原版的比較好」，要在 app 原本的動畫上加特效。

環境特效（commit `e6f1984`）：
- `animate.py` 加了「環境特效」一節：每個境界照自己背景裡有的東西配特效，表在那一節開頭的註解。
  - 煉氣：起風捲草屑、頭上葉子被吹歪，樹叢掉葉子。
  - 築基：出劍時腳邊揚塵，遠山、石階前有雲霧飄。
  - 金丹：仙鶴飛過，崖邊有雲霧飄。
  - 元嬰：腳下雲邊冒出雲絮。
  - 化神：星星加多，化神女加一顆流星，雲海有雲霧飄。
  - 大乘：大乘男金粉灑落，大乘女光輪的光芒輪流亮。
  - 渡劫：雨絲，雷劈時碎石彈起，起風吹歪葉子。
  - 14 張都有：動作空檔時紅果閃一下。
- 在正式資料夾 `造型風格/動畫_新去背/` 重出 14 條，放進 `ios/.../Portraits/`。
- 154 條付費造型動畫用 `造型風格/make_style_anims.py` 一起重出，放進 `PortraitStyles/`，內建檢查全過。
- 新特效的顏色在付費造型裡算亮、暖還是暗，寫在 `animate.ENV_FX_KINDS`，`make_style_anims.py` 的 `KEYS` 會讀它。
- 設 `NO_AMBIENT=1` 重出時，14 條跟加特效前的 app 一格不差（驗證過），所以招牌動作完全沒動。
- 記憶 `pixel-animation-follow-broll-motion.md` 補了這次的回饋：特效要照背景配、先列表給多米點頭。
- `layered-animation-experiment-2026-11.md` 補了 A-pose 對照的結論。

## 🚧 還沒做完／待決定

- 沒 push。多米說「先不要」。push 到 main 會跑 `ios.yml` 自動出新的 TestFlight。要等他開口。
- 多米還沒在手機實際大小下看過特效。霧比其他特效淡，是刻意的，但他可能會嫌看不出來。
- 下面這些都沒 commit，多米沒說要 commit：
  - `分層動畫實驗/A-pose對照/`（16 MB）
  - `環境特效預覽/`（16 MB，14 張前後對照 GIF 加一張總覽）
  - `分層動畫實驗/fx.py`（加了 `FX_CFG` 環境變數，只有 A-pose 實驗用得到）
- 上架那條線狀態不確定，開工前先問多米：
  - 2115 那份交接說「只差多米在網頁填四張表再送審」。
  - 記憶 `rencan-ios-project.md` 寫 1.0（34）已送審。
  - 指令在 `OVERNIGHT.md` 的「早上摘要」。

## 📌 關鍵決策（別再爭）

- 立繪動畫維持 app 原本的 `animate.py`，不換成 see-through／Rigby2D 分層那套。
- 特效每個境界不同，要看背景有什麼再配，不是每張都落葉。
- 起風只放在有風的場景（煉氣、渡劫），排在第 56 格（8.4 秒）。招牌動作都在前 48 格。
- 化神沒做月暈：背景沒有月亮，那兩彎黃色是葉尖。
- 霧畫成扁扁一團、底下帶陰影色。光暈收色後會消失，細長白線又像多米退過的風線。

## 📂 下個會話最重要的檔案

- `.uiux/像素風立繪/animate.py`：搜尋「環境特效（照每個境界的背景配）」那一節，位置常數都在那。
- `.uiux/像素風立繪/造型風格/make_style_anims.py`：付費造型動畫，`KEYS`、`KEY_KIND` 那段。
- `.uiux/像素風立繪/環境特效預覽/`：前後對照 GIF。
- `.uiux/像素風立繪/分層動畫實驗/A-pose對照/說明.md`

## ⏭️ 下一步從哪繼續

1. 先問多米兩件事：特效在手機上看起來怎樣、要不要 push 出 TestFlight。
2. 他要改哪張的特效：
   - 改 `animate.py` 環境特效那一節。
   - 在 `.uiux/像素風立繪` 底下跑 `python animate.py 造型風格/動畫_新去背 "" <代號>`。中間的空字串是檢查圖資料夾，不給的話第三個參數會被當成資料夾。
   - 把 `造型風格/動畫_新去背/<代號>_anim96.png` 複製到 `ios/Rencan/Resources/Assets.xcassets/Portraits/<代號>Anim.imageset/<代號>Anim.png`。
   - 在 `造型風格` 底下跑 `python make_style_anims.py <代號>`，它會自己放進 app。
3. 他說 push：注意本機領先 origin 四個 commit，最後一個（這份交接）標了 [skip ci]。最後一個 commit 有 [skip ci] 時整次推送都不跑 CI，不會出 TestFlight。所以先做一個不帶 [skip ci] 的 commit 墊在最後（例如更新這份交接），或改用 `gh workflow run ios.yml --ref main`，再 `git push origin main`。

## 🗑️ 雜訊（別再討論）

- A-pose 路 A 和路 B 誰好已經比完了：路 A 像素不會跑掉，路 B 部件對不準。多米選了原版，兩條都不用再做。
- 第一版 14 張統一套落葉，被退了，別再提。
- 生 GIF、做預覽的暫存檔在 scratchpad，重開機會不見，沒關係，預覽已經放進 `環境特效預覽/`。
- Bash 的 heredoc 太長（超過約 8 KB）會壞，長的修改腳本要先用 Write 存檔再跑。
