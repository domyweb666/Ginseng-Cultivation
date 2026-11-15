# Handoff: 組塊 B 規則引擎做完並上 main；多米要「整個 app 做完再一次驗收」，組塊 C＋D 寫到一半停在分支 work/app（還沒編譯過）

> 產出時間：2026-11-15 23:24
> 前一會話的最後狀態，給下一個會話接續用。真相源是 `.vibe/切片帳本.md`；這份只補帳本沒寫的「做到一半的細節」。

## ✅ 這次完成了什麼

- 組塊 B（B1–B5）全部做完、推上 `main`、帳本打勾。最後一輪 run 43724808643：187 條中文名測試全過、swift-format 與 SwiftLint 嚴格都綠、TestFlight build 23。五片都是第一次推就綠。
- 多米點頭的事：採用 11/9 的標準清單、B5 放行、B3 兩張白話表（含補的三處）、七張女性立繪原檔進版控。
- 多米 2026-11-15 深夜的指示：「都做完，我再一次驗收」，並在選項裡選「整個 app 做完」。組塊 C 到 K 的程式全部做完才請他驗收，組塊 B 的人驗併到那一次。只停三種事：上架送審、要他登入 Apple 後台的、刪除真實資料。中途要他選的（Siri 語句、小人蔘 K2–K4 放行）照建議代決並記進 `.vibe/代決清單.md`。
- 建好「檢查線」（分支 `work/app`）：`.github/workflows/ios-check.yml` 在推到 `work/**` 時跑 Linux 測試、排版與 lint、模擬器編譯、UI 測試截圖，不碰 secrets、不上傳 TestFlight。UI 測試目標 `RencanUITests` 已加進 pbxproj 與 scheme。第一輪 run 43728269942 全綠，三張截圖看過正常。
- 補做組塊 B 的簡版體檢（記在帳本跳過紀錄）。
- 規則引擎加了畫面要用的東西（都在 `work/app`，還沒上過 CI）：`Digest.swift`（境界碑、功法卡、記一筆預覽、走勢點）、`Formulas.stageProgressPercent`、`Formulas.bodyFatGate`、`Formulas.fmt`、`Breakthrough.ffmi`、三種新錯誤（profileMissing、sameDayMeasurement、saveFailed）、`DigestTests.swift`（26 條）。
- 組塊 C＋D 的 app 程式寫了大約一半（清單在下面），**一次都還沒編譯過**。

## 🚧 還沒做完 / 待決定

### 分支 work/app 現在編不過，缺這些才會過

- `Views/Analysis/AnalysisView.swift` 還是舊的（收 `page` binding）。要改成 `AnalysisView(digest:lifts:)`，分段境界／功法。
- `Views/Settings/SettingsView.swift` 還是舊的。要改成 `SettingsView(digest:)`，先做「身體」區：身高（用 `HeightStepper`）與性別分段，改了呼叫 `store.saveProfile`。
- `Views/Gong/GongView.swift` 還是空殼。要做：統計格（累計修煉、這個月、練到大成幾門）、六張功法卡兩欄、最近修煉 20 筆（點了進編輯）、「功法等級怎麼算」。
- 還沒有的檔：
  - `Views/CelebrationView.swift`：收 `Celebration`，深色底（對整個 view 下 `.environment(\.colorScheme, .dark)` 就能用同一套代號）、立繪、大字、說明、4.5 秒進度條、點任何地方關閉；`.task` 裡用 `Task.pause(seconds: AppFlow.celebrationSeconds)` 自動關。粒子照網頁版 `burst`（index.html L582–596），系統開「減少動態效果」不噴。
  - `Views/Gong/MoveDetailView.swift`：`MoveDetailView(key:digest:lifts:)`，那門功法的 1RM 走勢（Swift Charts）加全部紀錄。
  - 功法卡（MoveCardView）：功法名、等級標籤、`SegmentBar(total: 5, filled: level)`、「1RM X 公斤」「Y 倍體重」、走勢線、「再加 N 公斤升Z」／「已到化境」／「還沒有紀錄」／「先量一次體重」。
  - 分析頁境界段：宗門卡（身分、說明、進度條、下一步、六個身分一排標出現在的）、FFMI 走勢圖（境界門檻畫虛線；只有一筆時顯示一句話）、突破紀錄（新的在上：「金丹後期」「11 月 3 日・距上次 62 天」或「第一次量測」「FFMI 20.6」）、天梯（七列，範圍用 `sex.displayedRealmBounds()`，現在那一列標「你在這裡・後期」）、「境界怎麼算」。沒量過時顯示一句空狀態。
- `ios/RencanUITests/ShellUITests.swift` 要改：現在 app 第一次打開會先到問身高那頁，測試要帶 `-rencanSeed profile` 才進得了三頁。另外要加測試：第一次打開（選性別、開始）、記一筆（看到預覽、記下、今天的修煉多一行）、手動量體組成（踏入仙途的慶祝）、`-rencanSeed demo` 截境界頁與分析兩段、編輯與左滑刪除加復原。
- `Formulas.fmt` 還沒有測試。網頁版算出來的標準答案：`fmt(0.125,2)="0.13"`、`fmt(20.316852,2)="20.32"`、`fmt(0.5544984,1)="0.6"`、`fmt(116.666,0)="117"`、`fmt(2.5,0)="3"`、`fmt(1.005,2)="1.00"`、`fmt(72,1)="72.0"`、`fmt(19.995,2)="20.00"`。
- 文件還沒跟上：`.vibe/架構藍圖.md` 第三節要補這次新增的檔（下面「重要的檔案」列的那些）；帳本要補組塊 C、D 的 plan-readback 與「本片動到的檔」；PRD 的 S1 要從「只問身高」改成「問身高與性別」（多米 11-15 定女性版時已經決定）。

### 之後的組塊（照帳本順序，每塊綠了併 main 出一版）

- **E 健康 app**：UI 測試模式（`-rencanUITest`）不碰 HealthKit。真機才驗得到，列進最後的驗收清單。
- **F 資料帶得走**：匯出匯入用 RencanCore 的 `WebExport`；`index.html` 只加一顆匯出鈕；「刪除全部紀錄」要二次確認。
- **G 小工具**：要第二個 App ID `org.domyweb.rencan.widget` 加上 App Group，App Group 指派用 API 做不到，要多米進 Apple 後台。所以小工具做到模擬器能驗，**不要併進 main 的 archive**，免得主線簽章紅掉、多米最後沒版本可驗。`ios/ci/appstore_profile.mjs` 也只吃一個 bundle id。
- **H Siri**：App Intents 放在主 app target，不用新 target。語句照帳本建議代決。
- **I 提醒與設定收尾**、**K 小人蔘**（K1 多米選了頭套款；K2 的角度答案在 `.uiux/小人蔘/頭套預覽.html` 的 `<script id="core">`）。
- **J 上架**：J1 隱私文稿可以先寫；J2–J4 是多米的事，不做。

### 留給後面的提醒

- 身高沒過 `Validation.check(heightCm:)` 不准呼叫 `ffmi`（傳 0 會算出渡劫後期）。現在 `saveProfile` 有擋。
- PRD S6「補登的量測不進突破紀錄」跟網頁版每次重排重算的做法有落差，組塊 D 做突破紀錄畫面時要記進代決清單或問多米。
- 刪除修煉現在是「立刻刪、5 秒內可復原」，藍圖寫的是「逾時才真刪」。使用者看到的一樣，app 在 5 秒內被殺掉時兩者不同。要記進代決清單。
- 記一筆表單照設計畫布只有加減鈕（重量一次 2.5 公斤），打不出 41 這種數字。最後驗收清單要提醒多米看這點。

## 📌 關鍵決策（這次定下來的，下次別再爭論）

- 中途一律推 `work/app` 跑檢查線，一整塊綠了才併 `main`（併 main 才會出 TestFlight 版本）。`main` 的 `ios.yml` 沒動。
- 畫面的機器自審＝UI 測試在 GitHub 的模擬器截圖，AI 下載回來用 Read 看圖。Limrun 不用了。
- 畫面要的數字全部由 RencanCore 的 `Digest` 算好，畫面只排版。`RootTabView` 用 `@Query` 讀一次資料、算一份 `Digest` 往下傳。
- 跟性別有關的函式 `sex` 沒有預設值；不帶 sex 的版本在 `WebParity.swift`（internal，只給測試對網頁版用）。
- SwiftData 的日期存成「yyyy-MM-dd」字串（`day`），用西曆（`DayStamp`），不用 `Calendar.current`（民國曆會出錯）。
- 三頁共用的流程狀態（哪張表單、小提示、慶祝、復原、現在哪一頁）放在 `AppFlow`（@Observable，從 environment 注入）。換頁按鈕讀它，不再傳 `page` binding。
- 資料只透過 `StoreService` 改，全部 throws，存檔失敗會 rollback 並丟 `RencanError.saveFailed`。
- Debug 版才認的啟動參數：`-rencanUITest`（記憶體資料庫）、`-rencanSeed profile|demo|female`。Release 版一律無視。
- 文字與版面照九張設計畫布，已存一份在 `.uiux/畫布-2026-11-15/*.dc.html`（Main、RealmEmpty、LogSheet、MeasureSheet、AnalysisRealm、AnalysisGong、Settings、Onboard、Celebrate）。
- 這台沒有 Swift 編譯器，寫 Swift 要守的（組塊 B 五片零紅燈就是靠這些）：
  - 不寫多行陣列字面值（swift-format 要尾逗號、SwiftLint 不准）。
  - 不寫 `try?`、空 catch、強制解包、`print`；畫面檔不准出現色碼，顏色只從 `Color.rencan.*` 取。
  - 每行最多 100 字元；變數名至少 3 個字（`id`、`kg`、`x`、`y`、`i` 例外）；tuple 最多 2 個成員；函式本體最多 40 行、檔案最多 400 行、型別本體最多 250 行。
  - `if`／`guard` 的條件不要拆成多行（SwiftLint 的 opening_brace）。
  - 測試名不能有小數點，寫「70點4」。
  - 推之前跑 `node .vibe/tools/dev/swift_check.js ios/Rencan` 與 `ios/RencanCore`（粗篩；「全形當 2 欄會超過 100」那種只是提醒）。
- Bash heredoc 會把兩個反斜線折成一個：含 `\(` 的 Swift 內容用 Write／Edit 工具，不要用 heredoc 裡的 node 字串替換。

## 📂 下個會話最重要的檔案

- `.vibe/切片帳本.md`：進度真相源。組塊 C 起的片都還沒打勾。
- `.vibe/代決清單.md`：替多米決定的事，最後要給他看。
- `.uiux/畫布-2026-11-15/*.dc.html`：九張畫面的文字與尺寸。
- `ios/RencanCore/Sources/RencanCore/Digest.swift`：畫面拿數字的介面。
- 已寫好、等編譯的 app 檔（都在 `ios/Rencan/`）：
  - `App/`：`RencanApp.swift`、`RootTabView.swift`（含 `PagesView`、`DataErrorView`）、`AppFlow.swift`、`FirstLaunchView.swift`（含 `HeightStepper`）、`UITestSupport.swift`、`Theme.swift`（加了字體、版面常數、立繪名）
  - `Models/`：`Measurement.swift`、`LiftRecord.swift`、`UserSettings.swift`
  - `Services/`：`StoreService.swift`、`DayStamp.swift`、`HapticsService.swift`
  - `Views/`：`Celebration.swift`（慶祝的文案，還沒有畫面）、`Realm/RealmView.swift`、`Realm/SteleView.swift`、`Log/LiftFormView.swift`、`Log/LiftFieldsView.swift`、`Log/LiftRow.swift`、`Log/TodayListView.swift`、`Log/EditRecordView.swift`、`Log/MeasurementFormView.swift`、`Shared/Components.swift`、`Shared/SheetChrome.swift`、`Shared/PageChrome.swift`
- `ios/RencanUITests/RencanUITestCase.swift`：截圖底座（`launch`、`shot`、`waitForText`、`tapButton`）。
- `.vibe/tools/dev/watch_check.sh`：等檢查線跑完、印錯誤行、把截圖抓回來。`.vibe/tools/dev/swift_check.js`：推之前的粗篩。

## ⏭️ 下一步從哪繼續

1. 讀這份，再讀 `.vibe/切片帳本.md` 開頭兩段註記與 `.vibe/代決清單.md` 最後幾條。
2. `git checkout work/app`（`main` 不要直接動）。
3. 把「分支 work/app 現在編不過」那一段缺的檔補齊，改 UI 測試，跑 `swift_check.js`，commit 後推 `work/app`。
4. 背景跑 `bash .vibe/tools/dev/watch_check.sh`。第一次編 SwiftUI 幾乎一定會紅幾輪，照錯誤行修到綠，再把截圖一張張用 Read 看過。
5. C、D 都綠、截圖對得上畫布後：補帳本（C1–C5、D1–D4 的機器層證據）、藍圖、PRD S1，把 `work/app` 併進 `main`（fast-forward，不要 force push）出一版，確認主線三個工作全綠。
6. 接著照帳本做 E、F、G、H、I、K、J1。全部做完後整理一份「一次驗收清單」給多米：手機上要看什麼、哪些只有真機驗得到（震動、體脂秤、Siri 語音）、哪些要他進 Apple 後台（小工具的 App ID 與 App Group、上架）。

## 🗑️ 這次會話的雜訊（下次別重新討論）

- 「都做完」的範圍已經問過，答案是整個 app。
- 組塊 B 每片的推送授權、B2 的做法沒被明確回覆這些細節，都已經記在代決清單，不用再提。
- 檢查腳本一開始放在暫存區，現在在 `.vibe/tools/dev/`，暫存區那份可以不管。
