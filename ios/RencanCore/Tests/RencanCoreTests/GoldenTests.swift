import XCTest

@testable import RencanCore

/// 黃金集測試。片 B2 會用 node 跑網頁版的 JS 產出 Fixtures/web-export.json 當標準答案；
/// 這片先放一個一定會過的測試，讓 CI 的 Linux 那一步從第一天就有東西跑。
final class GoldenTests: XCTestCase {
    func test體脂穩固門檻是百分之二十() {
        XCTAssertEqual(Tables.bodyFatStableThresholdPercent, 20)
    }
}
