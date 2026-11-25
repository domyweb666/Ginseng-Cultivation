import XCTest

@testable import RencanCore

// 慶祝判定的每一條路。測試名對著 .vibe/標準清單.md 的兩張「判定規則白話表」，一列一條。
// 身高一律 174。體重 70 公斤、體脂 18% 是築基後期。

private let heightCm: Double = 174

private func weighing(_ kg: Double, bodyFat: Double, on date: String) -> MeasurementEntry {
    MeasurementEntry(id: date, date: date, weightKg: kg, bodyFatPercent: bodyFat)
}

private func lift(
    _ move: MoveKey, kg: Double, on date: String, bodyweightKg: Double? = nil
) -> LiftEntry {
    LiftEntry(
        id: date + move.rawValue, date: date, move: move, kg: kg, reps: 5, sets: 3,
        bodyweightKg: bodyweightKg
    )
}

/// 一月份連續幾天，每天深蹲 60 公斤 5 下（體重 70 時是小成）。
private func squatDays(_ count: Int) -> [LiftEntry] {
    (1...count).map { day in
        lift(.squat, kg: 60, on: day < 10 ? "2026-01-0\(day)" : "2026-01-\(day)")
    }
}

/// 接在一月後面，二月份連續幾天的深蹲（一月只有 31 天，要湊 50 天時用）。
private func februarySquatDays(_ count: Int) -> [LiftEntry] {
    (1...count).map { day in
        lift(.squat, kg: 60, on: day < 10 ? "2026-02-0\(day)" : "2026-02-\(day)")
    }
}

/// 白話表第一張：記一筆修煉，由上往下五選一。
final class LiftJudgementTests: XCTestCase {
    private let body = [weighing(70, bodyFat: 18, on: "2025-12-01")]

    private func judge(_ new: LiftEntry, before: [LiftEntry]) throws -> LiftJudgement {
        try Judgement.liftOutcome(
            new: new, before: before, measurements: body, heightCm: heightCm
        )
    }

    func test第1列這筆讓修煉天數到8天升外門是宗門晉升() throws {
        let result = try judge(lift(.squat, kg: 60, on: "2026-02-01"), before: squatDays(7))
        XCTAssertEqual(result.outcome, .sectPromotion)
        XCTAssertEqual(result.trainDaysAfter, 8)
        XCTAssertEqual(result.sectAfter.title, "外門弟子")
    }

    func test同一天記第二筆不重複算天所以不晉升() throws {
        let result = try judge(lift(.bench, kg: 40, on: "2026-01-07"), before: squatDays(7))
        XCTAssertEqual(result.outcome, .firstRecord)
        XCTAssertEqual(result.trainDaysAfter, 7)
        XCTAssertEqual(result.sectAfter.title, "雜役弟子")
    }

    func test宗門晉升排在功法突破前面() throws {
        let result = try judge(lift(.squat, kg: 80, on: "2026-02-01"), before: squatDays(7))
        XCTAssertEqual(result.outcome, .sectPromotion)
        XCTAssertTrue(result.isLevelUp)
    }

    func test第2列這門功法以前一筆都沒有是開練() throws {
        let result = try judge(lift(.bench, kg: 40, on: "2026-02-01"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .firstRecord)
        XCTAssertEqual(result.level, 1)
    }

    func test第3列比值跨過下一階門檻是功法突破() throws {
        let result = try judge(lift(.squat, kg: 80, on: "2026-02-01"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .levelUp)
        XCTAssertEqual(result.level, 3)
        XCTAssertTrue(result.isLevelUp)
    }

    func test第4列估計1RM比歷來最高還高是功法精進() throws {
        let result = try judge(lift(.squat, kg: 62.5, on: "2026-02-01"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .personalBest)
        XCTAssertEqual(try XCTUnwrap(result.gainKg), 2.9166666666666714, accuracy: 1e-6)
        XCTAssertFalse(result.isLevelUp)
    }

    func test第5列以上都不是就是修煉加1() throws {
        let result = try judge(lift(.squat, kg: 55, on: "2026-02-01"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .logged)
        XCTAssertNil(result.gainKg)
    }

    func test體重掉了比值變高但1RM沒變不放精進() throws {
        let before = [lift(.squat, kg: 60, on: "2026-01-05", bodyweightKg: 72)]
        let new = lift(.squat, kg: 60, on: "2026-02-01", bodyweightKg: 70.5)
        let result = try judge(new, before: before)
        XCTAssertEqual(result.outcome, .logged)
        XCTAssertNil(result.gainKg)
    }

    func test體重掉了讓比值跨過門檻照樣是功法突破() throws {
        let before = [lift(.squat, kg: 60, on: "2026-01-05", bodyweightKg: 72)]
        let new = lift(.squat, kg: 60, on: "2026-02-01", bodyweightKg: 69)
        let result = try judge(new, before: before)
        XCTAssertEqual(result.outcome, .levelUp)
        XCTAssertEqual(result.level, 2)
    }

    func test引體向上體重變重做一樣多下也算功法精進() throws {
        let before = [lift(.pull, kg: 0, on: "2026-01-05", bodyweightKg: 70)]
        let new = lift(.pull, kg: 0, on: "2026-02-01", bodyweightKg: 72)
        let result = try judge(new, before: before)
        XCTAssertEqual(result.outcome, .personalBest)
        XCTAssertEqual(try XCTUnwrap(result.gainKg), 2.3333333333333286, accuracy: 1e-6)
    }

    func test從沒量過體重記修煉只算修煉加1() throws {
        let result = try Judgement.liftOutcome(
            new: lift(.squat, kg: 80, on: "2026-02-01"), before: squatDays(3), measurements: [],
            heightCm: heightCm
        )
        XCTAssertEqual(result.outcome, .logged)
        XCTAssertNil(result.calc)
        XCTAssertNil(result.level)
    }

    func test從沒量過體重但天數到了照樣宗門晉升() throws {
        let result = try Judgement.liftOutcome(
            new: lift(.squat, kg: 60, on: "2026-02-01"), before: squatDays(7), measurements: [],
            heightCm: heightCm
        )
        XCTAssertEqual(result.outcome, .sectPromotion)
        XCTAssertEqual(result.sectAfter.title, "外門弟子")
    }
}

/// 白話表第二張：量一次體組成，由上往下四選一。
final class MeasurementJudgementTests: XCTestCase {
    /// 築基後期
    private let foundationLate = weighing(70, bodyFat: 18, on: "2026-01-05")
    /// 金丹初期
    private let coreEarly = weighing(71, bodyFat: 18, on: "2026-02-05")

    private func judge(
        _ new: MeasurementEntry, before: [MeasurementEntry], lifts: [LiftEntry] = []
    ) throws -> MeasurementJudgement {
        try Judgement.measurementOutcome(
            new: new, before: before, lifts: lifts, heightCm: heightCm
        )
    }

    func test第1列體脂超過20是根基不穩但照樣算出境界() throws {
        let result = try judge(weighing(80, bodyFat: 24, on: "2026-03-05"), before: [])
        XCTAssertEqual(result.outcome, .unstable)
        XCTAssertEqual(result.standing.label, "金丹中期")
        XCTAssertEqual(result.ffmi, 20.4599, accuracy: 1e-4)
    }

    func test根基不穩不動宗門身分() throws {
        let new = weighing(80, bodyFat: 24, on: "2026-03-05")
        let result = try judge(new, before: [], lifts: squatDays(28))
        XCTAssertEqual(result.outcome, .unstable)
        XCTAssertNil(result.promotedSectTitle)
    }

    func test體脂剛好20不算超過() throws {
        let result = try judge(weighing(70, bodyFat: 20, on: "2026-03-05"), before: [])
        XCTAssertEqual(result.outcome, .enteredPath)
    }

    func test第2列以前沒有穩固的量測是踏入仙途() throws {
        let unstable = weighing(80, bodyFat: 24, on: "2026-01-01")
        let result = try judge(foundationLate, before: [unstable])
        XCTAssertEqual(result.outcome, .enteredPath)
        XCTAssertEqual(result.standing.label, "築基後期")
        XCTAssertNil(result.daysSincePrevious)
    }

    func test踏入仙途同時宗門身分升了會多帶一句() throws {
        // 修煉滿 50 天還沒量過是內門弟子，第一次量到築基就升真傳（真傳要築基）。
        let lifts = squatDays(31) + februarySquatDays(19)
        let result = try judge(foundationLate, before: [], lifts: lifts)
        XCTAssertEqual(result.outcome, .enteredPath)
        XCTAssertEqual(result.promotedSectTitle, "真傳弟子")
    }

    func test第3列期別比歷來最高還高是境界突破() throws {
        let new = weighing(71, bodyFat: 14, on: "2026-03-05")
        let result = try judge(new, before: [coreEarly])
        XCTAssertEqual(result.outcome, .breakthrough)
        XCTAssertEqual(result.standing.label, "金丹中期")
        XCTAssertEqual(result.daysSincePrevious, 28)
    }

    func test第3列跨到新的大境界是大境界突破() throws {
        // 去脂 57.4 與 59.04 的平均是 58.22，金丹初期
        let new = weighing(72, bodyFat: 18, on: "2026-02-05")
        let result = try judge(new, before: [foundationLate])
        XCTAssertEqual(result.outcome, .majorBreakthrough)
        XCTAssertEqual(result.standing.label, "金丹初期")
        XCTAssertEqual(result.daysSincePrevious, 31)
    }

    func test跟上次突破同一天再量到更高也算突破() throws {
        let new = weighing(70.4, bodyFat: 14.2, on: "2026-02-05")
        let result = try judge(new, before: [coreEarly])
        XCTAssertEqual(result.outcome, .breakthrough)
        XCTAssertEqual(result.daysSincePrevious, 0)
    }

    func test第4列期別沒有更高就是結算() throws {
        let new = weighing(70, bodyFat: 18, on: "2026-03-05")
        let result = try judge(new, before: [coreEarly])
        XCTAssertEqual(result.outcome, .settled)
        XCTAssertEqual(result.standing.label, "金丹初期", "這次量到築基後期，境界不降")
        XCTAssertNil(result.daysSincePrevious)
    }

    func test補登過去日期的量測不放煙火() throws {
        let backfill = weighing(70.4, bodyFat: 14.2, on: "2026-01-10")
        let result = try judge(backfill, before: [coreEarly])
        XCTAssertEqual(result.outcome, .settled)
        XCTAssertEqual(result.standing.label, "金丹中期")
    }

    func test結算不帶宗門晉升那一句() throws {
        let backfill = weighing(71, bodyFat: 18, on: "2026-01-01")
        let result = try judge(backfill, before: [foundationLate], lifts: squatDays(28))
        XCTAssertEqual(result.outcome, .settled)
        XCTAssertNil(result.promotedSectTitle)
    }
}
