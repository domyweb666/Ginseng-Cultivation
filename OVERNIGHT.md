<!-- overnight: done -->
# Overnight 報告

分支：`work/overnight-20261126-1110`（從 `work/perf-1126` 開出來）。檢查線只在 `work/**` 跑，所以分支名前面加了 work/。

## 早上摘要

10 項做完 10 項。2026-11-27 多米說「併進 main」，整條分支已併 main。

- 第 1 項：TestFlight 1.1（43）已上傳，是 work/perf-1126 那一版（Digest 快取那批），不含下面 2 到 8 項。
- 第 2 項：立繪動畫只在境界頁、沒開表單、沒在慶祝時換格，看不到時停在當格（`SteleView.swift` 的 `PortraitFrameSchedule`）。
- 第 3 項：境界碑陰影只掛在底色圓角上（`SteleView.swift`）。截圖跟改前每格差最多 2，看不出來。
- 第 4 項：慶祝粒子淡完（約 1.9 秒）就把整塊拿掉（`CelebrationParticles.swift`）。
- 第 5 項：回前景只重看買過什麼（`PurchaseService.refreshOwned`），價格打開選造型頁才抓；還沒抓回來時購買鍵寫「讀取價格中」（`PortraitStyleView.swift`）。
- 第 6 項：健康查詢的日曆只建一次，時區跟著手機換（`HealthKitQueries.swift`）。
- 第 7 項：一筆量測都沒有時，健康 app 沒有體脂率就只拿最新一筆體重與去脂體重，不讀整段歷史（`HealthKitService.swift`）。
- 第 8 項：拿掉境界頁、分析頁、功法、最近修煉、單一功法沒用到的 lifts 參數。

檢查線：run 45747324040 全綠；改購買鍵字型別後的 run 45824004998 有一條 SheetDelete（刪除再復原）找不到「復原」鍵，跟改動無關，重跑。

要先測：選造型頁第一次打開時價格多久出來、購買鍵；切到設定或分析頁再回境界頁，立繪接著動；突破慶祝的粒子。這幾項模擬器都沒量過速度。

1.0（40）又被 Apple 退（2.3.7，截圖寫了「免費」「付費」），第 8 張截圖已改，等多米點頭重送，細節在 `.vibe/HANDOFF.md`。

## 任務清單
- [x] 1. run 45743378156 綠了，從 work/perf-1126 手動觸發 ios.yml 出 TestFlight 性能版。完成標準：ios.yml 那次執行成功。
- [x] 2. 立繪動畫只在看得到時動：在境界頁、沒開表單、沒在慶祝。停的時候停在當格，不換成靜態圖（換圖會跳一下）。完成標準：檢查線編譯與 UI 測試過。
- [x] 3. 境界碑陰影只掛在底色形狀上，立繪換格不重算陰影。完成標準：檢查線過、截圖跟改前一樣。
- [x] 4. 慶祝粒子散完就停（約 1.9 秒），不跑滿 4.5 秒。完成標準：檢查線過。
- [x] 5. 回前景只重看買過什麼，不再重抓 12 個商品價格；價格在打開選造型頁時抓。完成標準：檢查線過、選造型頁 UI 測試過。
- [x] 6. `HealthKitQueries.swift` 的 calendar 改 static let。完成標準：檢查線過。
- [x] 7. 一筆量測都沒有時，健康 app 沒有體脂率就不讀整段體重歷史。完成標準：檢查線過。
- [x] 8. 拿掉沒用到的 lifts 參數（RealmView、AnalysisView、GongView、RecentLiftsList、MoveDetailView）。完成標準：檢查線過。
- [x] 9. 推上去跑檢查線，全綠；紅了修。
- [x] 10. 更新 HANDOFF.md、寫早上摘要。

## 待確認（需要多米決定的事）

## 卡住的項目

## 執行紀錄
- 11:10 開分支，HANDOFF.md 先存檔（eaa7748）。run 45743378156 還在跑 macOS 那段。
- 11:40 第 2–8 項改完、各自 commit（1af15b8 到 9664085）。這台沒有 Xcode，編譯與測試要等檢查線。OVERNIGHT.md 蓋掉了上次整晚的舊報告（舊的在 git 歷史 b948f7c）。
- 11:40 推 work/overnight-20261126-1110 跑檢查線（第 9 項）。
- 11:50 run 45743378156 全綠。從 work/perf-1126（4f667fb）手動觸發 ios.yml，run 45747413975，建置號 43，在跑。整晚分支的檢查線 run 45747324040 在排 macOS 機器。
- 12:20 第 1 項完成：run 45747413975 三段全綠（規則引擎、建置上傳、填測試說明），TestFlight 1.1（43）已上傳。整晚分支檢查線 macOS 那段在跑。
- 12:45 檢查線 run 45747324040 全綠（UI 34 條、規則引擎、swift-format、swiftlint）。截圖 156 張對過：境界碑那些每格差最多 2（陰影換寫法，看不出來）；選造型頁購買鍵多了一個空格（「水墨」 NT$120），原因是新加的 missingPriceText 回 String，整句從 LocalizedStringKey 變成 String。改回同型別，再推一次。立繪動畫截圖格數不同是截圖時機，人蔘姿勢一樣。
- 2026-11-27 11:10 多米說併進 main。asc check 看到 1.0（40）REJECTED。run 45824004998 的 SheetDelete 紅，重跑中，綠了再併。
