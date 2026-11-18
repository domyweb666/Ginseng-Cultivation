# Handoff: 整晚上架進行中（M3、M4 綠了，M2 圖做好待接 Swift，App Store Connect 填到一半）

> 產出時間：2026-11-18 13:40。一律在 `E:\人篸修煉`，分支 `work/overnight-20261118-1130`（從 work/portrait-styles 開，含 M1）。
> 多米的指示（11:30–13:35）：熬夜做到上架為止；多開 subagent；拍照和錄影都用 Limrun；**睡醒要看到已經送審，途中困難自己解決**；context 太長就寫 handoff 繼續。
> 進度主檔是專案根目錄的 `OVERNIGHT.md`（任務清單 1–13、待確認、執行紀錄）。先讀它。

## 已完成
- 1：M1 檢查線綠。3、4：M3 內購（`Services/PurchaseService.swift`，StoreKit 2，出錯當沒買，UI 測試走假商店）、M4 選造型頁（鎖、全套卡、購買鍵、恢復購買），run 44233063338 全綠，截圖看過。
- 5（一半）：`IAPReviewShotsUITests` 拍出 12 張審核截圖（在 run 44233063338 的 artifact rencan-ui-screenshots，檔名 IAPReviewShots-NN-代碼.png）；`iap_products.mjs` 有 MODE=screenshots，讀 `ios/ci/iap_review_screenshots/{代碼}.png`（代碼＝產品 ID 最後一段，全套 all）。**還沒把圖放進那個資料夾、還沒跑。**
- 6、7：文件與 `docs/上架文稿.md`（commit 58f7b3c）。
- 網站：`E:\domyweb-main` 5d51403 已推，`https://domyweb.org/rencan/privacy/`、`/rencan/support/`（部署後要確認打得開，沒斜線的網址會 308 轉）。
- 審核聯絡資訊：GitHub secret `REVIEW_CONTACT_JSON`（從茄記 store.config.json 來，同一個人；repo 公開，不准寫進檔案）。

## App Store Connect 工具（都在 main 上，用 git commit-tree 直接推 main，不動工作區）
- `.github/workflows/asc.yml`：手動、只准 main。mode：check（`asc_release.mjs` 只讀）、fill／media／submit（`asc_publish.mjs`），submit 可帶 build 號。
- 資料：`ios/ci/asc_listing.json`；描述與送審備註從 `docs/上架文稿.md` 抽 ``` 區塊（開頭字串比對）。
- fill 第二輪停在：**描述不能有「▌」**。修法：asc_publish.mjs 抽描述後把 `^▌(.+)$` 換成 `【$1】`。改完要同步到整晚分支與 main（commit-tree），再 `gh workflow run asc.yml --ref main -f mode=fill`。
- 年齡分級還空 socialMediaAgeRestricted、gracRatingClassificationNumber（先不管，送審報錯再補）。
- 價格免費、地區全部 → fill 後段，還沒跑到。
- media 要的檔：`ios/ci/store/6.9/*.jpg`（3–10 張，APP_IPHONE_67）、`ios/ci/store/review.mp4`（附在審核資料）。
- 隱私標籤問卷沒有 API。內建瀏覽器沒登入 App Store Connect（我不能輸入密碼）；多米沒說可以用他的 Chrome，所以沒碰。**送審可能被這個擋住**，擋住就留給多米早上點「不蒐集資料」再跑 submit。
- 付費 App 協議有沒有簽不知道；12 個內購都是 MISSING_METADATA（差審核截圖）。

## 還沒做（照 OVERNIGHT.md 編號）
1. 2：M2 接 Swift。subagent 已把 154 個 `{代號}-{造型}Anim.imageset` 放進 `Assets.xcassets/PortraitStyles/`（21 MB），檢查圖在 `.uiux/像素風立繪/造型風格/動畫檢查/總覽_{造型}.png`（先看幾張）。Swift 要改：`Theme.swift` 的 `PortraitStyle.hasAnimation` 改成全部 true、`RencanPortrait.animationName` 加 style 參數（`name(...style) + "Anim"`），`SteleView.swift` 呼叫處帶 style。再加一條 UI 測試或改 DemoUITests 帶 `-rencanOwn celadon` 與 `-rencanPlayPortrait` 拍兩張比對。要 commit 的：`.uiux/像素風立繪/animate.py`、`造型風格/make_styles.py`、`造型風格/make_style_anims.py`、`動畫_新去背/*_anim96_mask.png`、Assets 的 154 個 imageset；`動畫_造型/` 與 `動畫檢查/` 是重複或檢查用，別 commit（太大）。
2. 推整晚分支跑檢查線（推之前確認沒有正在跑的同分支 run，推了會取消它）。
3. 8：商品頁截圖。照 `E:\茄記\qieji-1.1\.aso\上架展示圖準則.md`，腳本在 `docs/上架文稿.md` 第五節。用 Limrun 拍原圖（金鑰 `~/.lim/config.yaml` 可用，13:00 開機測過；做法見記憶 limrun-cloud-simulator 與 `.vibe/tools/limrun_walk.mjs`；模擬器版從檢查線 artifact `rencan-sim-app` 下載，是 Debug 版，啟動參數 -rencanUITest -rencanSeed demo -rencanOwn all 都能用）。複製 `E:\茄記\qieji-1.1\.aso\tools\store_shots.py` 到 `.aso/tools/`（或 ios/ci/store/），改顏色（app 圖示的金棕）與 SHOTS，輸出 `ios/ci/store/6.9/*.jpg`。付費那張用 `-rencanOwn all`（圖上不能有價格）。
4. 8b：送審錄影，Limrun `client.startRecording()`／`stopRecording({ localPath })`。照送審備註的步驟走（第一次打開→身高 175、男、開始→手動輸入體組成 70／15→結算境界→慶祝→記一筆修煉→分析頁→設定→立繪造型→點有鎖的→購買鍵→恢復購買）。存 `ios/ci/store/review.mp4`，從頭看一次。模擬器 typeText 會變注音，數字用點鍵盤（見記憶）。
5. 5 的後半：12 張審核截圖複製成 `ios/ci/iap_review_screenshots/{代碼}.png`，到 main 跑 `gh workflow run iap.yml --ref main -f mode=screenshots`。
6. 9：安全自查（可開 subagent 跑 vibe-security-gate C，產出 `.vibe/安全檢查報告.md`）。
7. 10：併 main 出建置：在 main 上 `git merge --no-ff --no-commit work/overnight-20261118-1130`，同一個 commit 改 `ios.yml` 的 `TESTFLIGHT_NOTES`（設定頁「立繪造型」、十一種造型與待機動畫、TestFlight 沙盒購買不扣錢），訊息不帶 [skip ci]。注意 main 上已有 asc 工具的 commit（f5cdde8、7d2d0fe、f9333cf），內容跟整晚分支相同，應該不衝突。
8. 11：fill、media、iap screenshots 跑完再 check 一次。
9. 12：等新建置 VALID 後 `-f mode=submit -f build=<號>`。
10. 13：帳本（`.vibe/切片帳本.md` 進行中段加 M2–M4、上架）、OVERNIGHT.md 早上摘要、這份 HANDOFF。

## 關鍵決策（別再爭）
- 多米 13:35 前說「自己解決」：併 main、填後台、送審都直接做，但每一步記在 OVERNIGHT.md。
- 不用多米的 Chrome、不輸入任何密碼。
- 推整晚分支會取消同分支正在跑的檢查線（concurrency），推之前先看。
- 一直跳「允許」是 app 權限設定，已請多米換成自動接受。
