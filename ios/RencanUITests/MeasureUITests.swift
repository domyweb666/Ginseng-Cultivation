import XCTest

/// 手動量體組成，從還沒量過的狀態起手：開表單、三欄打數字、看到結算後的預覽、結算，
/// 第一次量測會跳「踏入仙途」的全螢幕慶祝，點一下關掉後境界碑有數字。
/// 身高 174、體重 70、體脂 15%、去脂體重 60 公斤 → FFMI 20.20，金丹中期。
final class MeasureUITests: RencanUITestCase {
    func test手動量體組成踏入仙途() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        shot("還沒量過")
        tapVisibleButton("手動輸入體組成")
        let submit = require(app.buttons["結算境界"], "體組成表單的「結算境界」按鈕")
        seeText("輸入體組成")
        shot("表單打開")
        // App Store 審查 1.4.1：出處要在這張表單上，不用捲就看得到。
        checkSourcesPage(shotName: "出處頁", scrolls: 4)
        seeText("輸入體組成")

        typeNumber("70", into: "weight")
        typeNumber("15", into: "bodyfat")
        typeNumber("60", into: "lean")
        shot("填好三欄")
        let preview = require(element(id: "measurement-preview"), "結算後的預覽")
        let previewText = preview.label
        XCTAssertTrue(previewText.contains("金丹中期"), "預覽不是金丹中期：\(previewText)")
        XCTAssertTrue(previewText.contains("FFMI 20.20"), "預覽不是 FFMI 20.20：\(previewText)")
        scrollFormUp()
        shot("預覽金丹中期")

        submit.tap()
        passCelebration(heading: "踏入仙途", shotName: "踏入仙途慶祝", sheetButton: submit)
        seeStele()
        requireVisible(anyElements(containing: "FFMI 20.20"), "境界碑上的 FFMI 20.20")
        requireVisible(anyElements(containing: "根基穩固・體脂 15.0%"), "境界碑上的根基那一行")
        XCTAssertFalse(app.staticTexts["還沒量過體組成"].exists, "量過了，空狀態還在")
        shot("境界碑有數字")
        // 來源列在境界碑下面，立繪變高之後可能要捲一下才看得到。
        scrollToSee(anyElements(containing: "70.0 公斤・體脂 15.0%"), "來源列的體重與體脂")
        shot("來源列")
    }

    /// 鍵盤開著的時候預覽可能被擋住，把表單往上推一點再截。
    private func scrollFormUp() {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        from.press(
            forDuration: 0.05, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3
        )
    }
}

/// 量過不只一次的人（示範資料），表單預覽要寫「境界看近 3 次的平均」：
/// 今天這筆加上 9 天前、40 天前，三筆都在 90 天內、體脂都在門檻以內。欄位已經帶了上次的數字，不用打。
final class MeasureAverageUITests: RencanUITestCase {
    func test預覽寫看近三次的平均() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        scrollDown()
        tapVisibleButton("手動輸入")
        require(app.buttons["結算境界"], "體組成表單的「結算境界」按鈕")
        let preview = require(element(id: "measurement-preview"), "結算後的預覽")
        let text = preview.label
        XCTAssertTrue(text.contains("境界看近 3 次的平均"), "預覽沒寫看近三次的平均：\(text)")
        requireVisible(idQuery("measurement-preview"), "畫面上的預覽")
        shot("預覽近三次平均")
    }
}

/// 連點兩下「結算境界」：慶祝照常出現，不會再跳出「蓋掉同一天」的確認（2026-11-25 手感審查）。
final class MeasureDoubleTapUITests: RencanUITestCase {
    func test連點結算只送一次() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        tapVisibleButton("手動輸入體組成")
        let submit = require(app.buttons["結算境界"], "體組成表單的「結算境界」按鈕")
        typeNumber("70", into: "weight")
        typeNumber("15", into: "bodyfat")

        submit.doubleTap()
        passCelebration(heading: "踏入仙途", shotName: "連點結算的慶祝", sheetButton: submit)
        XCTAssertEqual(app.alerts.count + app.sheets.count, 0, "連點兩下「結算境界」跳出了確認")
        seeStele()
    }
}
