import Foundation

// 跟網頁版一樣「只有男性」的版本。只給測試用，所以不是 public，app 看不到：
// 黃金集與片 B1–B3 的測試要拿它們對網頁版 index.html 的答案，網頁版從來沒有性別。
// app 一律呼叫帶 sex 的版本；沒選性別不准算，也不准預設成男（.vibe/女性版規則.md）。

extension Formulas {
    static func realmOf(ffmi: Double) -> RealmStanding {
        realmOf(ffmi: ffmi, sex: .male)
    }

    static func nextStageGap(leanMassKg: Double, heightCm: Double) -> StageGap? {
        nextStageGap(leanMassKg: leanMassKg, heightCm: heightCm, sex: .male)
    }

    static func breakthroughs(
        measurements: [MeasurementEntry], heightCm: Double
    ) throws -> [Breakthrough] {
        try breakthroughs(measurements: measurements, heightCm: heightCm, sex: .male)
    }

    static func realmMax(measurements: [MeasurementEntry], heightCm: Double) throws -> Int {
        try realmMax(measurements: measurements, heightCm: heightCm, sex: .male)
    }

    static func moveLevel(move: Move, ratio: Double) -> Int {
        moveLevel(move: move, ratio: ratio, sex: .male)
    }
}

extension Judgement {
    static func liftOutcome(
        new lift: LiftEntry, before lifts: [LiftEntry], measurements: [MeasurementEntry],
        heightCm: Double
    ) throws -> LiftJudgement {
        try liftOutcome(
            new: lift, before: lifts, measurements: measurements, heightCm: heightCm, sex: .male
        )
    }

    static func measurementOutcome(
        new measurement: MeasurementEntry, before measurements: [MeasurementEntry],
        lifts: [LiftEntry], heightCm: Double
    ) throws -> MeasurementJudgement {
        try measurementOutcome(
            new: measurement, before: measurements, lifts: lifts, heightCm: heightCm, sex: .male
        )
    }
}
