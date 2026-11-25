import XCTest

@testable import RencanCore

/// 境界、突破紀錄、天數的算法。答案都是拿網頁版 index.html 的程式算出來的
/// （身高校正 2026-11-23 兩邊一起從 6.1 改成 6.3）。
final class FormulasTests: XCTestCase {
    private let heightCm: Double = 174

    private func label(ofFFMI ffmi: Double) -> String {
        Formulas.realmOf(ffmi: ffmi).label
    }

    /// 五筆量測：第一筆體脂 22% 不穩；之後去脂 58.22、60.4032、59.5、62.5。
    private func fiveMeasurements() -> [MeasurementEntry] {
        let first = MeasurementEntry(
            id: "2026-01-05", date: "2026-01-05", weightKg: 72, bodyFatPercent: 22, createdAtMs: 1
        )
        let second = MeasurementEntry(
            id: "2026-02-05", date: "2026-02-05", weightKg: 71, bodyFatPercent: 18, createdAtMs: 2
        )
        let third = MeasurementEntry(
            id: "2026-03-05", date: "2026-03-05", weightKg: 70.4, bodyFatPercent: 14.2,
            createdAtMs: 3
        )
        let fourth = MeasurementEntry(
            id: "2026-04-05", date: "2026-04-05", weightKg: 70, bodyFatPercent: 15, createdAtMs: 4
        )
        let fifth = MeasurementEntry(
            id: "2026-06-05", date: "2026-06-05", weightKg: 72, bodyFatPercent: 14,
            leanMassKg: 62.5, createdAtMs: 5
        )
        // 故意不照日期放，突破紀錄要自己排。
        return [fourth, first, fifth, third, second]
    }

    // MARK: 境界

    func test身高174體重70點4體脂14點2是金丹中期() throws {
        let leanMassKg = 70.4 * (1 - 14.2 / 100)
        let ffmi = Formulas.ffmi(leanMassKg: leanMassKg, heightCm: heightCm)
        XCTAssertEqual(ffmi, 20.33, accuracy: 0.005)
        XCTAssertEqual(ffmi, 20.328852160126836, accuracy: 1e-9)
        XCTAssertEqual(label(ofFFMI: ffmi), "金丹中期")
        let maybeGap = Formulas.nextStageGap(leanMassKg: leanMassKg, heightCm: heightCm)
        let gap = try XCTUnwrap(maybeGap)
        XCTAssertEqual(gap.nextLabel, "金丹後期")
        XCTAssertEqual(gap.leanNeededKg, 0.5, accuracy: 0.05)
        XCTAssertEqual(gap.leanNeededKg, 0.5181672, accuracy: 1e-6)
    }

    func test去脂體重反推回FFMI會是同一個數字() {
        let leanMassKg = Formulas.leanFor(ffmi: 20.5, heightCm: heightCm)
        let ffmi = Formulas.ffmi(leanMassKg: leanMassKg, heightCm: heightCm)
        XCTAssertEqual(ffmi, 20.5, accuracy: 1e-9)
    }

    func testFFMI17是煉氣中期() {
        XCTAssertEqual(label(ofFFMI: 17), "煉氣中期")
    }

    func testFFMI18點2是築基初期() {
        XCTAssertEqual(label(ofFFMI: 18.2), "築基初期")
    }

    func testFFMI19點6是金丹初期() {
        XCTAssertEqual(label(ofFFMI: 19.6), "金丹初期")
    }

    func testFFMI21點9是元嬰中期() {
        XCTAssertEqual(label(ofFFMI: 21.9), "元嬰中期")
    }

    func testFFMI23點7是化神後期() {
        XCTAssertEqual(label(ofFFMI: 23.7), "化神後期")
    }

    func testFFMI24點1是大乘初期() {
        XCTAssertEqual(label(ofFFMI: 24.1), "大乘初期")
    }

    func testFFMI26是渡劫中期() {
        XCTAssertEqual(label(ofFFMI: 26), "渡劫中期")
    }

    func testFFMI剛好18算築基初期() {
        let standing = Formulas.realmOf(ffmi: 18)
        XCTAssertEqual(standing.label, "築基初期")
        XCTAssertEqual(standing.nextFFMI, 18.5)
        XCTAssertEqual(standing.fromFFMI, 18)
    }

    func testFFMI低於16點5算煉氣初期而且下一個門檻是16點5() {
        let standing = Formulas.realmOf(ffmi: 15)
        XCTAssertEqual(standing.label, "煉氣初期")
        XCTAssertEqual(standing.nextFFMI, 16.5)
        XCTAssertEqual(standing.fromFFMI, 16.5)
    }

    func testFFMI超過27還是渡劫後期而且沒有下一期() {
        let standing = Formulas.realmOf(ffmi: 28)
        XCTAssertEqual(standing.label, "渡劫後期")
        XCTAssertNil(standing.nextFFMI)
        XCTAssertEqual(standing.fromFFMI, 26.5)
    }

    func test渡劫後期沒有還差幾公斤() {
        let leanMassKg = Formulas.leanFor(ffmi: 26.6, heightCm: heightCm)
        XCTAssertNil(Formulas.nextStageGap(leanMassKg: leanMassKg, heightCm: heightCm))
    }

    func test體脂秤有給去脂體重就直接用() {
        let measurement = MeasurementEntry(
            id: "a", date: "2026-06-05", weightKg: 72, bodyFatPercent: 14, leanMassKg: 62.5
        )
        XCTAssertEqual(Formulas.leanOf(measurement), 62.5)
    }

    func test沒給去脂體重就用體重和體脂率算() {
        let measurement = MeasurementEntry(
            id: "a", date: "2026-06-05", weightKg: 72, bodyFatPercent: 14
        )
        XCTAssertEqual(Formulas.leanOf(measurement), 61.92, accuracy: 1e-9)
    }

    // MARK: 突破紀錄

    func test突破紀錄只記第一次到達更高期別的那幾筆() throws {
        let records = try Formulas.breakthroughs(
            measurements: fiveMeasurements(), heightCm: heightCm
        )
        // 三月、四月的平均都還在金丹初期；六月往回 90 天只剩四月，兩次平均 61 到金丹後期。
        XCTAssertEqual(records.map(\.date), ["2026-02-05", "2026-06-05"])
        XCTAssertEqual(records.map(\.label), ["金丹初期", "金丹後期"])
        XCTAssertEqual(records.map(\.stageRank), [6, 8])
    }

    func test突破紀錄第一筆是入道起點而且之後寫出距上一階幾天() throws {
        let records = try Formulas.breakthroughs(
            measurements: fiveMeasurements(), heightCm: heightCm
        )
        XCTAssertEqual(records.map(\.isFirst), [true, false])
        XCTAssertEqual(records.map(\.daysSincePrevious), [0, 120])
    }

    func test體脂超過20的量測不算突破() throws {
        let unstable = MeasurementEntry(
            id: "a", date: "2026-01-05", weightKg: 72, bodyFatPercent: 22
        )
        let records = try Formulas.breakthroughs(measurements: [unstable], heightCm: heightCm)
        XCTAssertEqual(records, [])
    }

    func test曾到過金丹最高境界就是金丹() throws {
        let top = try Formulas.realmMax(measurements: fiveMeasurements(), heightCm: heightCm)
        XCTAssertEqual(top, 2)
        XCTAssertEqual(Tables.realms[top].name, "金丹")
    }

    func test還沒有穩固量測時最高境界是尚未入道() throws {
        let top = try Formulas.realmMax(measurements: [], heightCm: heightCm)
        XCTAssertEqual(top, Tables.noRealmIndex)
    }

    // MARK: 天數

    func test二月28到三月1在閏年是2天() throws {
        XCTAssertEqual(try Formulas.daysBetween("2024-02-28", "2024-03-01"), 2)
    }

    func test跨年的前後兩天差1天() throws {
        XCTAssertEqual(try Formulas.daysBetween("2025-12-31", "2026-01-01"), 1)
    }

    func test日期倒過來天數差是負的() throws {
        XCTAssertEqual(try Formulas.daysBetween("2026-03-01", "2026-01-01"), -59)
    }

    func test日期用斜線寫會被擋下來() {
        XCTAssertThrowsError(try Formulas.daysBetween("2026/03/01", "2026-03-02")) { error in
            XCTAssertEqual(error as? RencanError, .invalidDate)
        }
    }

    func test不存在的日子會被擋下來() {
        XCTAssertThrowsError(try Formulas.daysBetween("2026-02-30", "2026-03-02"))
        XCTAssertThrowsError(try Formulas.daysBetween("2026-13-01", "2026-03-02"))
        XCTAssertThrowsError(try Formulas.daysBetween("2025-02-29", "2026-03-02"))
    }

    func test59天寫成59天() {
        XCTAssertEqual(Formulas.durTxt(days: 59), "59 天")
    }

    func test60天寫成2個月() {
        XCTAssertEqual(Formulas.durTxt(days: 60), "2 個月")
    }

    func test75天寫成3個月() {
        XCTAssertEqual(Formulas.durTxt(days: 75), "3 個月")
    }

    func test365天寫成1年() {
        XCTAssertEqual(Formulas.durTxt(days: 365), "1 年")
    }

    func test400天寫成1年1個月() {
        XCTAssertEqual(Formulas.durTxt(days: 400), "1 年 1 個月")
    }

    func test同一天的兩筆量測照建立時間排先後() {
        let later = MeasurementEntry(
            id: "b", date: "2026-03-05", weightKg: 71, bodyFatPercent: 15, createdAtMs: 9
        )
        let earlier = MeasurementEntry(
            id: "a", date: "2026-03-05", weightKg: 70, bodyFatPercent: 15, createdAtMs: 2
        )
        XCTAssertEqual(Formulas.byDate([later, earlier]).map(\.id), ["a", "b"])
    }
}
