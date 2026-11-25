import XCTest

/// 記一筆修煉（核心動作），從只填了身高性別、還沒量過體重的狀態起手：
/// 開表單、選功法、用加減鈕調數字、記下、「引氣入體」的全螢幕慶祝、「今天的修煉」多一行。
/// 沒量過體重時預覽那格是一句說明；有體重的即時預覽在 LogPreviewUITests。
final class LogUITests: RencanUITestCase {
    private let emptyNote = "今天還沒記。練完記最重那一組就好，三十秒。"

    func test記一筆後今天的修煉多一行() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        waitForText(emptyNote)
        tapVisibleButton("記一筆修煉")
        let submit = require(app.buttons["記下"], "記一筆表單的「記下」按鈕")
        shot("表單打開")

        // 重量從 20 加兩次到 25 公斤，次數從 5 加到 6。功法分頁一開始停在腿，拔山式在拉那頁
        tapButton("拉")
        tapButton("拔山式・硬舉")
        tapButton("重量加 2.5 公斤")
        tapButton("重量加 2.5 公斤")
        tapButton("次數加一")
        waitForText("次數 6")
        waitForText("組數 3")
        require(textContaining("還沒量過體重"), "沒量過體重時預覽那格的說明")
        shot("選拔山式25公斤6下")

        XCTAssertFalse(element(id: "lift-last").exists, "這門從沒記過，不該有「上次」那行")
        submit.tap()
        let line = "量過體重才算得出等級"
        require(anyElements(containing: line).firstMatch, "慶祝上的「\(line)」", timeout: 8)
        passCelebration(heading: "引氣入體", shotName: "引氣入體慶祝", sheetButton: submit)
        let isClosed = waitUntil(timeout: 5) { !submit.exists }
        XCTAssertTrue(isClosed, "按了「記下」，表單沒有收回去")
        shot("記下之後")

        scrollDown()
        let rows = anyElements(containing: "25 公斤 × 6 下 × 3 組")
        requireVisible(rows, "今天的修煉裡剛記的那一筆")
        requireVisible(anyElements(containing: "拔山式"), "今天的修煉裡的「拔山式」")
        XCTAssertFalse(app.staticTexts[emptyNote].exists, "記了一筆，「今天還沒記」那句還在")
        shot("今天的修煉多一行")
    }
}

/// 有體重時（示範資料）記一筆：預覽跟著功法與重量即時變，「上次」那行只跟著功法變；
/// 這一筆破了坐馬樁的紀錄，會跳「功法精進」的全螢幕慶祝，點一下關掉後清單多一行。
final class LogPreviewUITests: RencanUITestCase {
    func test有體重時預覽跟著數字變() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        tapVisibleButton("記一筆修煉")
        let submit = require(app.buttons["記下"], "記一筆表單的「記下」按鈕")
        // 表單先帶上次記的那一門（推山掌 62.5 公斤）
        expectPreview("預估 1RM 73 公斤・1.04 倍體重")
        expectLast("上次 今天・62.5 公斤 × 5 下 × 3 組")
        shot("表單帶上次的數字")

        // 分頁停在推山掌的推那頁，坐馬樁要先切到腿
        tapButton("腿")
        tapButton("坐馬樁・深蹲")
        expectPreview("預估 1RM 117 公斤・1.66 倍體重")
        expectLast("上次 今天・100 公斤 × 5 下 × 3 組")
        shot("換成坐馬樁100公斤")

        tapButton("重量加 2.5 公斤")
        expectPreview("預估 1RM 120 公斤・1.70 倍體重")
        expectLast("上次 今天・100 公斤 × 5 下 × 3 組")
        shot("加到102點5公斤預覽跟著變")

        submit.tap()
        passCelebration(heading: "功法精進", shotName: "功法精進慶祝", sheetButton: submit)
        let rows = anyElements(containing: "102.5 公斤 × 5 下 × 3 組")
        scrollToSee(rows, "今天的修煉裡剛記的 102.5 公斤那一筆")
        shot("今天的修煉三筆")
    }

    /// 功法格下面的「上次」那行是這段字。
    private func expectLast(_ text: String) {
        let last = require(element(id: "lift-last"), "功法格下面的「上次」那行")
        let isShown = waitUntil(timeout: 5) { last.label == text }
        XCTAssertTrue(isShown, "「上次」那行不是「\(text)」，現在是：\(last.label)")
    }

    /// 等預覽那格出現這段字。沒等到就把它現在寫的字印在失敗訊息裡。
    private func expectPreview(_ text: String) {
        let preview = require(element(id: "lift-preview"), "記一筆表單的即時預覽")
        let isShown = waitUntil(timeout: 5) { preview.label.contains(text) }
        XCTAssertTrue(isShown, "預覽沒有變成「\(text)」，現在是：\(preview.label)")
    }
}

/// 回來還沒記、再記一筆（2026-11-25）：`-rencanSeed away` 是示範資料，修煉全部往前推 40 天。
/// 境界頁不放「本週 0 天」，「今天的修煉」寫累計的 9 天都還在；照上次的數字記一筆就是「出關」。
final class AwayUITests: RencanUITestCase {
    func test隔40天回來記一筆是出關() {
        launch(["-rencanSeed", "away"])
        seeStele(timeout: 30)
        scrollDown()
        scrollDown()
        seeText("你的 9 天修煉都還在，練一門就出關。")
        requireVisible(anyElements(containing: "累計修煉"), "三格天數裡的累計")
        XCTAssertNil(visibleElement(in: anyElements(containing: "本週")), "這週 0 天，還放著「本週」")
        shot("境界頁-回來還沒記")

        tapVisibleButton("記一筆修煉")
        let submit = require(app.buttons["記下"], "記一筆表單的「記下」按鈕")
        let last = require(element(id: "lift-last"), "功法格下面的「上次」那行")
        XCTAssertTrue(
            last.label.hasSuffix(" 日・62.5 公斤 × 5 下 × 3 組"), "「上次」那行是：\(last.label)"
        )
        shot("表單-上次寫日期")
        submit.tap()
        require(anyElements(containing: "累計修煉 10 天").firstMatch, "慶祝上的累計天數", timeout: 8)
        passCelebration(heading: "出關", shotName: "出關慶祝", sheetButton: submit)
        scrollToSee(anyElements(containing: "62.5 公斤 × 5 下 × 3 組"), "今天的修煉裡剛記的那一筆")
        requireVisible(anyElements(containing: "本週"), "記了一筆之後回來的「本週」")
        shot("出關之後的境界頁")
    }
}

/// 加減鈕按住會一直走（2026-11-25 手感審查 #2）。震動與「會不會快到停不住」只有真機驗得到。
final class LogHoldUITests: RencanUITestCase {
    func test加減鈕按住連續走() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        tapVisibleButton("記一筆修煉")
        require(app.buttons["記下"], "記一筆表單的「記下」按鈕")
        waitForText("次數 5")

        app.buttons["次數加一"].press(forDuration: 1.5)
        let reps = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "次數 "))
        let count = Int(reps.firstMatch.label.dropFirst(3)) ?? 0
        XCTAssertGreaterThan(count, 6, "按住「次數加一」1.5 秒，次數只到 \(count)")

        app.buttons["重量加 2.5 公斤"].press(forDuration: 2)
        shot("按住次數1點5秒重量2秒")
    }
}

/// 連點兩下「記下」：只存一筆，第二下也不會把剛出現的慶祝點掉（2026-11-25 手感審查）。
final class LogDoubleTapUITests: RencanUITestCase {
    func test連點記下只存一筆() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        tapVisibleButton("記一筆修煉")
        let submit = require(app.buttons["記下"], "記一筆表單的「記下」按鈕")
        tapButton("腿")
        tapButton("坐馬樁・深蹲")
        tapButton("重量加 2.5 公斤")

        submit.doubleTap()
        passCelebration(heading: "功法精進", shotName: "連點記下的慶祝", sheetButton: submit)
        let detail = "102.5 公斤 × 5 下 × 3 組"
        scrollToSee(anyElements(containing: detail), "今天的修煉裡剛記的那一筆")
        shot("連點記下之後")
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", detail))
        XCTAssertEqual(rows.count, 1, "連點兩下「記下」，存成 \(rows.count) 筆")
    }
}
