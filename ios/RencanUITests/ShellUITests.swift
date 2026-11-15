import XCTest

/// 三頁外框：打開停在境界頁，齒輪到設定、分析圖示到分析，側頁有回境界的箭頭。
final class ShellUITests: RencanUITestCase {
    func testThreePages() {
        launch()
        waitForText("境界")
        shot("realm")

        tapButton("設定")
        waitForText("設定")
        shot("settings")
        tapButton("回境界")

        tapButton("分析")
        waitForText("分析")
        shot("analysis")
        tapButton("回境界")
        waitForText("境界")
    }
}
