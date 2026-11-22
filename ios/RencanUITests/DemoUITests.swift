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
        seeStele(timeout: 30)
        requireVisible(anyElements(containing: "FFMI 20.32"), "境界碑上的 FFMI 20.32")
        require(element(id: "realm-sect"), "境界頁最上面的宗門小卡")
        shot("境界頁")
        scrollToSee(anyElements(containing: "100 公斤 × 5 下 × 3 組"), "今天的坐馬樁那一筆")
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

    /// 修煉卡頁。2026-11-21 多米看存下來的圖，外框上下比左右窄；這裡留一張圖，在檢查線的截圖裡看四邊是不是一樣寬。
    func test修煉卡頁() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        let open = app.buttons.matching(identifier: "share-card-open")
        requireVisible(open, "頁首的分享圖示").tap()
        requireVisible(app.buttons.matching(identifier: "share-card-save"), "修煉卡頁的「存到相簿」")
        shot("修煉卡頁")
        // 打一個道號，看卡上只有名字、沒有「道號」那行小字（2026-11-21 多米選的）
        let field = requireVisible(
            app.textFields.matching(identifier: "share-card-dao-name"), "道號那一欄"
        )
        field.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        // 打完按「完成」收鍵盤再截圖：鍵盤開著時卡片被推到頁首底下，卡上的道號拍不到（第一版截圖就是這樣）
        field.typeText("Domy\n")
        _ = waitUntil(timeout: 3) { !app.keyboards.firstMatch.exists }
        shot("修煉卡頁-打了道號")
        typeOverLimitEnglish(into: field)
        shot("修煉卡頁-英文超過八個字")
        typeFullDaoName(into: field)
        XCTAssertFalse(
            app.staticTexts["share-card-dao-name-limit"].exists, "剛好八個字，不該出現字數提醒"
        )
        shot("修煉卡頁-道號八個字")
        typeOneMoreDaoNameCharacter(into: field)
        shot("修煉卡頁-道號超過八個字")
    }

    /// 已經八個字再多打一個：多的那個字不能留在欄位裡，欄位下面要出現「道號最多 8 個字」（2026-11-21 多米要的）。
    private func typeOneMoreDaoNameCharacter(into field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        field.typeText("仙\n")
        _ = waitUntil(timeout: 3) { !app.keyboards.firstMatch.exists }
        let hint = requireVisible(
            app.staticTexts.matching(identifier: "share-card-dao-name-limit"), "道號超過八個字的提醒"
        )
        XCTAssertEqual((field.value as? String)?.count, 8, "道號超過八個字，多的字沒有被拿掉")
        // 注音選字中不截字，靠的是接到輸入框本體去問它；這裡驗有接到（選字本身模擬器測不到，要真機）
        XCTAssertEqual(hint.value as? String, "有接到輸入框", "沒接到道號輸入框，選字中不截字不會有作用")
    }

    /// 英文也是最多八個字（2026-11-22 多米要的）：欄位裡已經有「Domy」四個字，再打五個就超過。
    /// 多的那個字不能留在欄位裡，欄位下面要出現提醒。
    private func typeOverLimitEnglish(into field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        field.typeText("Abcde\n")
        _ = waitUntil(timeout: 3) { !app.keyboards.firstMatch.exists }
        requireVisible(
            app.staticTexts.matching(identifier: "share-card-dao-name-limit"), "英文超過八個字的提醒"
        )
        XCTAssertEqual((field.value as? String)?.count, 8, "英文道號超過八個字，多的字沒有被拿掉")
    }

    /// 道號打滿八個字：卡上名字那一格會縮字，留一張圖看有沒有被截掉、擠到右邊的境界。
    /// 欄位的字靠右，點右緣游標會在字尾，刪掉原本八個英文字再打八個中文字（最寬的情況）。
    /// 這裡不檢查打進去的字：游標萬一沒在字尾，結果會夾著英文，但一樣是八個字，看截圖就知道。
    private func typeFullDaoName(into field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("太虛逍遙無極真人\n")
        _ = waitUntil(timeout: 3) { !app.keyboards.firstMatch.exists }
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

/// 分析頁的功法段：三格統計、十二張功法卡、點一張進單一功法頁、最近修煉、功法等級怎麼算。
final class DemoGongUITests: RencanUITestCase {
    func test示範資料功法段與單一功法頁() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        openAnalysis()
        tapVisibleButton("功法")
        seeText("十二門功法")
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
    /// 十二門照腿推拉排之後拔山式是第九張，要先往下捲才看得到。
    private func openMoveDetail() {
        let card = scrollToSee(idQuery("move-card-dead"), "拔山式的功法卡", maxDrags: 8)
        // 懸浮分頁列蓋在畫面底部，卡停在它底下時 isHittable 照樣是真的，點下去卻點到分頁列
        // （2026-11-19 雷達圖改直寫變高後紅過一次）。卡的下緣要在分頁列上方才點。
        let tabBarTop = app.buttons["tab-分析"].frame.minY
        for _ in 0..<2 where card.frame.maxY > tabBarTop {
            scrollDown()
        }
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
        seeStele(timeout: 30)
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
        seeStele()
        requireVisible(anyElements(containing: "FFMI 20.32"), "身高改回 174 後的 FFMI 20.32")
    }
}

/// `-rencanSeed realm0` 到 `realm6`：七個境界各一筆量測，看深色卡的七個底色、印章、立繪。
/// `-rencanSeed unstable`：金丹但體脂 24%，看根基不穩那一行與灰掉的進度條。
final class SteleCardsUITests: RencanUITestCase {
    func test七個境界的深色卡與根基不穩() {
        let realmNames = ["煉氣", "築基", "金丹", "元嬰", "化神", "大乘", "渡劫"]
        for (index, name) in realmNames.enumerated() {
            launch(["-rencanSeed", "realm\(index)"])
            requireVisible(
                anyElements(containing: "\(name)期人蔘立繪"), "\(name)的立繪", timeout: 30
            )
            shot("深色卡-\(name)")
        }

        launch(["-rencanSeed", "unstable"])
        seeStele(timeout: 30)
        requireVisible(anyElements(containing: "根基不穩・體脂 24.0%"), "根基不穩那一行")
        shot("深色卡-根基不穩")
        scrollToSee(anyElements(containing: "以下境界才生效"), "白卡上降體脂的那一句")
        shot("根基不穩-白卡")
    }
}

/// 境界碑的立繪有沒有在動。測試模式預設不播，這一支另外帶 -rencanPlayPortrait 讓它照播，
/// 隔三秒（20 格）各拍一次螢幕，兩張要不一樣。順不順只有真機看得出來。
final class PortraitMotionUITests: RencanUITestCase {
    func test境界碑的立繪隔三秒換了格() {
        launch(["-rencanSeed", "demo", "-rencanPlayPortrait"])
        // 只確認它在，不問點不點得到：播動畫時立繪關掉了觸控。
        require(
            anyElements(containing: "金丹期人蔘立繪").firstMatch, "境界碑的立繪", timeout: 30
        )
        // 拍整個螢幕來比：只拍立繪那個元素，模擬器會回「畫不出截圖」（2026-11-16 檢查線紅過）。
        // 狀態列的時間在模擬器上是固定的，整頁只有立繪會變。
        let first = XCUIScreen.main.screenshot().pngRepresentation
        shot("動畫-第一張")
        Thread.sleep(forTimeInterval: 3)
        let second = XCUIScreen.main.screenshot().pngRepresentation
        shot("動畫-三秒後")
        XCTAssertNotEqual(first, second, "隔了三秒，畫面一點都沒變，立繪沒有換格")
    }
}

/// 付費造型也會動（組塊 M2）：先算買了青花瓷、設成青花瓷，境界碑隔三秒拍兩張要不一樣。
final class StyledPortraitMotionUITests: RencanUITestCase {
    func test青花瓷的立繪也會動() {
        launch([
            "-rencanSeed", "demo", "-rencanOwn", "celadon", "-rencanStyle", "celadon",
            "-rencanPlayPortrait",
        ])
        require(
            anyElements(containing: "金丹期人蔘立繪").firstMatch, "境界碑的立繪", timeout: 30
        )
        let first = XCUIScreen.main.screenshot().pngRepresentation
        shot("青花瓷動畫-第一張")
        Thread.sleep(forTimeInterval: 3)
        let second = XCUIScreen.main.screenshot().pngRepresentation
        shot("青花瓷動畫-三秒後")
        XCTAssertNotEqual(first, second, "隔了三秒，青花瓷的立繪沒有換格")
    }
}

/// `-rencanSeed female`：身高 160、女，一筆量測（60 公斤、體脂 23%、去脂 46 公斤）。
/// 看女性立繪、27% 的體脂門檻，天梯上換算過的範圍。
final class FemaleUITests: RencanUITestCase {
    func test女性版境界頁與分析境界段() {
        launch(["-rencanSeed", "female"])
        seeStele(timeout: 30)
        requireVisible(anyElements(containing: "體脂 23.0%"), "境界碑上的體脂 23.0%")
        shot("境界頁")

        openAnalysis()
        waitForText("天梯")
        require(textContaining("目前只有一次量測"), "只有一筆量測時走勢那格的說明")
        shot("分析境界段-頂")
        scrollShots("分析境界段", count: 2)
    }
}
