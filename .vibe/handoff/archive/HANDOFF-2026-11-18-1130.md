# Handoff: 付費造型補到原版加十一種、內購商品用 API 填好、出了 1.0（32）（33）、M1 換造型寫好在分支上等檢查線

> 產出時間：2026-11-18 11:20
> 一律在 `E:\人篸修煉` 工作（多米只用這個資料夾，不開 worktree）。現在切在分支 `work/portrait-styles`。
> 真相源是 `.vibe/切片帳本.md`（這次加了五筆，最後一筆是 1.0（33）已出）。

## ✅ 這次完成了什麼

- 付費造型從七種補成十一種：多米從五個候選挑了青花瓷、赤霞夕照、霓虹，再加翠玉湊滿選造型頁 3×4 十二格（原版加十一種）。函式在 `.uiux/像素風立繪/造型風格/make_styles.py` 的 `STYLES`，畫布四張畫板都更新了（https://claude.ai/artifact/YPBCBJde2WzFBBKRQcLZFW）。
- `work/anim-mask` 併 main 出 TestFlight 1.0（32）：十四條待機動畫換新去背。
- 第三輪回饋（分支 `work/ui-polish`）併 main 出 1.0（33）：設定頁拿掉固定說明（出問題才出現的提示照留）、「境界」往下 16 點、功法卡 A 版（功法名與等級同一行）、雷達圖丙版（半徑 116、軸端只寫功法名）。設計比較在 `.uiux/分析頁改版/功法卡與雷達圖.html`。
- 付費定案：單買 120、全套十一種 480、入口在設定頁。寫進 `.vibe/付費造型計畫.md`，含 12 個商品的參考名稱、產品 ID、顯示名稱、描述、審核備註。
- 內購 12 個商品：產品 ID 多米自己在 App Store Connect 建好；我寫了 `ios/ci/iap_products.json`＋`ios/ci/iap_products.mjs`＋`.github/workflows/iap.yml`（只能手動、只准 main，check 只讀、create 建或更新），create run 44220046564 把中文名稱、描述、價格、審核備註、上架地區都填好。狀態仍是「缺少資料」，只差審核截圖。
- M1 換造型寫好（分支 `work/portrait-styles`，還沒併 main）：
  - 154 張造型立繪在 `ios/Rencan/Resources/Assets.xcassets/PortraitStyles/`，名字 `r2-ink` 這種（make_styles.py 新增第三段輸出到 `<輸出資料夾>/app/`）。
  - `Theme.swift` 新增 `PortraitStyle`（代碼＝圖名後綴＝make_styles 風格名＝存的值），`RencanPortrait.name` 多一個 `style`。
  - `UserSettings.portraitStyleCode`（預設 original，認不得當原版）、`StoreServiceBulk.setPortraitStyle`。
  - 設定頁 `SettingsStyleSection.swift`（「立繪造型」一列）→ 選造型頁 `PortraitStyleView.swift`（`AppFlow.Sheet.portraitStyle`），每種都能直接選，沒有鎖。
  - 境界碑、雜役立繪、量測慶祝跟著換；付費造型還沒動畫，境界碑放靜態圖（`PortraitStyle.hasAnimation`）。
  - UI 測試 `ios/RencanUITests/PortraitStyleUITests.swift`：選青花瓷，預覽、設定那一列、境界碑都換，沿路截圖。
  - 第一輪檢查線 44224852140 紅（PagesView 讀不到設定、縮排），已修（b9c24a3）。第二輪 run 44226248264：編譯、排版、lint 都過，UI 測試 19 條過 18 條；M1 的六張截圖看過都對（設定那一列、選造型頁 12 格、選中青花瓷、設定寫青花瓷、境界碑青花瓷）。紅的是 HoldDeleteUITests：截圖 03 有出現「復原」，模擬器慢、測試去點時 5 秒已過，跟 M1 無關；已按 rerun（第 2 次嘗試）。

## 🚧 還沒做完 / 待決定

- **M1 併 main**：截圖已看過沒問題，只等 run 44226248264 第 2 次嘗試綠燈，就問多米要不要併 main 出 1.0（34）。如果 HoldDelete 再紅，代表那條測試在慢機器上不穩，要另外修測試（把復原的等待放寬，或測試模式把復原秒數拉長），不要拿 M1 的程式動刀。併的時候跟前兩次一樣：在 main 上 `git merge --no-ff --no-commit`，同一個 merge commit 改 `ios.yml` 的 `TESTFLIGHT_NOTES`，訊息不帶 `[skip ci]`。
- **M2 付費造型的待機動畫**：掌機四色、粗像素可整條換色；其他九種要讓 `animate.py` 每格輸出角色範圍再換色。做好後把 `PortraitStyle.hasAnimation` 打開。
- **M3 內購（StoreKit）、M4 選造型頁加鎖與購買鍵**：產品 ID 照 `ios/ci/iap_products.json`，一字不差。出錯一律當沒買、顯示原版（安全標準）。按鈕字用「購買」，不用「解鎖」（多米的寫作禁用詞）。
- **審核截圖**：M4 做好後加 UI 測試一次拍 12 張，再擴充 `iap_products.mjs` 上傳。
- 產品定稿兩處還沒改（`.vibe/產品定稿.md` 第 55、112 行「內購／無內購」），改前把原文拿給多米看。
- 水墨、全套兩個商品的上架地區是多米自己設的，腳本沒動；如果他只勾台灣，會跟其他十個不一樣，問過他、還沒答。
- 畫布上「境界頁換造型」那張（InAppRealm）還是舊的入口，入口已改設定頁，之後要改。
- 付費造型的宗門晉升長老圖、第一次打開那頁不換造型（多米同意）。

## 📌 關鍵決策（下次別再爭論）

- 多米定的：單買 120、全套 480、入口設定頁、原版加十一種（青花瓷、赤霞夕照、霓虹、翠玉是第八到十一種）、功法卡 A 版、雷達圖丙版、設定頁固定說明拿掉。
- 內購商品資料一律改 `ios/ci/iap_products.json` 再到 GitHub Actions 跑「內購商品」→ create；不要手動到後台改，兩邊會對不上。
- 併 main 前一律先問多米；push 的最後一筆帶 `[skip ci]` 會整次不跑（設計檔、帳本那種才帶）。
- 霓虹的亮邊沿「封口後的外形」描、縫補深紫；新風格都先 `binary_fill_holes`。檢查新風格要男女十四張都看、放大五倍。
- 多米要中文回覆（這次中途我一度用英文講，他說「說中文」）。

## 📂 下個會話最重要的檔案

- `.vibe/安全標準.md` ← **下一個會話必讀**（內購屬付費，出錯倒向鎖住；類別 9 新增了 `iap.yml` 那一條）。
- `.vibe/付費造型計畫.md` ← 組塊 M 五片、價格、商品清單與文案。
- `.vibe/切片帳本.md` ← 真相源。
- `ios/Rencan/App/Theme.swift` 的 `PortraitStyle`、`RencanPortrait` ← 造型從這裡接。
- `ios/Rencan/Views/Settings/PortraitStyleView.swift` ← 選造型頁，M4 在這裡加鎖與購買。
- `ios/ci/iap_products.json`、`ios/ci/iap_products.mjs` ← 內購商品。
- `.uiux/像素風立繪/造型風格/make_styles.py`、`.uiux/像素風立繪/animate.py` ← M2 會動到。

## ⏭️ 下一步從哪繼續

1. 確認在 `E:\人篸修煉`、分支 `work/portrait-styles`。
2. `gh run view 44226248264 --json attempt,conclusion` 看第 2 次嘗試：綠的話在帳本那筆 M1 記錄補上綠燈，問多米要不要併 main 出 1.0（34）；紅的話 `gh run view 44226248264 --log-failed` 看是不是又是 HoldDelete。
3. 併 main 時 TestFlight 測試說明寫：設定頁多了「立繪造型」，可以換十一種造型（還沒收錢、付費造型暫時不會動）。
4. 之後照 `.vibe/付費造型計畫.md` 做 M2（動畫）或 M3（內購），先問多米要先做哪個。

## 🗑️ 這次會話的雜訊（下次別重新討論）

- 第八種風格選型的過程（五個候選、雪夜沒選），結果已在 make_styles.py 與畫布。
- 內購「方法一 API／方法二瀏覽器」的比較，已經用 API 做完。
- 瀏覽器預覽 HTML 一直截圖逾時，跟頁面無關。
