import XCTest

// 立繪造型（組塊 M1）：從 `-rencanSeed demo` 起手（身高 174、男、金丹中期）。
// M1 每種造型都能直接選，沒有鎖也沒有購買。

/// 設定頁點「立繪造型」那一列、選青花瓷、預覽跟著換，回境界頁截境界碑換成青花瓷的樣子。
final class PortraitStyleUITests: RencanUITestCase {
    func test選青花瓷境界碑跟著換() {
        openDemoSettings()
        let row = requireVisible(idQuery("settings-portrait-style"), "設定頁「立繪造型」那一列")
        XCTAssertTrue(row.label.contains("原版"), "一開始的造型應該是原版，那一列寫的是：\(row.label)")
        shot("設定頁-立繪造型那一列")

        row.tap()
        requireVisible(idQuery("style-original"), "選造型頁的「原版」那格")
        XCTAssertTrue(element(id: "style-original").isSelected, "一開始選中的應該是原版")
        shot("選造型頁-原版")

        requireVisible(idQuery("style-celadon"), "選造型頁的「青花瓷」那格").tap()
        let preview = element(id: "style-preview-name")
        let isChanged = waitUntil(timeout: 5) { preview.label == "青花瓷" }
        XCTAssertTrue(isChanged, "點了青花瓷，預覽的名字沒有換成青花瓷（現在是：\(preview.label)）")
        XCTAssertTrue(element(id: "style-celadon").isSelected, "點了青花瓷，那格沒有變成選中")
        shot("選造型頁-選了青花瓷")
        scrollDown()
        requireVisible(idQuery("style-jade"), "最後一排的「翠玉」那格", timeout: 5)
        shot("選造型頁-捲到最後一排")

        tapVisibleButton("完成")
        let hasSaved = waitUntil(timeout: 5) {
            element(id: "settings-portrait-style").label.contains("青花瓷")
        }
        XCTAssertTrue(hasSaved, "關掉選造型頁之後，設定頁那一列沒有寫青花瓷")
        shot("設定頁-寫著青花瓷")

        backToRealmFromSettings()
        seeStele()
        shot("境界頁-境界碑換成青花瓷")
    }
}
