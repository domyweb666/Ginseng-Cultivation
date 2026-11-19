# Handoff: 設定頁照共用規格重排並接上 VeggieKit、B 方案 14 張立繪動畫換進 app

> 產出時間：2026-11-19 09:14。分支 main，本機領先 origin/main 16 個 commit，**沒推 main**（多米說先不要，所以還沒出 TestFlight）。
> 同樣內容已推到 `work/share-card-radar`，最後一輪 CI（run 44430906674，commit eefc88f）全綠。
> 上一份交接備份在 `.vibe/handoff/archive/HANDOFF-2026-11-19-0320-修煉卡與B方案.md`。

## ✅ 這次完成了什麼

- 修上一輪 CI 紅燈：雷達圖改直寫變高，拔山式卡停在懸浮分頁列底下，UI 測試點到分頁列。修測試（`DemoUITests.swift` 點卡前確認卡在分頁列上方）。
- 建 VeggieKit 套件：把蒜日子、豆鍵兩份 `App/Veggie/` 合成一包，推到 github.com/domyweb666/VeggieKit（本機在 `E:\VeggieKit`），改公開、打 tag 1.0.0。顏色字體由 app 傳 `VeggieStyle`。
- 設定頁照蔬菜家族共用規格重排：身體、立繪造型、健康 app、提醒 → 一般（外觀、通知、觸覺回饋）→ 資料（匯出資料、匯入資料、清除所有資料）→ 購買（恢復購買）→ 支援（意見回饋、分享給朋友）→ 關於（其他 app、隱私權政策、開源授權）→ 頁尾。「權限」區拿掉。
  - 人蔘修煉的名字、信箱、網址、色票都在 `ios/Rencan/App/VeggieSetup.swift`。專案檔鎖 VeggieKit exactVersion 1.0.0。
  - 清除所有資料：問兩次（第一次附「先匯出」），連身高性別設定一起清，回到第一次打開那頁；不跳小提示。
  - 匯出檔名改成「人蔘修煉-備份-日期.json」，內容格式不變。
  - 藍圖、安全標準登記 VeggieKit 例外；隱私清單補 UserDefaults 理由 CA92.1。
- 立繪 B 方案（AI 影片縮回像素）14 張全做完並換進 app 的原版造型（`Assets.xcassets/Portraits/{代號}Anim`）：
  - 12 張：H3 生 6 秒招牌動作，接進程式動畫第 0 到 43 格（金丹女接第 19 到 54 格，因為她左右晃、每 12 格才回中間）。最後 4 格逐步換回原圖像素。
  - 煉氣男、煉氣女：整條 96 格都用 15 秒影片（多米嫌程式晃的桶子、褲子不自然）。
  - 金丹男改「金丹飛進丹田、全身發金光」，金丹女改「金丹繞身拖金色光帶」（多米嫌原本太普通）。
- 修金丹女程式動畫的金丹：繞圈時原位留下一段棕色殘邊。`animate.py` 的 `core_mask` 加 `rim`，只用在金丹女；原版動畫與 11 種付費造型都重出、換進 app。

## 🚧 還沒做完／待決定

- **推 main 出 TestFlight**：多米說先不要。要推時先確認最後一個 commit 不帶 `[skip ci]`，再 `git push origin main`。
- **11 種付費造型還沒接 B 方案**：`PortraitStyles/{代號}-{造型}Anim` 還是程式動畫版，選付費造型的人看到的招牌動作跟原版不一樣（例如金丹男付費版還在拋接）。卡在 `造型風格/make_style_anims.py` 是靠 `animate.layers()` 一格一格拆角色、背景、特效再換色，還會檢查拆完要跟 `動畫_新去背/{代號}_anim96.png` 一模一樣；影片格拆不出零件。要改成：影片那幾格用 `video_splice.py` 另出的遮罩（`{代號}_anim96_B6_mask.png`）當角色範圍、背景用 `rg.bg`，而且要先拿到「沒疊特效」的影片格。**`動畫_新去背/{代號}_anim96.png` 不要用 B6 覆蓋**，換色程式的檢查會壞。
- **評分那一列與分享連結**：等多米給 App Store 的 Apple ID（App Store Connect → App 資訊，一串數字），填進 `VeggieSetup.swift` 的 `appStoreID`；修煉卡 `ShareCardContent.shareMessage` 也一起換成下載連結。
- **規劃頁建議過、這次沒做**：突破境界後跳系統評分小視窗。多米沒提，沒做。
- **已知小問題**：
  - 共用色盤沒有淡藍，水花、化神男的流星縮回來偏紫。
  - 化神女影片段的夜空星點比較多，接回程式動畫時天空閃一下。
  - 煉氣男 15 秒版提桶時插腰的手會離開腰、兩手捧桶（手還是兩隻，多米還沒表示意見）。
  - 煉氣女「踮兩下」不明顯。
- 上上份交接留下沒碰的：環境特效多米還沒在手機實際大小看過；上架狀態（1.0（34）審核）開工前先問。
- 蒜日子、豆鍵還是各自的 `App/Veggie/`，沒改用 VeggieKit（是它們自己 repo 的事，沒動）。
- 沒 commit 的照舊沒動：`分層動畫實驗/fx.py`、`A-pose對照/`、`環境特效預覽/`、`造型風格/動畫_造型/`、`動畫檢查/`、`介面選項-2026-11-18/`。

## 📌 關鍵決策（別再爭）

- VeggieKit 現在就拆成自家套件、公開 repo、鎖版本；其他 app 清單寫死不連網；清除所有資料照規格全清；匯出只改檔名；1.0 隱私權政策維持 domyweb.org/rencan/privacy；回饋信箱 charlie@domyweb.org；一句話介紹「量完體組成，看你練到哪個境界」。
- 立繪動畫走 B，用 MiniMax H3（Seedance 2.0 Mini 會重畫第一格，淘汰）。
- H3 一個動作 4 到 5 秒就做完：招牌動作只生 6 秒（12 點）；只有要整條都用影片的才生 15 秒（30 點）。不把短片攤長（會變慢動作）。
- 指令一定寫死「哪隻手全程不動」，不然會多長一隻手（煉氣男第一版三隻手的教訓）。
- 出場那一格差 5000 格以上是程式動畫本來的呼吸（整個人上下 1 格），原版每輪都有，不是接壞。

## 📂 下個會話最重要的檔案

- `.vibe/安全標準.md` ← 下一個會話必讀（VeggieKit 例外、意見回饋信不夾健康數值都跟它有關）
- `ios/Rencan/App/VeggieSetup.swift`、`ios/Rencan/Views/Settings/`（SettingsGeneral／Data／Support／AboutSection）
- `.uiux/像素風立繪/水桶修圖實驗/B_影片/video_splice.py`（接檔，參數：影片 代號 [START] [格數]）、`splice_all.py`、`14張招牌動作.md`、`十四張_B6_一輪.gif`
- `.uiux/像素風立繪/造型風格/make_style_anims.py`（付費造型要接 B 就改這支）
- `.uiux/像素風立繪/animate.py`（程式動畫；`core_mask` 的 `rim`）

## ⏭️ 下一步從哪繼續

1. 先問多米：要不要推 main 出 TestFlight？要的話確認最後一個 commit 不帶 `[skip ci]` 再 `git push origin main`。
2. 多米要付費造型也換成 B 方案的話：改 `make_style_anims.py`，讓影片格（第 START 到 START+格數-1，煉氣男女是全部 96 格）改用 `{代號}_anim96_B6_mask.png` 當角色範圍、`rg.bg` 當背景、`animate.layers()` 給的特效疊回去；`video_splice.py` 要先另存一份「沒疊特效」的影片格給它用。先拿金丹男＋青花瓷（celadon）試一張，過了再跑 14 × 11。
3. 多米給了 Apple ID 就填 `VeggieSetup.swift` 的 `appStoreID`，修煉卡分享那句一起換。

## 🗑️ 雜訊（別再討論）

- 15 秒影片平均攤成 96 格、0.5 倍慢放：都會變慢動作，不做。
- Seedance 2.0 Mini：第一格整張重畫，對不上原圖，淘汰。
- 單手版 A 影片開頭有黑底圓形轉場，丟掉。
- 原始影片 `*_6s_raw.mp4`、`*_15s_raw.mp4` 約 60 MB 只留本機、不進 git（Higgsfield 紀錄也找得到）；`r0_6s_raw.mp4`、`h3_15s_raw.mp4` 例外有進 git。
- Higgsfield 帳戶剩 643 點。
