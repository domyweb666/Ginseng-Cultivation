import XCTest

// 內購商品的審核截圖（.vibe/付費造型計畫.md「審核截圖」）：App Store Connect 每個商品要一張，
// 拍選造型頁：那種造型被選中、標著小鎖，底下看得到購買鍵。全套那張拍「全套十一種」選中的樣子。
// 檔名是 IAPReviewShots-NN-代碼.png，ios/ci/iap_products.mjs 的 screenshots 指令照代碼對商品上傳。
// 假商店的價格是固定字串（UITestSupport.testSinglePrice），跟真的 App Store 一樣寫 NT$。

/// 一次拍十二張。照格子由上往下的順序點，捲到看得到那格為止（不往回捲：在表單最上面往下拖會把表單關掉）。
/// 前兩排的預覽大圖會留在畫面上；後兩排要往下捲，預覽會被推上去一部分。
final class IAPReviewShotsUITests: RencanUITestCase {
    /// 十一種付費造型的代碼與名字，順序跟選造型頁的格子一樣。
    private let styles: [(code: String, name: String)] = [
        ("ink", "水墨"), ("gold", "鎏金"), ("moon", "月夜"), ("puppet", "皮影燈籠"),
        ("handheld", "掌機四色"), ("sticker", "貼紙"), ("chunky", "粗像素"), ("celadon", "青花瓷"),
        ("sunset", "赤霞夕照"), ("neon", "霓虹"), ("jade", "翠玉"),
    ]

    func test內購審核截圖十二張() {
        openStylePage()
        for style in styles {
            tapStyle(style.code, style.name)
            waitPreview(style.name)
            let buy = requireVisible(idQuery("style-buy"), "\(style.name)的購買鍵")
            XCTAssertTrue(buy.label.contains(style.name), "購買鍵沒寫\(style.name)（現在是：\(buy.label)）")
            shot(style.code)
        }
        scrollToSee(idQuery("style-bundle"), "「全套十一種」那張卡").tap()
        let buy = requireVisible(idQuery("style-buy"), "全套的購買鍵")
        XCTAssertTrue(buy.label.contains("全套"), "購買鍵沒寫全套（現在是：\(buy.label)）")
        shot("all")
    }
}
