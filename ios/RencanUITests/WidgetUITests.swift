import XCTest

/// 小工具（組塊 G）：示範資料打開 app 寫好快照，回主畫面把小工具加上去，截圖看樣子。
///
/// 主畫面是系統的畫面，按鈕叫什麼、清單長怎樣每版 iOS 都可能不一樣，所以這支只負責截圖：
/// 哪一步找不到就截一張、把當時畫面上的元件印進紀錄、這支標成跳過，不讓整條檢查線變紅。
/// 鎖定畫面的圓形小工具這裡加不了，留給真機。
final class WidgetUITests: RencanUITestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let appName = "人蔘修煉"

    func test主畫面加小工具看樣子() throws {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        XCUIDevice.shared.press(.home)

        // 按住自己的圖示會跳選單，裡面有「編輯主畫面」；比按空白處穩，空白處在哪每台模擬器不一樣。
        let icon = try find(springboard.icons[appName], "主畫面上的 app 圖示")
        icon.press(forDuration: 1.3)
        shot("按住圖示之後")
        let editHome = try find(firstExisting(["Edit Home Screen", "編輯主畫面"]), "選單裡的編輯主畫面")
        editHome.tap()

        let edit = try find(firstExisting(["Edit", "編輯"]), "左上角的編輯")
        edit.tap()
        shot("點編輯之後")
        let addMenu = try find(firstExisting(["Add Widget", "加入小工具"]), "選單裡的加入小工具")
        addMenu.tap()

        let search = try find(springboard.searchFields.firstMatch, "小工具清單的搜尋欄", timeout: 15)
        shot("小工具清單")
        search.tap()
        search.typeText(appName)
        shot("搜尋人蔘修煉")

        let inList = NSPredicate(format: "label CONTAINS %@", appName)
        let cell = springboard.collectionViews.cells.matching(inList).firstMatch
        let row = try find(cell, "清單裡的人蔘修煉", timeout: 10)
        row.tap()

        // 預覽頁裡的東西不在主畫面的元件樹裡（2026-11-16 第一趟印出來的樹只有主畫面的圖示），
        // 所以這一頁照位置操作：中間那排左右滑換尺寸，最下面那顆藍色的是「Add Widget」。
        _ = waitUntil(timeout: 2.5) { false }
        shot("預覽-小的")
        let carouselRight = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.57))
        let carouselLeft = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.57))
        carouselRight.press(forDuration: 0.05, thenDragTo: carouselLeft)
        _ = waitUntil(timeout: 1.5) { false }
        shot("預覽-中的")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.905)).tap()
        _ = waitUntil(timeout: 2) { false }
        shot("加到主畫面")

        let done = firstExisting(["Done", "完成"])
        if done.waitForExistence(timeout: 5) {
            done.tap()
        }
        _ = waitUntil(timeout: 3) { false }
        shot("主畫面上的小工具")
    }

    /// 中英文的名字都試，回第一個找得到的；都沒有就回第一個名字的按鈕，讓 find 去報找不到。
    private func firstExisting(_ labels: [String]) -> XCUIElement {
        for label in labels {
            let button = springboard.buttons[label].firstMatch
            if button.waitForExistence(timeout: 3) { return button }
            let text = springboard.staticTexts[label].firstMatch
            if text.exists { return text }
        }
        return springboard.buttons[labels[0]].firstMatch
    }

    /// 等一個元素出現。沒出現：截圖、把主畫面現在有哪些元件印進紀錄、這支測試標成跳過。
    private func find(
        _ element: XCUIElement, _ what: String, timeout: TimeInterval = 8
    ) throws -> XCUIElement {
        if element.waitForExistence(timeout: timeout) { return element }
        shot("找不到-" + what)
        print("WIDGET-DEBUG 找不到\(what)，主畫面現在的元件：\n\(springboard.debugDescription)")
        throw XCTSkip("小工具：找不到\(what)，看截圖與紀錄")
    }
}
