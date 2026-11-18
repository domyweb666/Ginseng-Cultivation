import XCTest

// 立繪造型（組塊 M1 換造型、M4 加鎖與購買）：從 `-rencanSeed demo` 起手（身高 174、男、金丹中期）。
// UI 測試模式下內購走假商店（PurchaseService）：不碰 App Store，價格固定 NT$120、全套 NT$480，
// 按購買直接算買到。真的 App Store 付款只有 TestFlight 的沙盒驗得到（docs/一次驗收清單.md）。

extension RencanUITestCase {
    /// 開示範資料，到設定頁點「立繪造型」那一列，等選造型頁出來。extra 是另外的啟動參數。
    func openStylePage(_ extra: [String] = []) {
        launch(["-rencanSeed", "demo"] + extra)
        seeStele(timeout: 30)
        openTab("設定")
        requireVisible(idQuery("settings-portrait-style"), "設定頁「立繪造型」那一列").tap()
        requireVisible(idQuery("style-original"), "選造型頁的「原版」那格")
    }

    /// 點選造型頁的一格（捲到看得到才點）。底下固定的購買鍵會蓋住最下面那排的一部分，
    /// 那格被蓋到就再往下捲一點，免得點到購買鍵（假商店一按就算買了）。
    func tapStyle(_ code: String, _ name: String) {
        let cell = scrollToSee(idQuery("style-" + code), "選造型頁的「\(name)」那格")
        let buy = element(id: "style-buy")
        if buy.exists, cell.frame.maxY > buy.frame.minY - buyBarPadding {
            scrollDownALittle()
        }
        cell.tap()
    }

    /// 購買鍵上下的留白再多算一點
    private var buyBarPadding: CGFloat { 16 }

    /// 等預覽的名字換成這個造型。
    func waitPreview(_ name: String) {
        let preview = element(id: "style-preview-name")
        let isChanged = waitUntil(timeout: 5) { preview.label == name }
        XCTAssertTrue(isChanged, "預覽的名字沒有換成\(name)（現在是：\(preview.label)）")
    }
}

/// 沒買的造型點了只換預覽：底下出現購買鍵，關掉頁面後設定與境界碑還是原版。
final class PortraitStyleUITests: RencanUITestCase {
    func test沒買的造型只能預覽() {
        openStylePage()
        XCTAssertTrue(element(id: "style-original").isSelected, "一開始選中的應該是原版")
        XCTAssertFalse(element(id: "style-buy").exists, "原版免費，不該有購買鍵")
        let celadon = element(id: "style-celadon")
        XCTAssertTrue(celadon.label.contains("還沒買"), "青花瓷應該標著還沒買（現在是：\(celadon.label)）")
        shot("選造型頁-一開始")

        tapStyle("celadon", "青花瓷")
        waitPreview("青花瓷")
        let buy = requireVisible(idQuery("style-buy"), "購買鍵")
        XCTAssertTrue(buy.label.contains("NT$120"), "購買鍵沒有寫價格（現在是：\(buy.label)）")
        shot("選造型頁-預覽青花瓷")

        tapVisibleButton("完成")
        let isOriginal = waitUntil(timeout: 5) {
            element(id: "settings-portrait-style").label.contains("原版")
        }
        XCTAssertTrue(isOriginal, "只是預覽沒有買，設定頁那一列應該還是原版")
        shot("設定頁-還是原版")
    }
}

/// 買了青花瓷就換上：購買鍵消失、那格不再標還沒買，設定頁與境界碑都換成青花瓷。
final class PortraitStyleBuyUITests: RencanUITestCase {
    func test買了青花瓷就換上() {
        openStylePage()
        tapStyle("celadon", "青花瓷")
        waitPreview("青花瓷")
        requireVisible(idQuery("style-buy"), "購買鍵").tap()

        let buy = element(id: "style-buy")
        let isBought = waitUntil(timeout: 5) { !buy.exists }
        XCTAssertTrue(isBought, "買了之後購買鍵應該消失")
        let celadon = element(id: "style-celadon")
        XCTAssertFalse(celadon.label.contains("還沒買"), "買了青花瓷，那格還標著還沒買")
        XCTAssertTrue(celadon.isSelected, "買了青花瓷，那格應該是選中的")
        shot("選造型頁-買好青花瓷")

        tapVisibleButton("完成")
        let hasSaved = waitUntil(timeout: 5) {
            element(id: "settings-portrait-style").label.contains("青花瓷")
        }
        XCTAssertTrue(hasSaved, "買了青花瓷，設定頁那一列沒有寫青花瓷")
        shot("設定頁-寫著青花瓷")

        backToRealmFromSettings()
        seeStele()
        shot("境界頁-境界碑換成青花瓷")
    }
}

/// 買全套：全套那張卡選中時購買鍵寫 NT$480，買完全套卡消失、十一種都不再標還沒買。
final class PortraitStyleBundleUITests: RencanUITestCase {
    func test買全套十一種都能用() {
        openStylePage()
        scrollToSee(idQuery("style-bundle"), "「全套十一種」那張卡").tap()
        let buy = requireVisible(idQuery("style-buy"), "購買鍵")
        XCTAssertTrue(buy.label.contains("NT$480"), "選了全套，購買鍵應該寫全套的價格（現在是：\(buy.label)）")
        shot("選造型頁-選了全套")

        buy.tap()
        let isGone = waitUntil(timeout: 5) { !element(id: "style-bundle").exists }
        XCTAssertTrue(isGone, "買了全套，全套那張卡應該消失")
        let jade = element(id: "style-jade")
        XCTAssertFalse(jade.label.contains("還沒買"), "買了全套，翠玉還標著還沒買")
        shot("選造型頁-買好全套")

        tapStyle("neon", "霓虹")
        waitPreview("霓虹")
        XCTAssertFalse(element(id: "style-buy").exists, "買了全套，點霓虹不該再出現購買鍵")
        shot("選造型頁-換上霓虹")
    }
}
