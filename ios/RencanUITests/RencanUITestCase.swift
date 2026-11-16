import XCTest

/// UI 測試的共用底座：開 app、找元件、截圖。
///
/// 這台開發機是 Windows，沒有模擬器；Limrun（片 A5）沒訂閱。所以畫面的機器自審改成：
/// GitHub Actions 的 macOS 機器開模擬器跑這些測試，每個畫面截一張圖，AI 下載回來看。
/// 截圖兩份：寫成 PNG 到環境變數 RENCAN_SCREENSHOT_DIR 指的資料夾（xcodebuild 用
/// TEST_RUNNER_RENCAN_SCREENSHOT_DIR 傳進來），也附進 .xcresult。
///
/// app 收到啟動參數 -rencanUITest 時用記憶體裡的資料庫、不碰健康 app、不排通知，
/// 每次測試都從乾淨狀態開始。
class RencanUITestCase: XCTestCase {
    var app: XCUIApplication!
    private var shotIndex = 0
    private var shotDir: URL?
    /// 正在截「失敗現場」。截圖自己出錯時不要再截一次。
    private var isShootingFailure = false

    /// 任何一個檢查沒過，先截一張「失敗現場」再照常記錄，看圖就知道當時畫面停在哪。
    override func record(_ issue: XCTIssue) {
        if !isShootingFailure {
            isShootingFailure = true
            shot("失敗現場")
            isShootingFailure = false
        }
        super.record(issue)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        if let dir = ProcessInfo.processInfo.environment["RENCAN_SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            shotDir = url
        }
        // 萬一跳出系統對話框（通知、健康 app），按同意讓流程走下去
        addUIInterruptionMonitor(withDescription: "系統對話框") { alert in
            for title in ["允許", "Allow", "好", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    /// 開 app。extra 是這支測試另外要的啟動參數（例如預先塞好的示範資料）。
    func launch(_ extra: [String] = []) {
        app.launchArguments = ["-rencanUITest", "-rencanHoldCelebration"] + extra
        app.launch()
    }

    /// 截一張圖。檔名前面自動加流水號，照走的順序排。
    func shot(_ name: String) {
        shotIndex += 1
        let prefix = String(describing: type(of: self)).replacingOccurrences(of: "UITests", with: "")
        let fileName = String(format: "%@-%02d-%@", prefix, shotIndex, name)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let shotDir else { return }
        do {
            let url = shotDir.appendingPathComponent(fileName + ".png")
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("截圖寫不進 \(shotDir.path)：\(error)")
        }
    }

    /// 等某段文字出現。
    @discardableResult
    func waitForText(_ text: String, timeout: TimeInterval = 10) -> XCUIElement {
        let element = app.staticTexts[text].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "沒看到「\(text)」")
        return element
    }

    /// 文字裡含某一段的元素（數字會變的句子用這個找）。
    func textContaining(_ part: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", part)
        return app.staticTexts.matching(predicate).firstMatch
    }

    /// 點一顆按鈕（用無障礙標籤找）。
    func tapButton(_ label: String, timeout: TimeInterval = 10) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "沒看到按鈕「\(label)」")
        button.tap()
    }
}

// MARK: 等待與尋找

extension RencanUITestCase {
    /// 等到條件成立，沒等到回 false。每隔一小段重看一次，不是固定睡幾秒。
    @discardableResult
    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return true }
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    /// 等一個元素出現，沒出現就 fail。
    @discardableResult
    func require(
        _ element: XCUIElement, _ what: String, timeout: TimeInterval = 10,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let isThere = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(isThere, "沒看到\(what)", file: file, line: line)
        return element
    }

    /// 用 identifier 找元素，不管它是哪一種元件。
    func idQuery(_ identifier: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    func element(id identifier: String) -> XCUIElement {
        idQuery(identifier).firstMatch
    }

    /// label 含某段字的元素，不管哪一種元件（合併成一個元素的列、卡片用這個找）。
    func anyElements(containing part: String) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "label CONTAINS %@", part)
        return app.descendants(matching: .any).matching(predicate)
    }

    /// label 或 identifier 剛好是這個字。
    func named(_ text: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR identifier == %@", text, text)
    }

    /// 查詢結果裡現在真的在畫面上、點得到的那一個。左右兩頁、被表單蓋住的不算。
    func visibleElement(in query: XCUIElementQuery) -> XCUIElement? {
        query.allElementsBoundByIndex.first { element in
            guard element.exists else { return false }
            // 選單、表單還在長出來的那一瞬間，元素的 frame 是空的；這時問 isHittable，XCUITest 會記一條
            // 「Failed to determine hittability」的失敗（2026-11-16 提醒日選單紅過一次）。frame 還沒有就先當沒看到。
            let frame = element.frame
            guard !frame.isEmpty, frame.minX.isFinite, frame.minY.isFinite else { return false }
            return element.isHittable
        }
    }

    /// 等查詢裡有一個元素真的出現在畫面上，沒等到就 fail。
    @discardableResult
    func requireVisible(
        _ query: XCUIElementQuery, _ what: String, timeout: TimeInterval = 15,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        var found: XCUIElement?
        let isSeen = waitUntil(timeout: timeout) {
            found = visibleElement(in: query)
            return found != nil
        }
        XCTAssertTrue(isSeen, "畫面上沒看到\(what)", file: file, line: line)
        return found ?? query.firstMatch
    }

    /// 等境界碑出現（量過體組成之後，境界頁最上面那張深色卡）。認的是立繪的旁白文字；
    /// 還沒量過時那張雜役服立繪唸的是別的字，不會認錯。
    @discardableResult
    func seeStele(
        timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let query = anyElements(containing: "期人蔘立繪")
        return requireVisible(query, "境界碑", timeout: timeout, file: file, line: line)
    }

    /// 等一段文字真的出現在畫面上（整段要一樣）。
    @discardableResult
    func seeText(
        _ text: String, timeout: TimeInterval = 15, file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let query = app.staticTexts.matching(named(text))
        return requireVisible(query, "文字「\(text)」", timeout: timeout, file: file, line: line)
    }

    /// 點畫面上看得到的那顆按鈕。三頁裡同名的按鈕（回境界）只點現在這頁的。
    func tapVisibleButton(
        _ label: String, timeout: TimeInterval = 15, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let query = app.buttons.matching(named(label))
        requireVisible(query, "按鈕「\(label)」", timeout: timeout, file: file, line: line).tap()
    }

    /// 點底部分頁列的那一格（境界、分析、設定），等它變成選中。
    /// 不用 tapVisibleButton：分析頁的分段也有一顆「境界」，同名會點錯。
    func openTab(
        _ label: String, timeout: TimeInterval = 15, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let query = app.tabBars.buttons.matching(named(label))
        let tab = requireVisible(
            query, "分頁列的「\(label)」", timeout: timeout, file: file, line: line
        )
        tab.tap()
        let isSelected = waitUntil(timeout: 5) { tab.isSelected }
        XCTAssertTrue(isSelected, "點了分頁列的「\(label)」，它沒有變成選中", file: file, line: line)
    }

    /// 幾個元素裡先出現的那一個；都沒出現回 nil。
    func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for element in elements where element.waitForExistence(timeout: 0.3) {
                return element
            }
        } while Date() < deadline
        return nil
    }
}

// MARK: 手勢與輸入

extension RencanUITestCase {
    private func drag(fromY: CGFloat, toY: CGFloat) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        from.press(
            forDuration: 0.05, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3
        )
    }

    /// 把現在這頁往下捲大約半個螢幕。慢慢拖、放開前停一下，不會滑過頭漏掉中間的內容。
    func scrollDown() {
        drag(fromY: 0.72, toY: 0.28)
    }

    /// 往回捲同樣的距離。
    func scrollUp() {
        drag(fromY: 0.28, toY: 0.72)
    }

    /// 往下捲幾次，每捲一次截一張。
    func scrollShots(_ name: String, count: Int) {
        for index in 1...count {
            scrollDown()
            shot("\(name)-往下捲\(index)")
        }
    }

    /// 一直往下捲到某個元素出現在畫面上。
    @discardableResult
    func scrollToSee(_ query: XCUIElementQuery, _ what: String, maxDrags: Int = 4) -> XCUIElement {
        for _ in 0..<maxDrags where visibleElement(in: query) == nil {
            scrollDown()
        }
        return requireVisible(query, what, timeout: 5)
    }

    /// 在數字欄打字。模擬器沒接硬體鍵盤，點了欄位等螢幕鍵盤出來再打。
    func typeNumber(_ text: String, into identifier: String) {
        let field = require(app.textFields[identifier], "輸入欄 \(identifier)")
        field.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        field.typeText(text)
        let typed = field.value as? String
        XCTAssertEqual(typed, text, "輸入欄 \(identifier) 打進去的字不對")
    }

    /// 全螢幕慶祝：等它出來、確認小標題、截圖、點一下、等它關掉。
    /// 測試啟動時帶了 -rencanHoldCelebration，慶祝不會自己關，等這裡點掉：XCUITest 每個動作前
    /// 會等 app 閒下來，等得久的時候 4.5 秒的慶祝已經關了。點的是螢幕上的位置，不是元素。
    func passCelebration(heading: String, shotName: String, sheetButton: XCUIElement) {
        let celebration = element(id: "celebration")
        require(celebration, "慶祝畫面「\(heading)」", timeout: 8)
        let label = celebration.label
        // 表單收回去、鍵盤降下去再截，才不會截到動畫的一半
        waitUntil(timeout: 2) { !sheetButton.exists && !app.keyboards.firstMatch.exists }
        shot(shotName)
        XCTAssertTrue(label.contains(heading), "慶祝畫面不是「\(heading)」，上面寫的是：\(label)")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        let isClosed = waitUntil(timeout: 8) { !celebration.exists }
        XCTAssertTrue(isClosed, "點了一下，慶祝畫面沒有關掉")
    }
}
