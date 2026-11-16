import XCTest

// `-rencanSeed demo`：身高 174、男，三筆量測（最新 70.4 公斤、體脂 14.2% → FFMI 20.32 金丹中期）、
// 九天十三筆修煉（今天兩筆：坐馬樁 100 公斤、推山掌 62.5 公斤）。修煉 9 天又到金丹，宗門身分是客卿。
// 一個流程一個類別：截圖檔名的流水號是每個測試各自從 01 起算，分開才不會撞名。

extension RencanUITestCase {
    /// 點分頁列的「分析」到分析頁。
    func openAnalysis() {
        openTab("分析")
    }
}

/// 境界頁，加上分析頁的境界段從頭捲到尾：宗門卡、FFMI 走勢、突破紀錄、天梯、境界怎麼算。
final class DemoRealmUITests: RencanUITestCase {
    func test示範資料境界頁與分析境界段() {
        launch(["-rencanSeed", "demo"])
        seeText("目前境界", timeout: 30)
        requireVisible(anyElements(containing: "FFMI 20.32"), "境界碑上的 FFMI 20.32")
        shot("境界頁")
        scrollDown()
        requireVisible(anyElements(containing: "100 公斤 × 5 下 × 3 組"), "今天的坐馬樁那一筆")
        shot("境界頁-今天的修煉")
        scrollUp()

        openAnalysis()
        shot("分析境界段-頂")
        scrollShots("分析境界段", count: 3)
        checkRealmSection()

        let rules = app.buttons.matching(named("境界怎麼算"))
        scrollToSee(rules, "「境界怎麼算」那一列").tap()
        require(textContaining("體脂秤誤差大"), "點開「境界怎麼算」後的說明")
        scrollDown()
        shot("分析境界段-境界怎麼算點開")
    }

    /// 境界段四塊都在。這一段不是懶載入，捲到哪裡都找得到，所以放在截完圖之後才查。
    private func checkRealmSection() {
        require(textContaining("再修煉 41 天，轉為正式真傳弟子"), "宗門卡的下一步")
        waitForText("FFMI 走勢")
        waitForText("突破紀錄")
        require(anyElements(containing: "第一次量測").firstMatch, "突破紀錄的第一筆")
        waitForText("天梯")
        require(anyElements(containing: "你在這裡・中期").firstMatch, "天梯上「你在這裡」那一列")
    }
}

/// 分析頁的功法段：三格統計、六張功法卡、點一張進單一功法頁、最近修煉、功法等級怎麼算。
final class DemoGongUITests: RencanUITestCase {
    func test示範資料功法段與單一功法頁() {
        launch(["-rencanSeed", "demo"])
        seeText("目前境界", timeout: 30)
        openAnalysis()
        tapVisibleButton("功法")
        seeText("六門功法")
        shot("功法段-頂")

        openMoveDetail()
        scrollShots("功法段", count: 4)
        waitForText("最近修煉")
        XCTAssertFalse(element(id: "gong-empty").exists, "有修煉紀錄，卻顯示「還沒有修煉紀錄」")

        let rules = app.buttons.matching(named("功法等級怎麼算"))
        scrollToSee(rules, "「功法等級怎麼算」那一列").tap()
        require(textContaining("用你那組的重量和次數"), "點開「功法等級怎麼算」後的說明")
        scrollDown()
        shot("功法段-等級怎麼算點開")
    }

    /// 點拔山式那張卡（120 公斤 × 5 下 → 1RM 140 公斤），看單一功法頁，再按「關閉」回來。
    private func openMoveDetail() {
        let card = requireVisible(idQuery("move-card-dead"), "拔山式的功法卡")
        let cardText = card.label
        XCTAssertTrue(cardText.contains("1RM 140 公斤"), "拔山式卡不是 1RM 140 公斤：\(cardText)")
        card.tap()
        seeText("拔山式・硬舉")
        let records = require(app.staticTexts["全部紀錄"].firstMatch, "單一功法頁的「全部紀錄」")
        require(textContaining("共 2 筆，從 128 公斤到 140 公斤"), "走勢圖底下那句話")
        shot("單一功法頁-拔山式")
        tapButton("關閉")
        let isClosed = waitUntil(timeout: 5) { !records.exists }
        XCTAssertTrue(isClosed, "按了「關閉」，單一功法頁沒有收回去")
    }
}

/// 設定頁（這一版只有「身體」區）：看得到身高 174，加減鈕改得動。
final class DemoSettingsUITests: RencanUITestCase {
    func test示範資料設定頁() {
        launch(["-rencanSeed", "demo"])
        seeText("目前境界", timeout: 30)
        openTab("設定")
        seeText("身體")
        requireVisible(anyElements(containing: "174"), "身高 174")
        shot("設定頁")

        tapVisibleButton("身高加一公分")
        requireVisible(anyElements(containing: "175"), "加一公分後的身高 175")
        shot("設定頁-身高175")
        tapVisibleButton("身高減一公分")
        requireVisible(anyElements(containing: "174"), "減回來的身高 174")

        openTab("境界")
        seeText("目前境界")
        requireVisible(anyElements(containing: "FFMI 20.32"), "身高改回 174 後的 FFMI 20.32")
    }
}

/// `-rencanSeed female`：身高 160、女，一筆量測（60 公斤、體脂 23%、去脂 46 公斤）。
/// 看女性立繪、27% 的體脂門檻，天梯上換算過的範圍。
final class FemaleUITests: RencanUITestCase {
    func test女性版境界頁與分析境界段() {
        launch(["-rencanSeed", "female"])
        seeText("目前境界", timeout: 30)
        requireVisible(anyElements(containing: "體脂 23.0%"), "境界碑上的體脂 23.0%")
        shot("境界頁")

        openAnalysis()
        waitForText("天梯")
        require(textContaining("目前只有一次量測"), "只有一筆量測時走勢那格的說明")
        shot("分析境界段-頂")
        scrollShots("分析境界段", count: 2)
    }
}
