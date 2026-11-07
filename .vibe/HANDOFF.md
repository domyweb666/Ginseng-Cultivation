# Handoff: 人蔘修煉 PWA → iOS 原生 app：從考古到切片全部定案，停在第一片動工前的走查

> 產出時間：2026-11-07 17:40
> 前一會話的最後狀態，給下一個會話接續用。session-start hook 會自動把這份、規矩檔、state.json 注入新會話。

## ✅ 這次完成了什麼
- 把 GitHub repo（domyweb666/Ginseng-Cultivation，使用者自己的）clone 到 `E:\人篸修煉` 當專案根目錄；origin 仍指向它，main 之上多了 12 個 VibeRails commit，**全部未 push**
- 鋪 VibeRails 安全網：`.vibe/`、三個 Claude Code hook（`.claude/settings.json`）、tag `pre-viberails`（採用前原始狀態）
- 考古三件套＋意圖落差清單：`.vibe/考古版-flowmap.html`、`考古版藍圖.md`、`考古版產品定稿.md`、`意圖落差清單.md`
- 拷問完成 → `.vibe/產品定稿.md`；PRD 28 條故事 → `.vibe/PRD.md`
- 正式架構藍圖 `.vibe/架構藍圖.md`，兩張待掛點流程圖（規格 `.vibe/flowmap/app.json`、`delivery.json`，工具 `.vibe/tools/flowmap_build.js`）
- 安全標準 `.vibe/安全標準.md`（MASVS＋CWE＋App Store 5.1.3），已掛進規矩檔
- 切片帳本 `.vibe/切片帳本.md`：10 組塊 36 片（組塊 A 後來加了 A5 變 37 片）；`.vibe/組塊核准讀稿.md` 使用者全部放行
- voice-lock：憲法寫進 `.vibe/規矩檔.md`「專案特定規矩」；pre-commit hook `.vibe/hooks/pre-commit.js`（`git config core.hooksPath .vibe/githooks` 已設，實測攔下故意放的 5 個違規）；`ios/.swift-format`、`ios/.swiftlint.yml` 給 CI；`.gitattributes` 統一 LF
- 片 A1（憑證）＋A2（骨架）的 `.vibe/標準清單.md` 與 `.vibe/黃金行為.md`
- 查證 Limrun 並納入交付線：帳本新片 A5、交付圖 d13／d14、PRD 黑箱盲點、藍圖第二節、安全標準類別 9

## 🚧 還沒做完 / 待決定
- **片 A1／A2 的真實情境走查沒做**：使用者沒用自己的話講「推上去之後我會怎麼操作、期望看到什麼」。下個會話第一件事（或他選「照標準開做」也行，但要留痕）。
- **組塊 A 加了 A5，組成變了，讀稿要他重新放行 A**（其他九塊放行不變）。
- **Limrun 帳號**：使用者有沒有帳號、試用 120 點夠做 A5 首驗、要不要付 Entry（20 美元/月）都沒問。
- plan-readback 還沒跑（走查過了才跑）。
- 全部 commit 未 push；push 前要問使用者（repo 公開，`.vibe/` 文件會公開在 GitHub Pages 上）。
- 架構藍圖第十節的切片順序建議裡「CI 可以提早到第一片之後就建」已被帳本採納（A3 在組塊 A）。

## 📌 關鍵決策（這次定下來的，下次別再爭論）
- 路線：SwiftUI 原生重寫，iOS 17 起，SwiftData 本機；零第三方套件
- 編譯：沒有 Mac。GitHub Actions（repo 公開，macOS runner 免費）建 TestFlight 版；Limrun 建模擬器版給 AI 自驗；lim xcode sync 只當卡編譯時的快速內圈
- 帳號：付費 Apple Developer；上架給陌生人；免費
- 第一版範圍：原樣移植＋HealthKit＋震動＋小工具＋Siri＋每月提醒
- 核心功能：境界那一刻；成功：陌生人三個月後還在量；最怕：欄位多的健身記錄 app（欄位數定死）
- 給誰用：有在重訓的人含新手；**去掉女性版**，一張男性表，說明註明
- 體脂數字必要；引導只問身高（能抓健康 app 就不問）；授權讀取第一次打開一次問四種
- 訓練模型：丙，單筆不動＋今天的修煉清單
- **不做 iCloud**（App Store 5.1.3 不准健康資料存 iCloud）；換手機靠健康 app 重建＋匯出匯入
- 體脂 >20%：顯示境界但根基不穩，突破與宗門只採計穩固；精進煙火要 1RM 真的變高；bwAt 不再預設 65 kg
- 設定加「刪除全部紀錄」（安全標準要求）
- Bundle ID org.domyweb.rencan；App 名稱人蔘修煉；繁中；隱私政策放 domyweb.org
- 規則引擎 RencanCore 純 Swift、只 import Foundation、日期用 yyyy-MM-dd 字串跟網頁版算法一樣；黃金集用 node 跑原版 index.html 的 JS 產標準答案（不用真實個人資料）
- 設計代號照網頁版 CSS（藍圖第六節），畫面不准寫死色碼（hook 擋）

## 📂 下個會話最重要的檔案
- `.vibe/規矩檔.md` ← 憲法在「專案特定規矩」，hook 會自動注入
- `.vibe/安全標準.md` ← **下一個會話必讀**（security-gate 的契約）
- `.vibe/切片帳本.md` ← 真相源；「進行中」欄位還是空的
- `.vibe/標準清單.md`、`.vibe/黃金行為.md` ← 片 A1／A2 的「怎樣算對」
- `.vibe/架構藍圖.md` ← 第三節檔案計畫、第四節資料模型、第五節規則引擎介面、第六節設計代號、第二節交付線（含 Limrun）
- `.vibe/PRD.md`、`.vibe/產品定稿.md` ← 終點；偏離先回來改
- `.vibe/組塊核准讀稿.md` ← 組塊 A 要重新放行
- `index.html` ← 原版規則在 L203–331，移植 Tables／Formulas 時逐行對照
- `.vibe/iOS轉製建議.md` ← 當初的判斷，只當背景

## ⏭️ 下一步從哪繼續
1. 讀這份、`.vibe/安全標準.md`、`.vibe/切片帳本.md` 組塊 A。
2. 問使用者兩件事：(a) 組塊 A 加了 A5，重新放行？(b) 走查：用他的話講「我說推上去了之後，你會怎麼操作、期望看到什麼」。他講的跟 `.vibe/標準清單.md` 有出入 → 以他為準改標準。
3. 跑 `vibe-plan-readback` 覆誦 A1／A2／A3／A5 的做法，他點頭才動工。
4. 做 A1：寫 `ios/ci/README.md`：openssl 做 key＋CSR（檔案放 `E:\人篸修煉-secrets\`，repo 外）、Apple 後台建 Apple Distribution 憑證、合成 .p12、註冊 App ID `org.domyweb.rencan`（勾 HealthKit、App Groups）、App Store Connect 建 API 金鑰（App Manager）與 app 記錄、GitHub 6 個 secrets（`APPLE_DIST_P12_BASE64`、`APPLE_DIST_P12_PASSWORD`、`APPLE_TEAM_ID`、`ASC_KEY_ID`、`ASC_ISSUER_ID`、`ASC_KEY_P8_BASE64`）＋ `LIM_API_KEY`；base64 轉法用 Git Bash 的 `base64 -w0`；Limrun 註冊、API key、`claude mcp add --transport http limrun https://mcp.limrun.com/mcp` 再 `/mcp` 授權、`npm install --global lim@<查最新版>`。
5. 做 A2：手寫 Xcode 16 專案（`PBXFileSystemSynchronizedRootGroup` 資料夾同步格式，objectVersion 77）、兩個 target（Rencan、RencanWidget 可先只做 Rencan，Widget 在組塊 G 加）、三分頁空殼、Assets 顏色集（藍圖第六節）、AppIcon（img/icon-512.png）、立繪 webp→png（python 3.10 有 PIL）、LXGW 文楷 TC 字型檔（OFL，要下載 .ttf 進 Resources/Fonts 並在 Info.plist 的 UIAppFonts 登記，用 `INFOPLIST_KEY_*` 建置設定或 Info.plist 檔）、entitlements（HealthKit、App Group `group.org.domyweb.rencan`）、PrivacyInfo 空殼、RencanCore 空套件＋一個會過的測試。
6. 做 A3：`.github/workflows/ios.yml`：job 1 ubuntu `swift test`（RencanCore）；job 2 macOS：swift-format lint --strict、swiftlint --strict、還原憑證到暫時鑰匙圈、`xcodebuild archive -allowProvisioningUpdates` 加 API 金鑰、`-exportArchive` 用 `ios/ci/ExportOptions.plist`（method app-store-connect、destination upload）、模擬器版 `-sdk iphonesimulator` 建置後 zip、`lim asset upload`；`if: always()` 刪鑰匙圈。
7. A5：用 Limrun MCP 開模擬器裝最新 asset，截圖三個分頁存 `.vibe/evidence/`，刪機器。
8. 每片做完照迴圈：vibe-self-review（在乾淨 subagent 跑，Limrun 截圖當證據）→ vibe-simplify → vibe-regression-guard → 存機器存檔點；立即驗的片攔使用者走 vibe-audit。

## 🗑️ 這次會話的雜訊（下次別重新討論）
- 女性標準表：討論過又由使用者砍掉，別再提
- iCloud 同步：查證 5.1.3 後砍，別再提
- 訓練資料模型三選一：選丙，別再提
- 免費 Apple ID 能不能開 HealthKit：已查（官方表格有勾），而且使用者有付費帳號，無關
- Bash 的 quoted heredoc 寫含大量單引號的大檔會炸：大檔用 Write 工具
- 這台 Windows：Git Bash、node 24、python 3.10＋PIL、ffmpeg；沒有 Swift 工具鏈；Claude Code 的 hook 只在以 `E:\人篸修煉` 為專案目錄開會話時生效；新 clone 要重跑 `git config core.hooksPath .vibe/githooks`
- 使用者回答習慣：多半只按框裡的按鈕，開放題要放進框裡才會答
