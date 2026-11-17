import XCTest

/// 三頁外框：打開停在境界頁；底部原生分頁列三格（設定、境界、分析）都換得了頁。
/// 帶 `-rencanSeed profile`（已填身高與性別），不然會停在第一次打開那頁。
final class ShellUITests: RencanUITestCase {
    func test分頁列換頁() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        let tabs = app.tabBars.buttons
        XCTAssertEqual(
            tabs.allElementsBoundByIndex.map(\.label), ["設定", "境界", "分析"],
            "分頁列由左到右應該是設定、境界、分析"
        )
        XCTAssertTrue(tabs.matching(named("境界")).firstMatch.isSelected, "打開時選中的不是境界")
        shot("境界頁")

        // 分析頁：切到功法段（分段的按鈕在 segmentedControls 裡，跟分頁列的「境界」分開找）
        openTab("分析")
        let segments = app.segmentedControls.buttons
        requireVisible(segments.matching(named("功法")), "分析頁分段的「功法」").tap()
        seeText("六門功法")
        shot("分析頁功法段")
        requireVisible(segments.matching(named("境界")), "分析頁分段的「境界」").tap()

        // 設定頁
        openTab("設定")
        seeText("身體")
        shot("設定頁")

        openTab("境界")
        seeText("還沒量過體組成")
        shot("回到境界頁")
    }
}
