import XCTest

// 「今天的修煉」的編輯與刪除（PRD S15），都從示範資料起手：今天有坐馬樁 100 公斤、推山掌 62.5 公斤兩筆。
// 刪除有兩條路：左滑（隱藏手勢）與編輯表單裡的刪除鈕。兩條各自一個測試，一條掛掉不會擋住另一條的截圖。

extension RencanUITestCase {
    /// 開示範資料、把境界頁往下捲到「今天的修煉」整塊露出來（最下面那列才不會被底部按鈕擋住）。
    func launchDemoAtTodayList() {
        launch(["-rencanSeed", "demo"])
        seeText("目前境界", timeout: 30)
        scrollDown()
    }

    /// 刪掉之後：出現「復原」、那一筆不見；按復原、那一筆回來。
    /// 「復原」只留 5 秒，所以這一段只做最少的查詢。
    func undoDelete(of rows: XCUIElementQuery, what: String) {
        require(app.buttons["復原"].firstMatch, "刪除後的「復原」按鈕", timeout: 4)
        shot("刪除後出現復原")
        let isRowGone = waitUntil(timeout: 1.5) { rows.count == 0 }
        XCTAssertTrue(isRowGone, "刪了之後\(what)還在清單上")
        tapButton("復原", timeout: 3)
        requireVisible(rows, "按復原後回來的\(what)")
        let isBarGone = waitUntil(timeout: 8) { !app.buttons["復原"].exists }
        XCTAssertTrue(isBarGone, "按了復原，「已刪除一筆修煉」那一條沒有收掉")
        shot("復原後那筆回來")
    }
}

/// 點一筆進編輯，用加減鈕改重量與組數，存回去，清單上的字跟著變。
final class EditUITests: RencanUITestCase {
    func test點一筆改數字存回清單更新() {
        launchDemoAtTodayList()
        let oldRows = anyElements(containing: "100 公斤 × 5 下 × 3 組")
        let row = requireVisible(oldRows, "今天的坐馬樁 100 公斤那一筆")
        shot("今天的修煉")
        row.tap()
        seeText("編輯這一筆")
        let save = require(app.buttons["存回去"], "編輯表單的「存回去」按鈕")
        waitForText("組數 3")
        shot("編輯表單")

        tapButton("重量加 2.5 公斤")
        tapButton("組數加一")
        waitForText("組數 4")
        shot("改成102點5公斤4組")

        save.tap()
        let isClosed = waitUntil(timeout: 5) { !save.exists }
        XCTAssertTrue(isClosed, "按了「存回去」，編輯表單沒有收回去")
        shot("存回去之後")
        let newRows = anyElements(containing: "102.5 公斤 × 5 下 × 4 組")
        requireVisible(newRows, "改成 102.5 公斤 4 組的那一筆")
        XCTAssertEqual(oldRows.count, 0, "存回去之後，舊的 100 公斤 3 組還在清單上")
        requireVisible(anyElements(containing: "62.5 公斤 × 5 下 × 3 組"), "沒動到的推山掌那一筆")
    }
}

/// 按住一列跳出選單，選「刪除」，底部出現「復原」，按了那一筆回來。
/// 原本是左滑刪除；2026-11-16 檢查線實測，左滑被左右換頁攔掉，所以 app 改成按住。
final class HoldDeleteUITests: RencanUITestCase {
    func test按住一筆刪除再復原() {
        launchDemoAtTodayList()
        let rows = anyElements(containing: "62.5 公斤 × 5 下 × 3 組")
        let row = requireVisible(rows, "今天的推山掌那一筆")
        shot("按住之前")

        // 模擬器忙的時候，按住會被當成點一下而打開編輯表單（2026-11-16 檢查線紅過一次，
        // Limrun 與前幾輪都正常）。沒跳出選單就把表單關掉，按久一點再試。
        let delete = app.buttons["刪除"]
        for duration in [1.2, 2.0, 3.0] {
            row.press(forDuration: duration)
            if delete.waitForExistence(timeout: 4) { break }
            let cancel = app.buttons["取消"]
            if cancel.waitForExistence(timeout: 2) {
                cancel.tap()
            }
            _ = waitUntil(timeout: 2) { !cancel.exists }
        }
        require(delete, "按住之後選單裡的「刪除」")
        shot("按住跳出選單")
        delete.tap()
        undoDelete(of: rows, what: "推山掌那一筆")
    }
}

/// 另一條刪除的路：點一筆進編輯，按表單裡的「刪除這一筆」，同樣出現「復原」。
final class SheetDeleteUITests: RencanUITestCase {
    func test編輯表單裡刪除再復原() {
        launchDemoAtTodayList()
        let rows = anyElements(containing: "62.5 公斤 × 5 下 × 3 組")
        requireVisible(rows, "今天的推山掌那一筆").tap()
        seeText("編輯這一筆")
        let delete = require(app.buttons["刪除這一筆"], "編輯表單裡的「刪除這一筆」")
        shot("編輯表單有刪除鈕")

        delete.tap()
        // 表單收回去再截，才不會截到動畫的一半
        waitUntil(timeout: 2) { !delete.exists }
        undoDelete(of: rows, what: "推山掌那一筆")
    }
}
