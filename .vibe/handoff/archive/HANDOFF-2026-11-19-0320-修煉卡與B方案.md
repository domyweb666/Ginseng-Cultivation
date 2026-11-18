# Handoff: 印章改「境」、雷達圖改直寫、修煉卡做進 app、水桶破圖試了 A 與 B（多米選 B）

> 產出時間：2026-11-19 03:20。分支 main，本機領先 origin/main 六個 commit，沒推 main。
> 同樣六個 commit 已推到 `work/share-card-radar` 跑 iOS check（run 44379370510），交接時還在跑。
> 上一份交接（環境特效）備份在 `.vibe/handoff/archive/HANDOFF-2026-11-18-2254-環境特效.md`，裡面的待辦大多還在，見下面「還沒做完」。

## ✅ 這次完成了什麼

- 境界碑紅印章七個境界都刻「境」（`SteleView.swift` 的 `sealGlyph`）。
- 功法雷達：功法名改直寫，每個名字照方向推到字框剛好不碰外圈，半徑與圖高由字級算（`MoveRadar.swift` 的 `RadarLayout`）；下面那句改成「內 ○○○○○ 外」刻度條（`GongView.swift` 的 `levelScale`）。字級常數 `RencanType.radarLabelSize`。
- 修煉卡做進 app（多米選甲版＋頁首右上角＋分享附一句話）：
  - `Views/Share/ShareCard.swift`：卡本身（360×640 點，`ImageRenderer` 放大 3 倍成 1080×1920）與 `ShareCardContent`（從 Digest 算字）。
  - `Views/Share/ShareCardSheet.swift`：預覽、道號（存 `UserSettings.daoName`，最多 8 字）、體脂開關、存到相簿（只要加入照片權限）、`ShareLink` 圖加一句話；`ShareCardButton` 放在境界頁、分析頁頁首右上角，沒量過時不出現。
  - 新增 8 個固定色 `Card*`／`OnCardBand` colorset、`RencanType.cardDisplay/cardText`、`AppFlow.Sheet.shareCard`、Info.plist 加 `NSPhotoLibraryAddUsageDescription`、架構藍圖加兩行、產品定稿把「社群分享卡」移出不做清單。
- 水桶破圖兩個方案都試了，都還沒換進 app：
  - A（`.uiux/像素風立繪/水桶修圖實驗/fix_r0.py`）：Codex 乾淨背景、Codex 補桶後衣襬、桶用 RotSprite 預先轉好每 3 度一張、草屑改 2 格放角色後面。
  - B（`水桶修圖實驗/B_影片/video_to_pixels.py`）：MiniMax H3 圖生影片 5 秒（首尾都是原圖），每 0.15 秒取一張縮回 168×210 收色盤，「動過的範圍」整塊用影片、靠近原圖的格子貼回原圖防閃。多米說 B「超出預期，好很多」。
- 選項頁（都在 `.uiux/介面選項-2026-11-19/`）：雷達圖排法、設定頁規劃（已補官網／臉書／IG 頁尾）、分享卡選項、分享流程預覽。

## 🚧 還沒做完／待決定

- **CI 結果還沒看**：`gh run view 44379370510`（或 `gh run list --branch work/share-card-radar`）。雷達圖與修煉卡在這台 Windows 沒編譯過，第一次編譯就在這一輪。紅了就修、推同一個分支再跑。
- **B 方案要做 14 張**，等多米在 https://higgsfield.ai 買點數（帳號現在 0 點、免費方案）。建議下一步：
  - 一支直接生 15 秒（0–5 秒呼吸晃葉、5–10 秒招牌動作、10–15 秒放回原姿勢），首尾都放原圖，縮成 96 格把 15 秒平均攤開（播起來快不到 4%）。不要 0.5 倍慢放。
  - 先用煉氣男同時試 MiniMax H3（15 秒 30 點，只有 2K）和 Seedance 2.0 Mini（480p 15 秒 7.5 點），比完再決定 14 張用哪個。H3 全做約 420 點、Mini 約 105 點。
  - 已知問題：共用 72 色盤沒有淡藍，水花縮回來變淡紫；付費造型（換色）跟 B 能不能接還沒試；招牌動作沒辦法逐格指定時間點。
- **設定頁照共用規格重排還沒動程式**：`設定頁規劃.html` 最下面 7 件要多米決定（VeggieKit 先寫在 app 裡、其他 app 清單寫死不連網、清除所有資料要不要連身高性別、匯出檔名格式、意見回饋信箱、隱私權政策網址、分享一句話介紹）。設定頁「分享給朋友」那一列等這次重排一起做。
- **修煉卡上架後要補**：App Store Apple ID 拿到後，`ShareCardContent.shareMessage` 換成下載連結、卡右下角補 QR 碼。
- 上一份交接留下、這次沒碰的：環境特效多米還沒在手機實際大小看過；push main 會出 TestFlight，要等多米開口（最後一個 commit 帶 [skip ci] 時整次不跑）；上架狀態（1.0（34）已送審？）開工前先問。
- 沒 commit 的東西照舊沒動：`分層動畫實驗/fx.py`、`A-pose對照/`、`環境特效預覽/`、`造型風格/動畫_造型/`、`動畫檢查/`、`介面選項-2026-11-18/`。

## 📌 關鍵決策（別再爭）

- 印章七境都刻「境」。
- 雷達圖：功法名全直寫（丙）＋刻度條（1）。
- 修煉卡：甲版（道號、境界、立繪、宗門一條、三格數字、最高六門功法）；入口在境界頁、分析頁頁首右上角（一）；分享時圖加一句話（A）。卡上不放體重，體脂可關。
- 立繪動畫走 B（AI 圖生影片再縮回像素），A 當備案。
- `標準清單.md` 裡舊切片寫的「不准加分享卡、QR 碼、道號」是那幾片的紀錄，不改；現行規則看產品定稿。

## 📂 下個會話最重要的檔案

- `.vibe/安全標準.md` ← 下一個會話必讀（相簿權限、分享內容不夾體重都跟它有關）
- `ios/Rencan/Views/Share/ShareCard.swift`、`ShareCardSheet.swift`
- `ios/Rencan/Views/Gong/MoveRadar.swift`、`GongView.swift`
- `.uiux/像素風立繪/水桶修圖實驗/B_影片/video_to_pixels.py`（B 的縮回像素流程，參數 MOVED、STICKY、REGION_GROW 寫在檔頭）
- `.uiux/介面選項-2026-11-19/設定頁規劃.html`（7 件待決定）

## ⏭️ 下一步從哪繼續

1. 跑 `gh run list --branch work/share-card-radar --limit 1` 看 CI。
   - 綠：跟多米說雷達圖與修煉卡編譯過了，問要不要推 main 出 TestFlight（推之前確認最後一個 commit 不帶 [skip ci]）。
   - 紅：`gh run view <id> --log-failed` 看錯，在 main 修、commit，再 `git push origin main:refs/heads/work/share-card-radar` 重跑。
2. 多米買好點數後，照上面「B 方案」那段先拿煉氣男跑 15 秒兩個模型的對照。上傳與生成的做法：`media_upload` → curl PUT → `media_confirm` → `generate_video`（start_image、end_image 都放同一張 `給多米/煉氣男_放大6倍_1008x1260.png`）→ `jobs_wait` → 下載 mp4 → `ffmpeg` 抽格 → 改 `video_to_pixels.py` 讀新檔（15 秒要改成攤成 96 格，不是嵌在第 18 格起）。

## 🗑️ 雜訊（別再討論）

- 0.5 倍慢放：提桶和水花會變慢動作，不做。
- 分享卡乙版（小雷達）、丙版（深色卡）與按鈕位置二、三：多米選了甲＋一，不用再比。
- B 第一版縮回像素時逐格挑原圖或影片，會出現頭疊影、桶碎掉、舊桶留在原地；已改成「整塊範圍＋貼回原圖」，別再走回頭路。
- Higgsfield 那 10 點已經用完在 B 的第一支影片上。
