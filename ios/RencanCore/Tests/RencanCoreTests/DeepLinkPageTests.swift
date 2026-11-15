import XCTest

@testable import RencanCore

/// 深連結只認三個固定頁名（安全標準類別 5；片 I2）。認不得的一律 nil，app 就當沒收到。
final class DeepLinkPageTests: XCTestCase {
    // MARK: 頁名（通知裡帶的那個字）

    func test三個頁名都認得() {
        XCTAssertEqual(DeepLinkPage(name: "settings"), .settings)
        XCTAssertEqual(DeepLinkPage(name: "realm"), .realm)
        XCTAssertEqual(DeepLinkPage(name: "analysis"), .analysis)
    }

    func test固定頁名只有三個() {
        XCTAssertEqual(DeepLinkPage.allCases.count, 3)
    }

    func test頁名大小寫不分() {
        XCTAssertEqual(DeepLinkPage(name: "REALM"), .realm)
        XCTAssertEqual(DeepLinkPage(name: "Settings"), .settings)
        XCTAssertEqual(DeepLinkPage(name: "aNaLySiS"), .analysis)
    }

    func test不認得的頁名不理() {
        for name in ["gong", "log", "delete", "", "設定", "realms", "realm/extra"] {
            XCTAssertNil(DeepLinkPage(name: name), name)
        }
    }

    func test頁名前後有空白不理() {
        XCTAssertNil(DeepLinkPage(name: " realm"))
        XCTAssertNil(DeepLinkPage(name: "realm "))
    }

    // MARK: 連結

    func test連結三個頁名都認得() {
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://settings"), .settings)
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://realm"), .realm)
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://analysis"), .analysis)
    }

    func test連結大小寫不分() {
        XCTAssertEqual(DeepLinkPage(urlText: "RENCAN://REALM"), .realm)
        XCTAssertEqual(DeepLinkPage(urlText: "Rencan://Analysis"), .analysis)
    }

    func test連結結尾多一條斜線照樣認() {
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://realm/"), .realm)
    }

    func test頁名後面有多餘路徑整條不理() {
        XCTAssertNil(DeepLinkPage(urlText: "rencan://realm/delete"))
        XCTAssertNil(DeepLinkPage(urlText: "rencan://settings/reset/all"))
        XCTAssertNil(DeepLinkPage(urlText: "rencan://realm/analysis"))
    }

    func test帶參數只認頁名參數不讀() {
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://realm?page=settings&kg=70"), .realm)
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://analysis#gong"), .analysis)
        XCTAssertEqual(DeepLinkPage(urlText: "rencan://settings/?next=realm"), .settings)
    }

    func test頁名只寫在參數裡不理() {
        XCTAssertNil(DeepLinkPage(urlText: "rencan://?page=realm"))
        XCTAssertNil(DeepLinkPage(urlText: "rencan://open?page=realm"))
    }

    func test連結裡不認得的頁名不理() {
        for text in ["rencan://gong", "rencan://delete-all", "rencan://", "rencan:", "rencan"] {
            XCTAssertNil(DeepLinkPage(urlText: text), text)
        }
    }

    func test別人的scheme不理() {
        for text in ["https://realm", "http://example.com/realm", "rencanx://realm"] {
            XCTAssertNil(DeepLinkPage(urlText: text), text)
        }
    }

    func test沒有scheme的不理() {
        for text in ["realm", "://realm", "//realm", ""] {
            XCTAssertNil(DeepLinkPage(urlText: text), text)
        }
    }

    func test夾帳號埠號或百分號編碼的不理() {
        XCTAssertNil(DeepLinkPage(urlText: "rencan://user@realm"))
        XCTAssertNil(DeepLinkPage(urlText: "rencan://realm:80"))
        XCTAssertNil(DeepLinkPage(urlText: "rencan://re%61lm"))
    }
}
