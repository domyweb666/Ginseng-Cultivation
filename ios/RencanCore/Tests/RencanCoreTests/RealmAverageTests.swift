import XCTest

@testable import RencanCore

// 境界看最近三次的平均、只升不降（規則在 RealmAverage.swift 檔頭）。
// 身高 174 的男性：去脂 58.22 是金丹初期、59.64 是金丹中期、60.4032 是金丹中期、57.4 是築基後期。

private let heightCm: Double = 174

private func weighing(
    _ kg: Double, bodyFat: Double, on date: String, lean: Double? = nil
) -> MeasurementEntry {
    MeasurementEntry(
        id: date, date: date, weightKg: kg, bodyFatPercent: bodyFat, leanMassKg: lean
    )
}

final class RealmAverageTests: XCTestCase {
    private let january = weighing(70, bodyFat: 15, on: "2026-01-05", lean: 58)
    private let february = weighing(70, bodyFat: 15, on: "2026-02-05", lean: 59)
    private let march = weighing(70, bodyFat: 15, on: "2026-03-05", lean: 63)
    private let april = weighing(70, bodyFat: 15, on: "2026-04-05", lean: 61)

    private func average(
        of measurement: MeasurementEntry, among all: [MeasurementEntry], sex: Sex = .male
    ) throws -> LeanAverage {
        try Formulas.leanAverage(of: measurement, among: all, sex: sex)
    }

    private func digest(_ measurements: [MeasurementEntry]) throws -> Digest {
        try Digest(
            measurements: measurements, lifts: [], heightCm: heightCm, sex: .male,
            today: "2026-06-30"
        )
    }

    // MARK: 平均

    func test只量過一次就是那一次() throws {
        let result = try average(of: january, among: [january])
        XCTAssertEqual(result, LeanAverage(count: 1, leanMassKg: 58))
    }

    func test量過兩次就兩次平均() throws {
        let result = try average(of: february, among: [january, february])
        XCTAssertEqual(result, LeanAverage(count: 2, leanMassKg: 58.5))
    }

    func test最多三次而且不管傳進來的順序() throws {
        let result = try average(of: april, among: [march, january, april, february])
        XCTAssertEqual(result, LeanAverage(count: 3, leanMassKg: 61))
    }

    func test剛好90天算91天不算() throws {
        let last = weighing(70, bodyFat: 15, on: "2026-04-05", lean: 60)
        let ninety = weighing(70, bodyFat: 15, on: "2026-01-05", lean: 58)
        let older = weighing(70, bodyFat: 15, on: "2026-01-04", lean: 58)
        XCTAssertEqual(try average(of: last, among: [ninety, last]).count, 2)
        XCTAssertEqual(try average(of: last, among: [older, last]).count, 1)
    }

    func test之後的量測不採計() throws {
        let result = try average(of: january, among: [january, february, march])
        XCTAssertEqual(result.count, 1)
    }

    func test體脂超標的不會跟門檻以內的一起平均() throws {
        let heavy = weighing(80, bodyFat: 24, on: "2026-02-20", lean: 66)
        let result = try average(of: march, among: [february, heavy, march])
        XCTAssertEqual(result, LeanAverage(count: 2, leanMassKg: 61))
        XCTAssertEqual(try average(of: heavy, among: [february, heavy, march]).count, 1)
    }

    func test日期壞掉時丟錯誤() {
        let bad = weighing(70, bodyFat: 15, on: "2026-01/05", lean: 58)
        XCTAssertThrowsError(try average(of: february, among: [bad, february])) { error in
            XCTAssertEqual(error as? RencanError, .invalidDate)
        }
    }

    // MARK: 境界碑

    func test量到比較低時境界不降FFMI照這次的數字() throws {
        let high = weighing(70.4, bodyFat: 14.2, on: "2026-03-05")
        let low = weighing(70, bodyFat: 18, on: "2026-04-05")
        let stele = try XCTUnwrap(try digest([high, low]).stele)
        XCTAssertEqual(stele.standing.label, "金丹中期")
        XCTAssertEqual(stele.ffmi, 57.4 / (1.74 * 1.74) + 6.3 * 0.06, accuracy: 1e-9)
        // 金丹後期要 20.5：(20.5 − 0.378) × 3.0276 = 60.9214；兩次平均 58.9016，還差 2.0198
        XCTAssertEqual(stele.gap?.nextLabel, "金丹後期")
        XCTAssertEqual(try XCTUnwrap(stele.gap).leanNeededKg, 2.0198, accuracy: 1e-3)
        XCTAssertEqual(stele.stagePercent, 2)
        XCTAssertTrue(stele.hasBreakthrough)
    }

    func test單次量高了但平均沒到不算突破() throws {
        let first = weighing(71, bodyFat: 18, on: "2026-02-05")
        let spike = weighing(70.4, bodyFat: 14.2, on: "2026-03-05")
        let result = try digest([first, spike])
        XCTAssertEqual(result.breakthroughs.map(\.label), ["金丹初期"])
        XCTAssertEqual(result.stele?.standing.label, "金丹初期")
    }

    func test突破過的人體脂超標境界照舊只是根基不穩() throws {
        let stable = weighing(70, bodyFat: 18, on: "2026-03-05")
        let heavy = weighing(80, bodyFat: 24, on: "2026-04-05")
        let stele = try XCTUnwrap(try digest([stable, heavy]).stele)
        XCTAssertEqual(stele.standing.label, "築基後期")
        XCTAssertEqual(stele.gate, .unstable(overBy: 4))
        XCTAssertTrue(stele.hasBreakthrough)
    }

    func test體脂從24降到18那次馬上生效不用等平均() throws {
        let heavy = weighing(80, bodyFat: 24, on: "2026-03-05")
        let lean = weighing(70, bodyFat: 18, on: "2026-04-05")
        let result = try digest([heavy, lean])
        XCTAssertEqual(result.stele?.gate, .stable)
        XCTAssertEqual(result.breakthroughs.map(\.label), ["築基後期"])
    }

    func test還沒突破過時境界照平均走() throws {
        let heavy = weighing(80, bodyFat: 24, on: "2026-03-05")
        let stele = try XCTUnwrap(try digest([heavy]).stele)
        XCTAssertEqual(stele.standing.label, "金丹中期")
        XCTAssertFalse(stele.hasBreakthrough)
    }

    // MARK: 判定

    func test判定帶著平均幾次與平均的FFMI() throws {
        let first = weighing(71, bodyFat: 18, on: "2026-02-05")
        let second = weighing(71, bodyFat: 14, on: "2026-03-05")
        let result = try Judgement.measurementOutcome(
            new: second, before: [first], lifts: [], heightCm: heightCm
        )
        XCTAssertEqual(result.averageCount, 2)
        XCTAssertEqual(result.averageFFMI, 59.64 / (1.74 * 1.74) + 6.3 * 0.06, accuracy: 1e-9)
        XCTAssertEqual(result.ffmi, 61.06 / (1.74 * 1.74) + 6.3 * 0.06, accuracy: 1e-9)
    }

    func test蓋掉同一天打錯的那筆境界照改過的算() throws {
        let typo = weighing(90, bodyFat: 14, on: "2026-02-05")
        let fixed = weighing(71, bodyFat: 18, on: "2026-02-05")
        let result = try Judgement.measurementOutcome(
            new: fixed, before: [typo], lifts: [], heightCm: heightCm
        )
        XCTAssertEqual(result.outcome, .settled)
        XCTAssertEqual(result.standing.label, "金丹初期")
        XCTAssertEqual(result.averageCount, 1)
    }
}
