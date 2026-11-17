import XCTest

/// `-rencanSeed profile`（填了身高性別、沒量過、沒修煉）：分析頁境界段與功法段的空狀態，
/// 各是一張卡、裡面一句話。
final class AnalysisEmptyUITests: RencanUITestCase {
    func test分析頁兩段空狀態各有一句話() {
        launch(["-rencanSeed", "profile"])
        seeText("還沒量過體組成", timeout: 30)
        openAnalysis()
        let realmNote = anyElements(containing: "這裡就會有走勢、突破紀錄和天梯")
        requireVisible(realmNote, "境界段空狀態那句話")
        shot("境界段空狀態")

        tapVisibleButton("功法")
        seeText("十二門功法")
        let gongNote = scrollToSee(idQuery("gong-empty"), "功法段空狀態那句話")
        let noteText = gongNote.label
        XCTAssertTrue(noteText.contains("還沒有修煉紀錄"), "功法段空狀態的字不對：\(noteText)")
        shot("功法段空狀態")
    }
}
