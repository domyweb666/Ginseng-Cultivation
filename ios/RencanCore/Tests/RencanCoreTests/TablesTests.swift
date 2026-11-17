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

    // 2026-11-18 擴成十二門，照腿、推、拉排，每排四門。

    func test十二門功法的功法名照腿推拉排() {
        let legs = ["坐馬樁", "抱鼎樁", "探海式", "架橋式"]
        let push = ["推山掌", "推月掌", "托天式", "撐柱式"]
        let pull = ["拔山式", "挽弓式", "攀雲梯", "捧丹手"]
        XCTAssertEqual(Tables.moves.map(\.artName), legs + push + pull)
    }

    func test十二門功法的動作名照腿推拉排() {
        let legs = ["深蹲", "前蹲", "羅馬尼亞硬舉", "臀推"]
        let push = ["臥推", "上斜臥推", "肩推", "雙槓撐體"]
        let pull = ["硬舉", "划船", "引體向上", "槓鈴彎舉"]
        XCTAssertEqual(Tables.moves.map(\.name), legs + push + pull)
    }

    func test原本六門的代號沒變存檔還讀得到() {
        let keys = ["squat", "dead", "bench", "ohp", "row", "pull"]
        for key in keys {
            XCTAssertNotNil(Tables.moves.first { $0.key.rawValue == key }, key)
        }
    }

    func test每排四門() {
        for group in MoveGroup.allCases {
            XCTAssertEqual(Tables.moves.filter { $0.group == group }.count, 4, group.rawValue)
        }
        XCTAssertEqual(Tables.moves.count, MoveKey.allCases.count)
    }

    func test新六門的男性門檻照草案() throws {
        XCTAssertEqual(try thresholds(of: .frontSquat), [0.55, 0.7, 0.9, 1.05, 1.45])
        XCTAssertEqual(try thresholds(of: .romanianDeadlift), [0.75, 0.95, 1.1, 1.5, 1.9])
        XCTAssertEqual(try thresholds(of: .hipThrust), [0.75, 1.0, 1.25, 1.5, 2.0])
        XCTAssertEqual(try thresholds(of: .inclineBench), [0.4, 0.6, 0.8, 1.0, 1.2])
        XCTAssertEqual(try thresholds(of: .dip), [1.1, 1.27, 1.4, 1.6, 1.83])
        XCTAssertEqual(try thresholds(of: .curl), [0.25, 0.35, 0.5, 0.6, 0.7])
    }

    func test每門功法的門檻由低到高() {
        for move in Tables.moves {
            for sex in [Sex.male, Sex.female] {
                let values = move.thresholds(for: sex)
                XCTAssertEqual(values.count, Tables.levelNames.count - 1, move.name)
                XCTAssertEqual(values, values.sorted(), move.name)
            }
        }
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

    func test攀雲梯和撐柱式把自身體重算進負重() {
        let keys = Tables.moves.filter(\.usesBodyweight).map(\.key)
        XCTAssertEqual(keys, [.dip, .pull])
    }

    func test六個宗門身分的名字照網頁版() {
        let names = ["雜役弟子", "外門弟子", "內門弟子", "真傳弟子", "長老", "太上長老"]
        XCTAssertEqual(Tables.ranks.map(\.name), names)
    }

    func test六個宗門身分要的修煉天數照網頁版() {
        XCTAssertEqual(Tables.ranks.map(\.requiredDays), [0, 8, 24, 50, 150, 300])
    }

    /// 網頁版是 [-1, -1, 1, 2, 3, 4]；2026-11-17 多米定的，app 這邊各降一階。
    func test六個宗門身分要的境界比網頁版各降一階() {
        XCTAssertEqual(Tables.ranks.map(\.requiredRealmIndex), [-1, -1, -1, 1, 2, 3])
    }
}
