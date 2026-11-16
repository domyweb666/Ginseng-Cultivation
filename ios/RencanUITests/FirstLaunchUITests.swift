import XCTest

/// 第一次打開（不帶 seed）：只問身高與性別。沒選性別不能開始，選了才出現「開始」，
/// 按下去進境界頁的空狀態，身高有存進設定。
final class FirstLaunchUITests: RencanUITestCase {
    func test第一次打開選性別後進境界頁() {
        launch()
        seeText("人蔘修煉", timeout: 30)
        let hint = seeText("選好性別再開始")
        XCTAssertFalse(app.buttons["開始"].exists, "還沒選性別就出現「開始」按鈕")
        shot("還沒選性別")

        // 灰色那一塊不是按鈕，點了不會離開這一頁
        hint.tap()
        seeText("選好性別再開始")
        XCTAssertFalse(app.staticTexts["還沒量過體組成"].exists, "沒選性別就進了境界頁")

        // 身高從 170 按加號加到 174，再選性別
        for _ in 0..<4 {
            tapButton("身高加一公分")
        }
        requireVisible(anyElements(containing: "174"), "身高 174")
        tapButton("男")
        requireVisible(app.buttons.matching(named("開始")), "選好性別後的「開始」按鈕")
        shot("身高174選了男")

        tapVisibleButton("開始")
        seeText("還沒量過體組成")
        waitForText("今天還沒記。練完記最重那一組就好，三十秒。")
        require(anyElements(containing: "雜役弟子").firstMatch, "宗門身分「雜役弟子」")
        shot("境界頁空狀態")

        // 剛才填的身高有存起來
        openTab("設定")
        requireVisible(anyElements(containing: "174"), "設定頁的身高 174")
        shot("設定頁身高174")
    }
}
