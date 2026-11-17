import XCTest

@testable import RencanCore

/// 宗門身分：六個正式身分，加上客卿、客卿長老、執事三種特殊身分。
/// 境界序號：-1 尚未入道、0 煉氣、1 築基、2 金丹、3 元嬰、4 化神。
/// 2026-11-17 起六階的境界門檻比網頁版各降一階（外門、內門只看天數，真傳築基、長老金丹、
/// 太上長老元嬰），所以這裡的答案是照新規則手算的，不再拿網頁版對。客卿、客卿長老照舊。
final class SectTests: XCTestCase {
    // MARK: 六個正式身分

    func test剛開始零天是雜役弟子() {
        let status = Formulas.sectOf(trainDays: 0, realmIndex: -1)
        XCTAssertEqual(status.title, "雜役弟子")
        XCTAssertEqual(status.note, "挑水劈柴，先把宗門的路走熟")
        XCTAssertEqual(status.next, "再修煉 8 天，升外門弟子")
        XCTAssertEqual(status.progressPercent, 3)
    }

    func test修煉8天升外門弟子() {
        let status = Formulas.sectOf(trainDays: 8, realmIndex: -1)
        XCTAssertEqual(status.title, "外門弟子")
        XCTAssertEqual(status.next, "再修煉 16 天，升內門弟子")
    }

    func test修煉24天還沒量過也是內門弟子() {
        let status = Formulas.sectOf(trainDays: 24, realmIndex: -1)
        XCTAssertEqual(status.title, "內門弟子")
        XCTAssertEqual(status.note, "修煉成了習慣，正式入了內門")
        XCTAssertEqual(status.next, "再修煉 26 天、突破至築基，升真傳弟子")
    }

    func test修煉24天又到築基是內門弟子只差天數() {
        let status = Formulas.sectOf(trainDays: 24, realmIndex: 1)
        XCTAssertEqual(status.title, "內門弟子")
        XCTAssertEqual(status.next, "再修煉 26 天，升真傳弟子")
    }

    func test修煉50天又到築基是真傳弟子() {
        let status = Formulas.sectOf(trainDays: 50, realmIndex: 1)
        XCTAssertEqual(status.title, "真傳弟子")
        XCTAssertEqual(status.note, "築基有成，宗門重點栽培")
        XCTAssertEqual(status.next, "再修煉 100 天、突破至金丹，升長老")
    }

    func test修煉50天還沒築基還是內門弟子() {
        let status = Formulas.sectOf(trainDays: 50, realmIndex: 0)
        XCTAssertEqual(status.title, "內門弟子")
        XCTAssertEqual(status.next, "突破至築基，升真傳弟子")
    }

    func test修煉150天又到金丹是長老() {
        let status = Formulas.sectOf(trainDays: 150, realmIndex: 2)
        XCTAssertEqual(status.title, "長老")
        XCTAssertEqual(status.note, "結成金丹，坐鎮一方")
        XCTAssertEqual(status.next, "再修煉 150 天、突破至元嬰，升太上長老")
    }

    func test修煉300天又到元嬰是太上長老() {
        let status = Formulas.sectOf(trainDays: 300, realmIndex: 3)
        XCTAssertEqual(status.title, "太上長老")
        XCTAssertEqual(status.note, "元嬰已成，宗門底蘊")
        XCTAssertEqual(status.next, "已是宗門最高位")
        XCTAssertEqual(status.progressPercent, 100)
    }

    func test到了渡劫還是太上長老() {
        let status = Formulas.sectOf(trainDays: 400, realmIndex: 6)
        XCTAssertEqual(status.title, "太上長老")
        XCTAssertEqual(status.rankIndex, 5)
    }

    func test金丹修煉300天沒到元嬰是長老() {
        let status = Formulas.sectOf(trainDays: 300, realmIndex: 2)
        XCTAssertEqual(status.title, "長老")
        XCTAssertEqual(status.next, "突破至元嬰，升太上長老")
    }

    // MARK: 三種特殊身分

    func test金丹但只修煉10天是客卿() {
        let status = Formulas.sectOf(trainDays: 10, realmIndex: 2)
        XCTAssertEqual(status.title, "客卿")
        XCTAssertEqual(status.note, "實力已達金丹，以客卿身分入宗")
        XCTAssertEqual(status.next, "再修煉 40 天，轉為正式真傳弟子")
        XCTAssertEqual(status.progressPercent, 20, accuracy: 1e-9)
    }

    func test金丹修煉滿50天轉成正式真傳弟子() {
        let status = Formulas.sectOf(trainDays: 60, realmIndex: 2)
        XCTAssertEqual(status.title, "真傳弟子")
        XCTAssertEqual(status.next, "再修煉 90 天，升長老")
        XCTAssertEqual(status.progressPercent, 10, accuracy: 1e-9)
    }

    func test築基但只修煉10天是外門弟子不是客卿() {
        let status = Formulas.sectOf(trainDays: 10, realmIndex: 1)
        XCTAssertEqual(status.title, "外門弟子")
        XCTAssertEqual(status.next, "再修煉 14 天，升內門弟子")
    }

    func test元嬰但只修煉10天是客卿長老() {
        let status = Formulas.sectOf(trainDays: 10, realmIndex: 3)
        XCTAssertEqual(status.title, "客卿長老")
        XCTAssertEqual(status.note, "實力已達元嬰，以客卿身分入宗")
        XCTAssertEqual(status.next, "再修煉 140 天，轉為正式長老")
        XCTAssertEqual(status.progressPercent, 6.666666666666667, accuracy: 1e-9)
    }

    func test元嬰修煉60天還是客卿長老() {
        let status = Formulas.sectOf(trainDays: 60, realmIndex: 3)
        XCTAssertEqual(status.title, "客卿長老")
        XCTAssertEqual(status.next, "再修煉 90 天，轉為正式長老")
        XCTAssertEqual(status.progressPercent, 40, accuracy: 1e-9)
    }

    func test修煉120天還沒築基是內門執事() {
        let status = Formulas.sectOf(trainDays: 120, realmIndex: 0)
        XCTAssertEqual(status.title, "內門執事")
        XCTAssertEqual(status.note, "修煉 120 天，資歷深厚，掌管宗門事務")
        XCTAssertEqual(status.next, "突破至築基，升真傳弟子")
        XCTAssertEqual(status.progressPercent, 100)
    }

    func test修煉99天還沒築基還是內門弟子不是執事() {
        let status = Formulas.sectOf(trainDays: 99, realmIndex: 0)
        XCTAssertEqual(status.title, "內門弟子")
        XCTAssertEqual(status.next, "突破至築基，升真傳弟子")
    }

    func test修煉120天築基沒到金丹是真傳弟子() {
        let status = Formulas.sectOf(trainDays: 120, realmIndex: 1)
        XCTAssertEqual(status.title, "真傳弟子")
        XCTAssertEqual(status.next, "再修煉 30 天、突破至金丹，升長老")
        XCTAssertEqual(status.progressPercent, 70, accuracy: 1e-9)
    }

    func test築基修煉160天沒到金丹是真傳弟子不是執事() {
        let status = Formulas.sectOf(trainDays: 160, realmIndex: 1)
        XCTAssertEqual(status.title, "真傳弟子")
        XCTAssertEqual(status.next, "突破至金丹，升長老")
    }

    // MARK: 境界頁小卡的短句（2026-11-18 多米說小卡右邊的字被拆成兩行）

    func test短句只差天數() {
        XCTAssertEqual(Formulas.sectOf(trainDays: 0, realmIndex: -1).shortNext, "再 8 天升外門")
    }

    func test短句天數和境界都差() {
        let status = Formulas.sectOf(trainDays: 24, realmIndex: -1)
        XCTAssertEqual(status.shortNext, "再 26 天＋築基升真傳")
    }

    func test短句只差境界() {
        let status = Formulas.sectOf(trainDays: 300, realmIndex: 2)
        XCTAssertEqual(status.shortNext, "突破元嬰升太上")
    }

    func test短句客卿() {
        let status = Formulas.sectOf(trainDays: 10, realmIndex: 2)
        XCTAssertEqual(status.shortNext, "再 40 天轉正式真傳")
    }

    func test短句已是最高位() {
        XCTAssertEqual(Formulas.sectOf(trainDays: 300, realmIndex: 3).shortNext, "已是最高位")
    }

    // MARK: 進度條

    func test修煉5天離外門的進度是百分之62點5() {
        let status = Formulas.sectOf(trainDays: 5, realmIndex: -1)
        XCTAssertEqual(status.next, "再修煉 3 天，升外門弟子")
        XCTAssertEqual(status.progressPercent, 62.5, accuracy: 1e-9)
    }

    func test修煉23天只差1天的進度是百分之93點75() {
        let status = Formulas.sectOf(trainDays: 23, realmIndex: -1)
        XCTAssertEqual(status.next, "再修煉 1 天，升內門弟子")
        XCTAssertEqual(status.progressPercent, 93.75, accuracy: 1e-9)
    }

    func test天數夠了只差境界時進度條是滿的() {
        let status = Formulas.sectOf(trainDays: 60, realmIndex: 0)
        XCTAssertEqual(status.title, "內門弟子")
        XCTAssertEqual(status.progressPercent, 100)
    }
}
