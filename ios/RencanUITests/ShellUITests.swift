import XCTest

/// 三頁外框：打開停在境界頁；左右滑換得了頁，齒輪、分析圖示、回境界箭頭也換得了頁。
/// 帶 `-rencanSeed profile`（已填身高與性別），不然會停在第一次打開那頁。
final class ShellUITests: RencanUITestCase {
    func test三頁左右滑與圖示換頁() {
        launch(["-rencanSeed", "profile"])
        seeText("境界", timeout: 30)
        seeText("還沒量過體組成")
        shot("境界頁")

        // 往右滑到左邊的設定頁，按箭頭回來
        app.swipeRight()
        seeText("設定")
        seeText("身體")
        shot("滑到設定頁")
        tapVisibleButton("回境界")
        seeText("還沒量過體組成")

        // 往左滑到右邊的分析頁，切到功法段，再滑回來
        app.swipeLeft()
        seeText("分析")
        shot("滑到分析頁")
        tapVisibleButton("功法")
        seeText("六門功法")
        shot("分析頁功法段")
        tapVisibleButton("境界")
        app.swipeRight()
        seeText("還沒量過體組成")

        // 齒輪與分析圖示是左右滑的看得見替身
        tapVisibleButton("設定")
        seeText("設定")
        app.swipeLeft()
        seeText("還沒量過體組成")
        tapVisibleButton("分析")
        seeText("分析")
        tapVisibleButton("回境界")
        seeText("還沒量過體組成")
        shot("回到境界頁")
    }
}
