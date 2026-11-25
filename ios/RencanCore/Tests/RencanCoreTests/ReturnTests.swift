import XCTest

@testable import RencanCore

// 出關、引氣入體、沒量過體重的精進（2026-11-25 多米定，由來在 .vibe/研究對照-2026-11-25.md）。
// 身高 174、體重 70 公斤：深蹲 60 公斤 5 下的估計 1RM 是 60 ×（1 + 5 ÷ 30）= 70，1.0 倍體重，小成。
// 一月 3 日之後第 20 天是 23 日、第 21 天是 24 日。

private let heightCm: Double = 174

private let body = [
    MeasurementEntry(id: "m", date: "2025-12-01", weightKg: 70, bodyFatPercent: 18)
]

private func lift(
    _ move: MoveKey, kg: Double, reps: Int = 5, on date: String
) -> LiftEntry {
    LiftEntry(
        id: date + move.rawValue + String(reps), date: date, move: move, kg: kg, reps: reps,
        sets: 3
    )
}

/// 一月份從 1 日起連續幾天（最多 9 天），每天深蹲 60 公斤 5 下。
private func squatDays(_ count: Int) -> [LiftEntry] {
    (1...count).map { lift(.squat, kg: 60, on: "2026-01-0\($0)") }
}

private func judge(
    _ new: LiftEntry, before: [LiftEntry], measurements: [MeasurementEntry] = body
) throws -> LiftJudgement {
    try Judgement.liftOutcome(
        new: new, before: before, measurements: measurements, heightCm: heightCm, sex: .male
    )
}

/// 出關：比歷來最晚那筆晚 21 天以上（含）。
final class ReturnJudgementTests: XCTestCase {
    func test第5列剛好隔21天是出關() throws {
        let result = try judge(lift(.squat, kg: 60, on: "2026-01-24"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .returned)
        XCTAssertTrue(result.isReturn)
        XCTAssertEqual(result.trainDaysAfter, 4)
    }

    func test隔20天還不算出關() throws {
        let result = try judge(lift(.squat, kg: 60, on: "2026-01-23"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .logged)
        XCTAssertFalse(result.isReturn)
    }

    func test隔很久比較輕也是出關() throws {
        let result = try judge(lift(.squat, kg: 40, on: "2026-08-01"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .returned)
        XCTAssertNil(result.gainKg)
    }

    func test補登比最晚那筆早的日期不算出關() throws {
        let before = squatDays(1) + [lift(.squat, kg: 60, on: "2026-03-01")]
        let between = try judge(lift(.squat, kg: 60, on: "2026-02-10"), before: before)
        XCTAssertEqual(between.outcome, .logged)
        XCTAssertFalse(between.isReturn)
        let earlier = try judge(lift(.squat, kg: 60, on: "2025-10-01"), before: before)
        XCTAssertFalse(earlier.isReturn)
    }

    func test跟最晚那筆同一天不算出關() throws {
        let result = try judge(lift(.squat, kg: 60, on: "2026-01-03"), before: squatDays(3))
        XCTAssertFalse(result.isReturn)
    }

    func test比的是日期最晚那筆不是最後才記的那筆() throws {
        // 先記三月 1 日，後來才補登一月頭兩天；三月 10 日這筆離三月 1 日只有 9 天
        let before = [lift(.squat, kg: 60, on: "2026-03-01")] + squatDays(2)
        let result = try judge(lift(.squat, kg: 60, on: "2026-03-10"), before: before)
        XCTAssertFalse(result.isReturn)
    }

    func test出關排在開練前面() throws {
        let result = try judge(lift(.bench, kg: 40, on: "2026-01-24"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .returned)
        XCTAssertEqual(result.level, 1)
    }

    func test出關同時宗門晉升照舊是宗門晉升() throws {
        let result = try judge(lift(.squat, kg: 60, on: "2026-01-28"), before: squatDays(7))
        XCTAssertEqual(result.outcome, .sectPromotion)
        XCTAssertTrue(result.isReturn)
    }

    func test出關同時功法突破照舊是功法突破() throws {
        let result = try judge(lift(.squat, kg: 80, on: "2026-01-24"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .levelUp)
        XCTAssertTrue(result.isReturn)
    }

    func test出關同時功法精進照舊是功法精進() throws {
        let result = try judge(lift(.squat, kg: 62.5, on: "2026-01-24"), before: squatDays(3))
        XCTAssertEqual(result.outcome, .personalBest)
        XCTAssertTrue(result.isReturn)
    }

    func test從沒量過體重也會出關() throws {
        let new = lift(.squat, kg: 60, on: "2026-01-24")
        let result = try judge(new, before: squatDays(3), measurements: [])
        XCTAssertEqual(result.outcome, .returned)
        XCTAssertNil(result.level)
    }

    func test日期壞掉時丟錯不會安靜算錯() {
        let broken = lift(.squat, kg: 60, on: "2026/01/24")
        XCTAssertThrowsError(try judge(broken, before: squatDays(3))) { error in
            XCTAssertEqual(error as? RencanError, .invalidDate)
        }
    }
}

/// 引氣入體：第一筆修煉，有沒有量過體重都一樣。
final class FirstLiftJudgementTests: XCTestCase {
    func test第2列第一筆修煉是引氣入體而且算得出等級() throws {
        let result = try judge(lift(.squat, kg: 60, on: "2026-01-03"), before: [])
        XCTAssertEqual(result.outcome, .firstLift)
        XCTAssertEqual(result.level, 2)
        XCTAssertEqual(result.trainDaysAfter, 1)
        XCTAssertFalse(result.isReturn)
    }

    func test沒量過體重的第一筆也是引氣入體沒有等級() throws {
        let new = lift(.squat, kg: 60, on: "2026-01-03")
        let result = try judge(new, before: [], measurements: [])
        XCTAssertEqual(result.outcome, .firstLift)
        XCTAssertNil(result.calc)
        XCTAssertNil(result.level)
    }

    func test第二筆換一門是開練不會再引氣入體() throws {
        let result = try judge(lift(.bench, kg: 40, on: "2026-01-01"), before: squatDays(1))
        XCTAssertEqual(result.outcome, .firstRecord)
    }
}

/// 從沒量過體重：非自重功法的估計 1RM 直接比公斤數，算不出等級照舊是 nil。
final class UnweighedBestTests: XCTestCase {
    private func judgeUnweighed(_ new: LiftEntry, before: [LiftEntry]) throws -> LiftJudgement {
        try judge(new, before: before, measurements: [])
    }

    func test比以前重就是功法精進帶多幾公斤() throws {
        // 62.5 ×（1 + 5 ÷ 30）= 72.9167，比 70 多 2.9167
        let new = lift(.squat, kg: 62.5, on: "2026-01-10")
        let result = try judgeUnweighed(new, before: squatDays(3))
        XCTAssertEqual(result.outcome, .personalBest)
        XCTAssertEqual(try XCTUnwrap(result.gainKg), 2.9166667, accuracy: 1e-6)
        XCTAssertNil(result.calc)
        XCTAssertNil(result.level)
        XCTAssertFalse(result.isLevelUp)
    }

    func test重量一樣多做幾下也是功法精進() throws {
        // 60 ×（1 + 8 ÷ 30）= 76，比 70 多 6
        let new = lift(.squat, kg: 60, reps: 8, on: "2026-01-10")
        let result = try judgeUnweighed(new, before: squatDays(3))
        XCTAssertEqual(result.outcome, .personalBest)
        XCTAssertEqual(try XCTUnwrap(result.gainKg), 6, accuracy: 1e-6)
    }

    func test一樣或比較輕是修煉加1() throws {
        let same = try judgeUnweighed(
            lift(.squat, kg: 60, on: "2026-01-10"), before: squatDays(3)
        )
        XCTAssertEqual(same.outcome, .logged)
        XCTAssertNil(same.gainKg)
        let lighter = try judgeUnweighed(
            lift(.squat, kg: 55, on: "2026-01-10"), before: squatDays(3)
        )
        XCTAssertEqual(lighter.outcome, .logged)
    }

    func test這門以前沒紀錄是修煉加1() throws {
        let new = lift(.bench, kg: 40, on: "2026-01-10")
        let result = try judgeUnweighed(new, before: squatDays(3))
        XCTAssertEqual(result.outcome, .logged)
        XCTAssertNil(result.gainKg)
    }

    func test自重功法多做幾下也只是修煉加1() throws {
        let before = [lift(.pull, kg: 0, on: "2026-01-01")]
        let new = lift(.pull, kg: 5, reps: 8, on: "2026-01-10")
        let result = try judgeUnweighed(new, before: before)
        XCTAssertEqual(result.outcome, .logged)
        XCTAssertNil(result.gainKg)
    }

    func test隔21天又破紀錄是功法精進也算出關後的第一筆() throws {
        let new = lift(.squat, kg: 62.5, on: "2026-01-24")
        let result = try judgeUnweighed(new, before: squatDays(3))
        XCTAssertEqual(result.outcome, .personalBest)
        XCTAssertTrue(result.isReturn)
    }
}

/// 回來但還沒記：畫面那句「都還在」要不要出現。今天固定 2026-03-11，往前 21 天是 2026-02-18。
final class ReturnDueTests: XCTestCase {
    private func digest(_ dates: [String]) throws -> Digest {
        try Digest(
            measurements: [], lifts: dates.map { lift(.squat, kg: 60, on: $0) }, heightCm: heightCm,
            sex: .male, today: "2026-03-11"
        )
    }

    func test離最晚那筆剛好21天是真的累計天數還在() throws {
        let result = try digest(["2026-02-18", "2026-02-10"])
        XCTAssertTrue(result.isReturnDue)
        XCTAssertEqual(result.trainDays, 2)
        XCTAssertEqual(result.weekCount, 0)
    }

    func test回來還沒練宗門小卡寫天數都還在() throws {
        let result = try digest(["2026-02-18", "2026-02-10"])
        XCTAssertEqual(result.sectLineText, "2 天修煉都還在")
        XCTAssertEqual(result.sectLineSpoken, "2 天修煉都還在")
    }

    func test今天練了宗門小卡換回下一步() throws {
        // 累計 2 天，外門要 8 天
        let result = try digest(["2026-02-18", "2026-03-11"])
        XCTAssertEqual(result.sectLineText, "再 6 天升外門")
        XCTAssertEqual(result.sectLineSpoken, result.sect.next)
    }

    func test離最晚那筆20天是假的() throws {
        XCTAssertFalse(try digest(["2026-02-19"]).isReturnDue)
    }

    func test今天記了就變回假的() throws {
        XCTAssertFalse(try digest(["2026-01-01", "2026-03-11"]).isReturnDue)
    }

    func test一筆都沒記過是假的() throws {
        XCTAssertFalse(try digest([]).isReturnDue)
    }
}
