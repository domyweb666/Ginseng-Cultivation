import XCTest

// 設定頁「身體」以下：提醒、一般、資料（匯出、匯入、清除所有資料）、購買、支援、關於與頁尾。
// 2026-11-19 照蔬菜家族共用規格重排，後面幾區用 VeggieKit 的共用元件。
// 都從 `-rencanSeed demo` 起手：身高 174、男，三筆量測、十三筆修煉（UITestSupport.demoLifts）。
// UI 測試模式下通知不碰系統、問權限一律當允許，所以提醒開關打得開。
// 健康 app 那一區在 UI 測試模式下只有一句說明，這裡只捲過它，不查它的字。
// 不點的東西：系統分享表單、檔案選擇器、隱私權政策、通知那列（會跳系統設定）、意見回饋（模擬器沒設郵件）。
// 一個流程一個類別：截圖檔名的流水號是每個測試各自從 01 起算，分開才不會撞名。

extension RencanUITestCase {
    /// 開示範資料，按齒輪到設定頁。
    func openDemoSettings() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        openTab("設定")
    }

    /// 往下捲一小段（大約五分之一個螢幕），微調位置用。
    func scrollDownALittle() {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        from.press(
            forDuration: 0.05, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3
        )
    }

    /// 往下捲到某個元素看得到，再一小段一小段把它帶到畫面上面 fraction 以內。
    /// 剛捲到看得到時它常常只露半列；帶上來截圖才完整，選單與確認視窗也才有地方長出來。
    /// 內容已經到底、帶不上來就停在那裡，不算失敗。
    @discardableResult
    func scrollToPlace(
        _ query: XCUIElementQuery, _ what: String, within fraction: CGFloat = 0.6
    ) -> XCUIElement {
        let found = scrollToSee(query, what, maxDrags: 8)
        let limit = app.frame.height * fraction
        for _ in 0..<4 where found.frame.midY > limit {
            scrollDownALittle()
        }
        return requireVisible(query, what, timeout: 5)
    }

    /// 點分頁列的「境界」回境界頁。
    func backToRealmFromSettings() {
        openTab("境界")
    }

    /// 開關現在的狀態："1" 是開，"0" 是關。
    func switchValue(_ toggle: XCUIElement) -> String {
        (toggle.value as? String) ?? ""
    }

    /// 點開關的圓鈕。SwiftUI 的開關連左邊的字是同一個元素，點正中間會點在字上、不會切換，
    /// 所以點它右緣往內一點、圓鈕在的位置。
    func tapSwitchKnob(_ toggle: XCUIElement) {
        let edge = toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        edge.withOffset(CGVector(dx: -28, dy: 0)).tap()
    }

    /// 點過之後等開關變成要的狀態，沒變就 fail。
    /// 點右緣沒切過去時（有的系統版本開關裡面還包一層），改點裡面那一顆再試一次。
    func confirmSwitch(_ toggle: XCUIElement, becomes wanted: String, _ what: String) {
        let isFlipped = waitUntil(timeout: 3) { switchValue(toggle) == wanted }
        if !isFlipped {
            let inner = toggle.switches.firstMatch
            if inner.exists {
                inner.tap()
            } else {
                toggle.tap()
            }
        }
        let isSet = waitUntil(timeout: 5) { switchValue(toggle) == wanted }
        let state = wanted == "1" ? "開" : "關"
        XCTAssertTrue(isSet, "點了\(what)的開關，它沒有變成「\(state)」")
    }
}

/// 設定頁全貌：從頂一路捲到底，每捲一次截一張。每一區和頁尾都入鏡。
final class SettingsOverviewUITests: RencanUITestCase {
    func test設定頁從頭捲到尾每一區都在() {
        openDemoSettings()
        seeText("身體")
        requireVisible(anyElements(containing: "174"), "身高 174")
        shot("設定頁-頂")

        // 一次捲不到半個螢幕，區塊變多了，捲六次才到底；捲到底那一拖會回彈，先查一次元素等畫面停下來再截。
        let version = element(id: "veggie-version")
        for index in 1...6 {
            scrollDown()
            _ = version.waitForExistence(timeout: 2)
            shot("設定頁-往下捲\(index)")
        }
        requireVisible(idQuery("veggie-version"), "捲到底之後頁尾的版本號", timeout: 5)
        checkSections()
    }

    /// 每一區都在。設定頁不是懶載入，捲到哪裡都找得到，所以放在截完圖之後才查。
    /// 匯入要過系統的檔案選擇器，不測，只確認那一列在。
    private func checkSections() {
        for title in ["身體", "提醒", "一般", "資料", "購買", "支援", "關於"] {
            waitForText(title)
        }
        require(element(id: "reminder-toggle"), "「每月量測提醒」開關")
        require(element(id: "reminder-day"), "提醒日那顆按鈕")
        require(element(id: "settings-appearance"), "「外觀」那一列")
        require(element(id: "settings-notifications"), "「通知」那一列")
        require(element(id: "settings-haptics"), "「觸覺回饋」開關")
        require(element(id: "settings-export"), "「匯出資料」那一列")
        require(element(id: "settings-import"), "「匯入資料」那一列")
        require(element(id: "settings-erase-all"), "「清除所有資料」那一列")
        require(element(id: "settings-restore"), "「恢復購買」那一列")
        require(element(id: "settings-feedback"), "「意見回饋」那一列")
        require(element(id: "settings-share"), "「分享給朋友」那一列")
        require(element(id: "about-family"), "「蔬菜家族的其他 app」那一列")
        require(element(id: "about-privacy"), "「隱私權政策」那一列")
        require(element(id: "about-licenses"), "「開源授權」那一列")
    }
}

/// 每月提醒：打開開關（說明那一列閃一下）、改提醒日成每月 5 日、再關掉。
final class SettingsReminderUITests: RencanUITestCase {
    func test每月提醒打開改提醒日再關掉() {
        openDemoSettings()
        // 提醒日帶到畫面上半：選單才會往下長，「每月 5 日」不用在選單裡捲就點得到。
        scrollToPlace(idQuery("reminder-day"), "提醒日那顆按鈕", within: 0.4)
        let toggle = requireVisible(idQuery("reminder-toggle"), "「每月量測提醒」開關")
        XCTAssertEqual(switchValue(toggle), "0", "提醒一開始應該是關的")
        requireVisible(anyElements(containing: "每月 1 日 08:00"), "一開始的提醒日「每月 1 日 08:00」")
        shot("提醒-還沒開")

        turnOnAndCatchExplain(toggle)
        pickDayFive()
        XCTAssertEqual(switchValue(toggle), "1", "改了提醒日，提醒開關被關掉了")
        shot("提醒-改成每月5日")

        tapSwitchKnob(toggle)
        confirmSwitch(toggle, becomes: "0", "「每月量測提醒」")
        requireVisible(anyElements(containing: "每月 5 日 08:00"), "關掉提醒後還留著的提醒日")
        shot("提醒-關掉")
    }

    /// 打開開關。開關下面那句說明只出現約 1.2 秒就收掉：抓得到就截，抓不到不算失敗，圖照截。
    private func turnOnAndCatchExplain(_ toggle: XCUIElement) {
        let explain = element(id: "reminder-explain")
        tapSwitchKnob(toggle)
        let sawExplain = explain.waitForExistence(timeout: 2.5)
        shot(sawExplain ? "提醒-打開時的說明" : "提醒-打開時沒抓到說明")
        confirmSwitch(toggle, becomes: "1", "「每月量測提醒」")

        // 說明收掉代表權限問完、設定存好了；這時候開關要還是開的，沒有彈回去。
        waitUntil(timeout: 5) { !explain.exists }
        let isStillOn = waitUntil(timeout: 3) { switchValue(toggle) == "1" }
        XCTAssertTrue(isStillOn, "說明收掉之後，提醒開關彈回關的位置")
        XCTAssertFalse(element(id: "reminder-denied").exists, "權限當作允許，卻出現「沒有允許發通知」")
        shot("提醒-開了")
    }

    /// 點提醒日那顆按鈕跳出選單，選「每月 5 日」，按鈕上的字跟著變。
    private func pickDayFive() {
        requireVisible(idQuery("reminder-day"), "提醒日那顆按鈕").tap()
        let exactLabel = NSPredicate(format: "label == %@", "每月 5 日")
        // 選單裡同一個字有兩個元素：外層的格子（Other）和裡面的按鈕。問外層那個點不點得到，
        // XCUITest 會直接記一條失敗（2026-11-16 檢查線連紅兩次）。所以先只在按鈕裡找，
        // 這一版系統的選單沒有按鈕才退回原本的找法。
        let buttons = app.buttons.matching(exactLabel)
        let hasButton = buttons.firstMatch.waitForExistence(timeout: 8)
        let options = hasButton ? buttons : app.descendants(matching: .any).matching(exactLabel)
        let option = requireVisible(options, "提醒日選單裡的「每月 5 日」", timeout: 8)
        shot("提醒日選單")
        option.tap()
        requireVisible(anyElements(containing: "每月 5 日 08:00"), "改好的提醒日「每月 5 日 08:00」")
    }
}

/// 匯出：點「匯出資料」跳出表單，上面寫量測 3 筆、修煉 13 筆與「含身體數據」的提醒。
/// 不點「分享檔案」（系統分享表單在模擬器上不穩），按「關閉」收掉。
final class SettingsExportUITests: RencanUITestCase {
    func test匯出表單寫對筆數再關閉() {
        openDemoSettings()
        let export = scrollToPlace(idQuery("settings-export"), "「匯出資料」那一列")
        require(element(id: "settings-import"), "「匯入資料」那一列")
        shot("資料區")

        export.tap()
        let summary = require(element(id: "export-summary"), "匯出表單上的筆數")
        let counts = summary.label
        XCTAssertTrue(counts.contains("量測 3 筆"), "匯出表單不是「量測 3 筆」，上面寫的是：\(counts)")
        XCTAssertTrue(counts.contains("修煉 13 筆"), "匯出表單不是「修煉 13 筆」，上面寫的是：\(counts)")
        let reminder = require(element(id: "export-reminder"), "匯出表單上「含身體數據」的提醒")
        let reminderText = reminder.label
        XCTAssertTrue(reminderText.contains("身體數據"), "匯出前的提醒沒講到身體數據：\(reminderText)")
        require(element(id: "export-share"), "匯出表單的「分享檔案」按鈕")
        shot("匯出表單")

        tapButton("關閉")
        let isClosed = waitUntil(timeout: 5) { !summary.exists }
        XCTAssertTrue(isClosed, "按了「關閉」，匯出表單沒有收回去")
        requireVisible(idQuery("settings-export"), "關閉表單後的「匯出資料」那一列")
        shot("關閉匯出表單之後")
    }
}

/// 清除所有資料：問兩次。第一次取消，紀錄還在；再來一次按「繼續」、再按「刪除所有資料」，
/// 量測、修煉、身高性別全部清掉，回到第一次打開那頁。兩次的按鈕字不一樣是故意的。
final class SettingsEraseUITests: RencanUITestCase {
    func test清除所有資料問兩次刪完回到第一次打開() {
        openDemoSettings()
        let proceed = openEraseDialog()
        require(anyElements(containing: "量測 3 筆、修煉 13 筆").firstMatch, "第一次確認裡寫的筆數")
        require(app.buttons["先匯出"].firstMatch, "第一次確認的「先匯出」")
        shot("第一次確認")
        tapButton("取消")
        let isGone = waitUntil(timeout: 5) { !proceed.exists }
        XCTAssertTrue(isGone, "按了「取消」，確認視窗還在")
        backToRealmFromSettings()
        seeStele()
        requireVisible(anyElements(containing: "FFMI 20.32"), "取消之後還在的 FFMI 20.32")
        shot("取消之後境界頁紀錄還在")

        openTab("設定")
        openEraseDialog().tap()
        let erase = require(app.buttons["刪除所有資料"].firstMatch, "第二次確認的「刪除所有資料」")
        shot("第二次確認")
        erase.tap()
        // 清完畫面整個換成第一次打開那頁（不跳小提示：提示掛在分頁上，分頁已經不在了）。
        seeText("先說你多高、男生還是女生，境界就能算。")
        shot("清除之後回到第一次打開")
        XCTAssertEqual(anyElements(containing: "FFMI 20.32").count, 0, "清除之後 FFMI 20.32 還在")
    }

    /// 捲到「清除所有資料」、點它，等第一次確認出來。回那顆「繼續」。
    private func openEraseDialog() -> XCUIElement {
        scrollToPlace(idQuery("settings-erase-all"), "「清除所有資料」那一列").tap()
        require(anyElements(containing: "要清除所有資料嗎").firstMatch, "第一次確認的標題")
        return require(app.buttons["繼續"].firstMatch, "第一次確認的「繼續」")
    }
}

/// 一般與關於：通知那列寫得出狀態、頁尾有版本號；點「開源授權」看得到霞鶩文楷的授權全文再關掉。
/// 不點「通知」與「隱私權政策」，點了會跳出 app。
final class SettingsAboutUITests: RencanUITestCase {
    func test通知狀態版本號與開源授權() {
        openDemoSettings()
        let status = scrollToPlace(idQuery("settings-notifications"), "「通知」那一列")
        let statusText = status.label
        let knownStates = ["還沒問過", "已開啟", "已關閉"]
        let isKnown = knownStates.contains { statusText.contains($0) }
        XCTAssertTrue(isKnown, "通知那一列沒有寫出狀態：\(statusText)")
        shot("一般")

        scrollToSee(idQuery("veggie-version"), "頁尾的版本號", maxDrags: 8)
        // 再捲一次確定到底，關於和頁尾整塊露出來；查元素會等回彈停下來。
        scrollDown()
        let version = requireVisible(idQuery("veggie-version"), "頁尾的版本號")
        shot("關於與頁尾")
        let versionText = version.label
        XCTAssertTrue(versionText.contains("人蔘修煉"), "頁尾版本號沒有 app 名字：\(versionText)")
        XCTAssertTrue(versionText.contains("（"), "頁尾版本號沒有建置號：\(versionText)")

        requireVisible(idQuery("about-licenses"), "「開源授權」那一列").tap()
        let fontRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "霞鶩文楷"))
        let font = require(fontRow.firstMatch, "授權頁的「霞鶩文楷 TC」")
        shot("開源授權")
        font.tap()
        let fullText = require(textContaining("SIL OPEN FONT LICENSE"), "霞鶩文楷的授權全文")
        shot("霞鶩文楷授權全文")
        // 全文頁是推進去的第二層，左上角是返回；「關閉」在第一層
        app.navigationBars.buttons.firstMatch.tap()
        require(fontRow.firstMatch, "返回之後的授權清單")
        tapButton("關閉")
        let isClosed = waitUntil(timeout: 5) { !fullText.exists && !fontRow.firstMatch.exists }
        XCTAssertTrue(isClosed, "按了「關閉」，開源授權頁沒有收回去")
    }
}
