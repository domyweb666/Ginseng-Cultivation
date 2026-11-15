import XCTest

@testable import RencanCore

/// 三張表跟網頁版 index.html L203–230 一字不差。表裡任何一格抄錯，這裡會紅。
final class TablesTests: XCTestCase {
    private func thresholds(of key: MoveKey) throws -> [Double] {
        try XCTUnwrap(Tables.moves.first { $0.key == key }).thresholds
    }

    func test七個境界的名字照網頁版() {
        let names = ["煉氣", "築基", "金丹", "元嬰", "化神", "大乘", "渡劫"]
        XCTAssertEqual(Tables.realms.map(\.name), names)
    }

    func test七個境界的FFMI下限照網頁版() {
        XCTAssertEqual(Tables.realms.map(\.lowerFFMI), [16.5, 18, 19.5, 21, 22.5, 24, 25.5])
    }

    func test七個境界的FFMI上限照網頁版() {
        XCTAssertEqual(Tables.realms.map(\.upperFFMI), [18, 19.5, 21, 22.5, 24, 25.5, 27])
    }

    func test每個境界的上限就是下一個境界的下限() {
        let uppers = Tables.realms.dropLast().map(\.upperFFMI)
        let lowers = Tables.realms.dropFirst().map(\.lowerFFMI)
        XCTAssertEqual(uppers, lowers)
    }

    func test三個期別的名字照網頁版() {
        XCTAssertEqual(Tables.stages, ["初期", "中期", "後期"])
    }

    func test六個功法等級的名字照網頁版() {
        let names = ["未入門", "入門", "小成", "大成", "圓滿", "化境"]
        XCTAssertEqual(Tables.levelNames, names)
    }

    func test六門功法的功法名照網頁版() {
        let names = ["坐馬樁", "拔山式", "推山掌", "托天式", "挽弓式", "攀雲梯"]
        XCTAssertEqual(Tables.moves.map(\.artName), names)
    }

    func test六門功法的動作名照網頁版() {
        let names = ["深蹲", "硬舉", "臥推", "肩推", "划船", "引體向上"]
        XCTAssertEqual(Tables.moves.map(\.name), names)
    }

    func test六門功法的代號跟網頁版存檔用的一樣() {
        let keys = ["squat", "dead", "bench", "ohp", "row", "pull"]
        XCTAssertEqual(Tables.moves.map(\.key.rawValue), keys)
    }

    func test坐馬樁深蹲的五階門檻照網頁版() throws {
        XCTAssertEqual(try thresholds(of: .squat), [0.75, 1.0, 1.25, 1.5, 2.0])
    }

    func test拔山式硬舉的五階門檻照網頁版() throws {
        XCTAssertEqual(try thresholds(of: .dead), [1.0, 1.25, 1.5, 2.0, 2.5])
    }

    func test推山掌臥推的五階門檻照網頁版() throws {
        XCTAssertEqual(try thresholds(of: .bench), [0.5, 0.75, 1.0, 1.25, 1.5])
    }

    func test托天式肩推的五階門檻照網頁版() throws {
        XCTAssertEqual(try thresholds(of: .ohp), [0.35, 0.5, 0.65, 0.8, 1.0])
    }

    func test挽弓式划船的五階門檻照網頁版() throws {
        XCTAssertEqual(try thresholds(of: .row), [0.5, 0.75, 1.0, 1.25, 1.5])
    }

    func test攀雲梯引體向上的五階門檻照網頁版() throws {
        XCTAssertEqual(try thresholds(of: .pull), [1.03, 1.17, 1.33, 1.5, 1.67])
    }

    func test只有攀雲梯把自身體重算進負重() {
        let keys = Tables.moves.filter(\.usesBodyweight).map(\.key)
        XCTAssertEqual(keys, [.pull])
    }

    func test六個宗門身分的名字照網頁版() {
        let names = ["雜役弟子", "外門弟子", "內門弟子", "真傳弟子", "長老", "太上長老"]
        XCTAssertEqual(Tables.ranks.map(\.name), names)
    }

    func test六個宗門身分要的修煉天數照網頁版() {
        XCTAssertEqual(Tables.ranks.map(\.requiredDays), [0, 8, 24, 50, 150, 300])
    }

    func test六個宗門身分要的境界照網頁版() {
        XCTAssertEqual(Tables.ranks.map(\.requiredRealmIndex), [-1, -1, 1, 2, 3, 4])
    }
}
