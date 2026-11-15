import XCTest

/// 手動量體組成，從還沒量過的狀態起手：開表單、三欄打數字、看到結算後的預覽、結算，
/// 第一次量測會跳「踏入仙途」的全螢幕慶祝，點一下關掉後境界碑有數字。
/// 身高 174、體重 70、體脂 15%、去脂體重 60 公斤 → FFMI 20.18，金丹中期。
final class MeasureUITests: RencanUITestCase {
    func test手動量體組成踏入仙途() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        shot("還沒量過")
        tapVisibleButton("手動輸入體組成")
        let submit = require(app.buttons["結算境界"], "體組成表單的「結算境界」按鈕")
        seeText("輸入體組成")
        shot("表單打開")

        typeNumber("70", into: "weight")
        typeNumber("15", into: "bodyfat")
        typeNumber("60", into: "lean")
        shot("填好三欄")
        let preview = require(element(id: "measurement-preview"), "結算後的預覽")
        let previewText = preview.label
        XCTAssertTrue(previewText.contains("金丹中期"), "預覽不是金丹中期：\(previewText)")
        XCTAssertTrue(previewText.contains("FFMI 20.18"), "預覽不是 FFMI 20.18：\(previewText)")
        scrollFormUp()
        shot("預覽金丹中期")

        submit.tap()
        passCelebration(heading: "踏入仙途", shotName: "踏入仙途慶祝", sheetButton: submit)
        seeText("目前境界")
        requireVisible(anyElements(containing: "FFMI 20.18"), "境界碑上的 FFMI 20.18")
        requireVisible(anyElements(containing: "根基穩固・體脂 15.0%"), "境界碑上的根基那一行")
        requireVisible(anyElements(containing: "70.0 公斤・體脂 15.0%"), "來源列的體重與體脂")
        XCTAssertFalse(app.staticTexts["還沒量過體組成"].exists, "量過了，空狀態還在")
        shot("境界碑有數字")
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
