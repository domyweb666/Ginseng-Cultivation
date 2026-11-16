import XCTest

// 設定頁「身體」以下的三區：提醒、資料（匯出、匯入、刪除全部紀錄）、權限與關於。
// 都從 `-rencanSeed demo` 起手：身高 174、男，三筆量測、十三筆修煉（UITestSupport.demoLifts）。
// UI 測試模式下通知不碰系統、問權限一律當允許，所以提醒開關打得開。
// 健康 app 那一區在 UI 測試模式下只有一句說明，這裡只捲過它，不查它的字。
// 不點的東西：系統分享表單、檔案選擇器、隱私政策、「到系統設定改」（會離開 app，或在模擬器上不穩）。
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

/// 設定頁全貌：從頂一路捲到底，每捲一次截一張。身體、提醒、資料、刪除全部紀錄、權限、關於都入鏡。
final class SettingsOverviewUITests: RencanUITestCase {
    func test設定頁從頭捲到尾每一區都在() {
        openDemoSettings()
        seeText("身體")
        requireVisible(anyElements(containing: "174"), "身高 174")
        shot("設定頁-頂")

        // 一次捲不到半個螢幕，三次夠捲到底；捲到底那一拖會回彈，先查一次元素等畫面停下來再截。
        let version = element(id: "about-version")
        for index in 1...3 {
            scrollDown()
            _ = version.waitForExistence(timeout: 2)
            shot("設定頁-往下捲\(index)")
        }
        requireVisible(idQuery("about-version"), "捲到底之後最下面的「版本」那一列", timeout: 5)
        checkSections()
    }

    /// 每一區都在。設定頁不是懶載入，捲到哪裡都找得到，所以放在截完圖之後才查。
    /// 匯入要過系統的檔案選擇器，不測，只確認那一列在。
    private func checkSections() {
        for title in ["身體", "提醒", "資料", "權限", "關於"] {
            waitForText(title)
        }
        require(element(id: "reminder-toggle"), "「每月量測提醒」開關")
        require(element(id: "reminder-day"), "提醒日那顆按鈕")
        require(element(id: "settings-export"), "「匯出紀錄」那一列")
        require(element(id: "settings-import"), "「匯入紀錄」那一列")
        require(element(id: "settings-delete-all"), "「刪除全部紀錄」那張卡")
        require(element(id: "about-notification-status"), "通知的授權狀態")
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

/// 匯出：點「匯出紀錄」跳出表單，上面寫量測 3 筆、修煉 13 筆與「含身體數據」的提醒。
/// 不點「分享檔案」（系統分享表單在模擬器上不穩），按「關閉」收掉。
final class SettingsExportUITests: RencanUITestCase {
    func test匯出表單寫對筆數再關閉() {
        openDemoSettings()
        let export = scrollToPlace(idQuery("settings-export"), "「匯出紀錄」那一列")
        require(element(id: "settings-import"), "「匯入紀錄」那一列")
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
        requireVisible(idQuery("settings-export"), "關閉表單後的「匯出紀錄」那一列")
        shot("關閉匯出表單之後")
    }
}

/// 刪除全部紀錄：先問一次。取消，紀錄還在；再來一次按「全部刪除」，量測與修煉都沒了，身高與性別留著。
/// 卡片上的字是「刪除全部紀錄」，確認的那顆是「全部刪除」，兩個字不一樣是故意的。
final class SettingsDeleteUITests: RencanUITestCase {
    func test刪除全部先取消再確認身高性別留著() {
        openDemoSettings()
        let confirm = openDeleteDialog()
        require(anyElements(containing: "量測 3 筆、修煉 13 筆").firstMatch, "確認視窗裡寫的筆數")
        shot("確認視窗")
        cancelDialog(confirm)
        shot("取消之後")
        backToRealmFromSettings()
        seeStele()
        requireVisible(anyElements(containing: "FFMI 20.32"), "取消之後還在的 FFMI 20.32")
        shot("取消之後境界頁紀錄還在")

        openTab("設定")
        let again = openDeleteDialog()
        again.tap()
        // 小提示只留 2.6 秒：先記下有沒有看到、照樣截圖往下走，最後才算帳，後面的圖才不會少。
        let toast = anyElements(containing: "已刪除全部紀錄").firstMatch
        let sawToast = toast.waitForExistence(timeout: 4)
        shot("全部刪除之後")
        let isGone = waitUntil(timeout: 5) { !again.exists }
        XCTAssertTrue(isGone, "按了「全部刪除」，確認視窗沒有收掉")

        checkRealmIsEmpty()
        checkProfileKept()
        XCTAssertTrue(sawToast, "全部刪除之後沒看到小提示「已刪除全部紀錄」")
    }

    /// 捲到「刪除全部紀錄」那張卡、點它，等確認視窗出來。回確認的那顆「全部刪除」。
    private func openDeleteDialog() -> XCUIElement {
        scrollToPlace(idQuery("settings-delete-all"), "「刪除全部紀錄」那張卡").tap()
        let confirm = require(app.buttons["全部刪除"].firstMatch, "確認視窗的「全部刪除」按鈕")
        require(anyElements(containing: "要刪除全部紀錄嗎").firstMatch, "確認視窗的標題")
        return confirm
    }

    /// 不刪了。底部動作表有「取消」就點它；確認視窗如果是從卡片旁邊長出來的小視窗（iOS 26），
    /// 上面沒有「取消」那顆，點視窗外面就是取消。
    private func cancelDialog(_ confirm: XCUIElement) {
        let cancel = app.buttons["取消"].firstMatch
        if cancel.waitForExistence(timeout: 2) && cancel.isHittable {
            cancel.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }
        let isGone = waitUntil(timeout: 5) { !confirm.exists }
        XCTAssertTrue(isGone, "取消之後，確認視窗還在")
    }

    /// 回境界頁：量測沒了是空狀態，修煉沒了宗門身分退回雜役弟子（示範資料原本是客卿）。
    private func checkRealmIsEmpty() {
        backToRealmFromSettings()
        seeText("還沒量過體組成")
        require(anyElements(containing: "雜役弟子").firstMatch, "修煉刪光後的宗門身分「雜役弟子」")
        let steleCount = anyElements(containing: "FFMI 20.32").count
        XCTAssertEqual(steleCount, 0, "全部刪除之後，境界碑上的 FFMI 20.32 還在")
        shot("全部刪除之後境界頁空了")
    }

    /// 身高與性別不算紀錄，全部刪除之後要留著。
    /// 分頁列會記住設定頁捲到哪（剛才捲到底按刪除），要先捲回最上面才看得到身高。
    private func checkProfileKept() {
        openTab("設定")
        for _ in 0..<8 where visibleElement(in: anyElements(containing: "174")) == nil {
            scrollUp()
        }
        requireVisible(anyElements(containing: "174"), "全部刪除之後還留著的身高 174")
        let male = requireVisible(app.buttons.matching(named("男")), "性別的「男」那一格")
        XCTAssertTrue(male.isSelected, "全部刪除之後，性別選中的不是「男」")
        shot("全部刪除之後設定頁身高性別還在")
    }
}

/// 權限與關於：通知的授權狀態、版本都有字。不點「隱私政策」與「到系統設定改」，點了會跳出 app。
final class SettingsAboutUITests: RencanUITestCase {
    func test權限與關於有通知狀態與版本() {
        openDemoSettings()
        scrollToSee(idQuery("about-version"), "「版本」那一列", maxDrags: 8)
        // 再捲一次確定到底，兩組都整塊露出來；查元素會等回彈停下來。
        scrollDown()
        let version = requireVisible(idQuery("about-version"), "「版本」那一列")
        let status = requireVisible(idQuery("about-notification-status"), "通知的授權狀態")
        shot("權限與關於")

        let versionText = version.label
        XCTAssertFalse(versionText.isEmpty, "「版本」那一列是空的")
        XCTAssertFalse(versionText.contains("未知"), "版本號讀不出來，上面寫的是：\(versionText)")
        let statusText = status.label
        let knownStates = ["還沒問過", "已允許", "沒有允許"]
        XCTAssertTrue(knownStates.contains(statusText), "通知的授權狀態不是預期的字：\(statusText)")
        waitForText("權限")
        waitForText("關於")
        require(element(id: "about-open-settings"), "「到系統設定改」那一列")
        require(element(id: "about-privacy"), "「隱私政策」那一列")
    }
}
