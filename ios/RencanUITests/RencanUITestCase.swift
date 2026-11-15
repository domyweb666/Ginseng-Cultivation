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
        app.launchArguments = ["-rencanUITest"] + extra
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
        return app.staticTexts.containing(predicate).firstMatch
    }

    /// 點一顆按鈕（用無障礙標籤找）。
    func tapButton(_ label: String, timeout: TimeInterval = 10) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "沒看到按鈕「\(label)」")
        button.tap()
    }
}
