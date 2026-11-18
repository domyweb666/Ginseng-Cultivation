import XCTest

/// 記一筆修煉（核心動作），從只填了身高性別、還沒量過體重的狀態起手：
/// 開表單、選功法、用加減鈕調數字、記下、表單收回、「今天的修煉」多一行。
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

        submit.tap()
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

/// 有體重時（示範資料）記一筆：預覽跟著功法與重量即時變；
/// 這一筆破了坐馬樁的紀錄，會跳「功法精進」的全螢幕慶祝，點一下關掉後清單多一行。
final class LogPreviewUITests: RencanUITestCase {
    func test有體重時預覽跟著數字變() {
        launch(["-rencanSeed", "demo"])
        seeStele(timeout: 30)
        tapVisibleButton("記一筆修煉")
        let submit = require(app.buttons["記下"], "記一筆表單的「記下」按鈕")
        // 表單先帶上次記的那一門（推山掌 62.5 公斤）
        expectPreview("預估 1RM 73 公斤・1.04 倍體重")
        shot("表單帶上次的數字")

        // 分頁停在推山掌的推那頁，坐馬樁要先切到腿
        tapButton("腿")
        tapButton("坐馬樁・深蹲")
        expectPreview("預估 1RM 117 公斤・1.66 倍體重")
        shot("換成坐馬樁100公斤")

        tapButton("重量加 2.5 公斤")
        expectPreview("預估 1RM 120 公斤・1.70 倍體重")
        shot("加到102點5公斤預覽跟著變")

        submit.tap()
        passCelebration(heading: "功法精進", shotName: "功法精進慶祝", sheetButton: submit)
        let rows = anyElements(containing: "102.5 公斤 × 5 下 × 3 組")
        scrollToSee(rows, "今天的修煉裡剛記的 102.5 公斤那一筆")
        shot("今天的修煉三筆")
    }

    /// 等預覽那格出現這段字。沒等到就把它現在寫的字印在失敗訊息裡。
    private func expectPreview(_ text: String) {
        let preview = require(element(id: "lift-preview"), "記一筆表單的即時預覽")
        let isShown = waitUntil(timeout: 5) { preview.label.contains(text) }
        XCTAssertTrue(isShown, "預覽沒有變成「\(text)」，現在是：\(preview.label)")
    }
}
