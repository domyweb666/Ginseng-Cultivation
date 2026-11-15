import XCTest

// 小人蔘（組塊 K，PRD S29）的截圖，給人看的：角色本身 VoiceOver 不讀、元件樹裡找不到，
// 所以這裡只等旁邊的字出現再截圖，長相對不對要打開圖看。
// 一個流程一個類別：截圖檔名的流水號是每個測試各自從 01 起算，分開才不會撞名。

/// 小人蔘展示畫面（Debug 版帶 `-rencanMascotGallery` 才有）：六個動作各一格，
/// 每格三種高度 56、96、160。看圖檢查兩件事：高 56 時白臉的框有沒有糊在一起、葉子是不是綠的。
/// 展示畫面不讀資料庫，不用帶 `-rencanSeed`。
final class MascotGalleryUITests: RencanUITestCase {
    func test小人蔘展示畫面六個動作三種高度() {
        launch(["-rencanMascotGallery"])
        seeText("揮手", timeout: 30)
        seeText("打瞌睡")
        shot("展示畫面")

        // 螢幕矮、一頁放不下時最後一排在下面；放得下時這一拖只會彈回來，不影響。
        scrollDown()
        scrollToSee(app.staticTexts.matching(named("聳肩")), "展示畫面的「聳肩」那一格")
        scrollToSee(app.staticTexts.matching(named("拜託")), "展示畫面的「拜託」那一格")
        shot("展示畫面-往下捲")
    }
}

/// `-rencanSeed profile`（填了身高性別、沒量過、沒修煉）：分析頁境界段與功法段的空狀態，
/// 小人蔘聳肩在上、一句話在下。
final class MascotEmptyUITests: RencanUITestCase {
    /// 聳肩一輪 2.4 秒，其中手放下來休息的時間不到 0.9 秒。
    /// 隔這麼久連截兩張，至少一張截得到兩手攤開。
    private let shrugGapSeconds: TimeInterval = 1.2

    func test分析頁兩段空狀態小人蔘聳肩() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        openAnalysis()
        let realmNote = anyElements(containing: "這裡就會有走勢、突破紀錄和天梯")
        requireVisible(realmNote, "境界段空狀態那句話")
        shrugShots("境界段空狀態")

        tapVisibleButton("功法")
        seeText("六門功法")
        let gongNote = scrollToSee(idQuery("gong-empty"), "功法段空狀態那句話")
        let noteText = gongNote.label
        XCTAssertTrue(noteText.contains("還沒有修煉紀錄"), "功法段空狀態的字不對：\(noteText)")
        shrugShots("功法段空狀態")
    }

    /// 同一個畫面隔一小段連截兩張。
    private func shrugShots(_ name: String) {
        let start = Date()
        shot(name + "-第1張")
        waitUntil(timeout: shrugGapSeconds) {
            Date().timeIntervalSince(start) >= shrugGapSeconds
        }
        shot(name + "-第2張")
    }
}
