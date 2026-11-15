# Handoff: 整個 app（C 到 K、J1）都在 TestFlight 1.0（28），含小工具；等多米照驗收清單一次驗收，之後是 J2–J4 上架

> 產出時間：2026-11-16 02:10，04:10 更新（小工具的 App ID 弄好了，主線全綠，TestFlight 1.0（28））
> 前一會話的最後狀態，給下一個會話接續用。真相源是 `.vibe/切片帳本.md`。上一份備份在 `.vibe/handoff/archive/HANDOFF-2026-11-16-0135.md`。

## ✅ 這次完成了什麼

- 第三輪檢查線（run 43738053476，commit `cd54529`）：E、F、H、I、K、J1 第一次編譯就過，排版與 lint 全綠，UI 測試 19 條過 18 條。
- 紅的那條是「記一筆破紀錄後沒看到功法精進」。查紀錄是 XCUITest 按下後等 app 閒下來等了 17 秒，4.5 秒的慶祝已經自己關了。Limrun 實機走同一步：慶祝 0.9 秒出現、5 秒自己關，app 沒卡。所以改的是測試：`launch()` 多帶 `-rencanHoldCelebration`，慶祝等測試點掉（`UITestSupport.holdsCelebration`）。
- 第四輪（run 43741015689，commit `12204c3`）全綠：規則引擎 351 條、UI 測試 19 條。
- `a0e72be` 已 fast-forward 併進 `main`，主線 run 43743646621 三個工作全綠，TestFlight 1.0（25）。測試說明已換成這一版的內容。
- 量測表單的錯誤列旁加了抓頭的小人蔘（跟記一筆表單同一個樣子）。
- `docs/一次驗收清單.md`：給多米整個 app 做完後一次走完用的，照拿著手機從頭走的順序排，九段加「要你決定的」「我替你決定過的」「機器已經驗過的」。
- 小工具 G1–G3 寫完，在分支 `work/widget`：
  - RencanCore `WidgetSnapshot.swift` 加 17 條測試（這一半已經在 `work/app` 與 `main`，不碰簽章）。`Formulas.daysThisWeek` 是新的，`weekCount` 改呼叫它。
  - `Services/WidgetBridge.swift`、`StoreService.afterSave`、`AppServices.digest(in:)`、`RencanApp` 打開時寫一次快照。
  - `ios/RencanWidget/`：進入點、時間線、三個尺寸的畫面、五個色票、entitlements、隱私清單、Info.plist。
  - `project.pbxproj` 手動加 app-extension target（`org.domyweb.rencan.widget`），嵌進主 app。
  - `ios-check.yml` 的模擬器版改成本機臨時簽章（`CODE_SIGN_IDENTITY=-`），App Group 才通。
  - `ios.yml`、`ExportOptions.plist`、`appstore_profile.mjs`：小工具自己的描述檔。`ios/ci/README.md` 第四段最後加了登記小工具 App ID 的步驟。
  - 第一次編譯就全綠（run 43741336820，commit `aaf976c`）。
- Limrun 這次跑了六趟共約 7.5 分鐘，每趟機器都刪了、殘留 0 台。看到的事：
  - 慶祝粒子（金加翠綠）、小人蔘葉子是綠的、設定頁五區都正常。
  - 雲端模擬器的「加入小工具」清單是空的，連系統內建的都沒有，等 12 秒也一樣。小工具的樣子在 Limrun 看不到。
  - 臨時簽章的模擬器版有 App Group 容器；示範資料打開後 `widgetSnapshot.v1` 是完整的一份（203 位元組，結尾是「中期」）。剛打開那一兩秒讀到的可能是 62 位元組的空狀態，那是系統還沒把第二次寫入存回磁碟。
  - Limrun 的 simctl 只准幾個指令：`appinfo` 可以（拿得到 App Group 路徑），`get_app_container` 不行；`spawn` 只准 `defaults`、`notifyutil`。
- 代決清單加了小工具四條。藍圖第三節與資料模型補了小工具。帳本補了 E、F、H、I、K、J1 的機器層證據。

## 🚧 還沒做完 / 待決定

- **小工具的樣子在模擬器上看過了，真機還沒。** `ios/RencanUITests/WidgetUITests.swift` 在 GitHub 的模擬器上走主畫面「按住圖示、Edit Home Screen、Edit、Add Widget、搜尋、點進去」，預覽頁照位置滑與點（那一頁的元件不在主畫面的元件樹裡），找不到任何一步就跳過不擋線。run 43747150455（commit `a45545d`）20 條全過，截圖 `Widget-05` 到 `Widget-08`：小的「境界 金丹中期、本週 4 天」，中的多「距金丹後期還差 0.6 公斤肌肉」，加到主畫面後一樣。
  - 看圖發現中的那句斷在「公／斤」中間，改成一行一句（`WidgetSnapshot.detailLines`，commit `7b1c330`）。run 43749476412 全綠（20 條），截圖看過：中的右邊是「距金丹後期」「還差 0.6 公斤肌肉」兩行，排好了。
  - 同一輪 run 43744487735 提醒日選單那條偶發紅過一次（Failed to determine hittability，選單動畫中），已在 `RencanUITestCase.visibleElement` 修掉（commit `8b93743`，work/app 的 run 43747120322 綠）。
- **小工具已經出版：TestFlight 1.0（28）。** 多米 04:00 左右在 Apple 後台把 `org.domyweb.rencan.widget` 弄好，重跑 run 43753698405 三個工作全綠：兩張描述檔都申請到、手動簽章的 archive 與匯出都過、上傳成功、測試說明已填。中間的經過：
  - 第一輪 run 43752942573 archive 紅，「Your account has reached the maximum number of certificates」。archive 原本走自動簽章，CI 機器每跑一次就向 Apple 要一張新的開發憑證，累積到帳號上限。改成手動簽章（commit `8b5afe5`）：先申請上架用描述檔，archive 直接用鑰匙圈裡的 Apple Distribution；`project.pbxproj` 兩個 target 的 Release 設定寫死 `CODE_SIGN_STYLE = Manual`、簽章身分與描述檔名字。
  - 第二、三輪紅在「Apple 後台沒有 App ID org.domyweb.rencan.widget」（多米第一次登記沒成功）。`appstore_profile.mjs` 現在找不到 App ID 時會把後台名字相近的列出來。
  - 小工具在真機上還沒有人看過：主畫面小的、中的，鎖定畫面圓形的，記一筆後有沒有更新，點了會不會開到境界頁。驗收清單第九段。
  - 改簽章設定後 `work/app` 的檢查線：run 43753694245 紅在「按住一筆刪除」（模擬器忙的時候按住 1.2 秒被當成點一下，開了編輯表單；跟簽章無關），測試改成沒跳出選單就關掉表單、按久一點再試（commit `b0be23f`），run 43756748803 全綠。小工具截圖那條在模擬器忙的時候也可能按不出選單，照設計會跳過不擋線。
- 帳號裡累積了很多 CI 要來的開發憑證（Apple Development，Created via API）。人蔘修煉這條線已經不再要新的，但多米其他照抄這條 CI 的 iOS 專案（archive 走自動簽章的）現在也會撞到同一個上限。要嘛那些專案也改手動簽章，要嘛多米到後台 Certificates 把用不到的開發憑證撤掉。撤憑證是他帳號的事，AI 不要自己動。
- 鎖定畫面的圓形小工具只有真機驗得到。
- 文件還沒跟上實作的地方：`.vibe/安全標準.md` 類別 8 寫「只申請四種讀取」，現在是五種（多了生理性別，多米 11-15 定的）；PRD S17、S26、S6 與代決清單裡寫的那幾處。片 J3 做安全閘門時一起對。
- J2–J4（App Store Connect 的 app 記錄、截圖、說明、隱私問卷、送審）都要多米操作，還沒開始。
- 隱私政策標「需多米補充」的三處與網址還沒定。

## 📌 關鍵決策（這次定下來的，下次別再爭論）

- 上一份的關鍵決策照舊：中途推 `work/**`、一整塊綠了才併 main；畫面數字全部由 `Digest` 算；資料只透過 `StoreService` 改；刪除修煉用按住選單。
- XCUITest 裡慶祝畫面不自己關（`-rencanHoldCelebration`）。Limrun 走流程不帶這個參數，照真實的 4.5 秒。
- 小工具的快照存「這一週有修煉的日期」，不存天數；小工具每天午夜自己重數，跨週會歸零。
- 快照裡不放體重、體脂率、FFMI。鎖定畫面的圓形只放本週天數。
- 小工具用系統字，不帶文楷字型（15 MB）。
- 寫快照失敗不算存檔失敗：把舊快照拿掉，小工具改顯示「打開 app 更新」。
- 檢查線的模擬器版用本機臨時簽章。主線的模擬器版建置（給 Limrun 的那一步）還是不簽章，沒動。
- 小工具的純計算放 RencanCore、可以先進 main；會動到簽章的（target、entitlements、ios.yml）留在 `work/widget`。

## 📂 下個會話最重要的檔案

- `docs/一次驗收清單.md`：多米驗收用，他回報的問題照這份的段落對
- `.vibe/切片帳本.md`、`.vibe/代決清單.md`
- `ios/RencanWidget/`、`ios/Rencan/Services/WidgetBridge.swift`、`ios/RencanUITests/WidgetUITests.swift`（都只在 `work/widget`）
- `ios/RencanCore/Sources/RencanCore/WidgetSnapshot.swift`
- `.vibe/tools/limrun_walk.mjs`：第三個參數可以只走指定段落（`demo,best,fresh,mascot,widget,snapshot`）
- `.vibe/tools/dev/watch_check.sh`：等檢查線、抓錯誤行與截圖
- `ios/ci/README.md` 第四段最後：小工具 App ID 的登記步驟

## ⏭️ 下一步從哪繼續

1. `git status --short`、`git branch -vv`：`main`、`work/app`、`work/widget` 應該在同一條線上（小工具已併）。之後只用 `work/app` 一個工作分支就好。
2. `gh run list --workflow=ios.yml --limit 3` 看主線，最後一次成功是 run 43753698405（build 28）。
3. 問多米驗收清單走得怎麼樣（含第九段小工具）。
4. 他回報的問題照清單的段落一條一條修，推 `work/app`，檢查線綠了 fast-forward 併 main。
5. 多米回報的問題照 `docs/一次驗收清單.md` 的段落一條一條修，修完推 `work/app`，綠了併 main。
6. 都過了再做 J2–J4。

## 🗑️ 這次會話的雜訊（下次別重新討論）

- 第三輪那條紅燈不用再查 app 有沒有卡：Limrun 實機量過，慶祝 0.9 秒就出來。
- Limrun 上不要再試加小工具，清單是空的。
- Bash 的 heredoc 超過 8KB 會壞、反斜線會被吃掉：長的 Python 腳本用 Write 寫成檔再跑，含 `\n` 的替換用 Edit。
- 截圖都在會話的暫存區，重開機可能不見，要看就重抓各輪的 artifact。
