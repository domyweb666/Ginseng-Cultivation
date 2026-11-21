import Foundation

// 畫面要顯示的東西，一次算好（組塊 C、D）。
// 境界頁、分析頁、小工具、Siri 都拿同一份 Digest，畫面只負責排版，不自己算（規矩檔第 1 節）。
// 數字的算法都在 Formulas；這裡只是把它們照畫面的需要組起來。
// 下一階還差幾公斤的寫法照 2026-11-15 的設計畫布（LogSheet、AnalysisGong）：
//   1RM 再加 max(1, 無條件進位(下一階門檻 × 體重 − 估計 1RM)) 公斤。

/// 體脂對根基的影響。門檻男女不同（女性各加 7 個百分點，.vibe/女性版規則.md 第二節的推法）。
public enum BodyFatGate: Equatable {
    /// 根基穩固。
    case stable
    /// 根基浮動：還沒超過門檻，但已經在門檻下面 2 個百分點以內。
    case wavering
    /// 體脂偏低，提醒留意恢復與飲食。
    case low
    /// 根基不穩：超過門檻。帶「還差幾個百分點才回到門檻」。
    case unstable(overBy: Double)
}

/// 境界碑要顯示的全部數字。
public struct SteleDigest: Equatable {
    public let measurement: MeasurementEntry
    public let leanMassKg: Double
    /// 使用者真實的 FFMI（女性不換算）。
    public let ffmi: Double
    public let standing: RealmStanding
    public let gate: BodyFatGate
    /// 距下一期還差多少肌肉；已是渡劫後期為 nil。
    public let gap: StageGap?
    /// 這一期走了百分之幾（0–100）。
    public let stagePercent: Double

    public var isStable: Bool {
        if case .unstable = gate { return false }
        return true
    }
}

/// 分析頁功法段的一張卡。
public struct MoveCard: Equatable {
    public let move: Move
    /// 比值最高的那一筆；沒有紀錄或沒有體重可算時為 nil。
    public let best: LiftCalc?
    /// 這門功法有沒有任何紀錄（有紀錄但 best 是 nil，代表還沒量過體重）。
    public let hasRecords: Bool
    public let level: Int
    /// 下一階再加幾公斤的估計 1RM；已到化境或沒有紀錄為 nil。
    public let kgToNextLevel: Int?
    /// 每一筆的估計 1RM，照日期排，畫走勢線用。
    public let history: [Double]
    /// 雷達圖的分數，0 到 5（Formulas.moveScore）；沒有紀錄或沒有體重可算是 0。
    public let score: Double

    public var levelName: String { Tables.levelNames[level] }
    public var nextLevelName: String? {
        level + 1 < Tables.levelNames.count ? Tables.levelNames[level + 1] : nil
    }
}

/// 記一筆表單底下的即時預覽。
public struct LiftPreview: Equatable {
    public let estimatedOneRepMaxKg: Double
    public let ratio: Double
    public let level: Int
    public let kgToNextLevel: Int?

    public var levelName: String { Tables.levelNames[level] }
    public var nextLevelName: String? {
        level + 1 < Tables.levelNames.count ? Tables.levelNames[level + 1] : nil
    }
}

/// FFMI 走勢圖上的一點。
public struct FFMIPoint: Equatable {
    public let date: String
    public let ffmi: Double
    /// 距第一次量測幾天（第一次是 0）。走勢圖的橫軸照它排，隔一週和隔三個月寬度才不一樣。
    public let dayOffset: Int
}

public struct Digest: Equatable {
    public let today: String
    public let measurements: [MeasurementEntry]
    public let lifts: [LiftEntry]
    public let heightCm: Double?
    public let sex: Sex?

    public let trainDays: Int
    public let weekCount: Int
    public let monthCount: Int
    public let sect: SectStatus
    /// 還沒量過，或還沒填身高、選性別時為 nil。
    public let stele: SteleDigest?
    public let breakthroughs: [Breakthrough]
    public let ffmiHistory: [FFMIPoint]
    public let moveCards: [MoveCard]

    /// 練到大成以上的功法有幾門。
    public var accomplishedCount: Int {
        moveCards.filter { $0.level >= Digest.accomplishedLevel }.count
    }

    /// 日期壞掉時丟 RencanError.invalidDate，畫面要顯示錯誤，不能整頁空白。
    public init(
        measurements: [MeasurementEntry], lifts: [LiftEntry], heightCm: Double?, sex: Sex?,
        today: String
    ) throws {
        self.today = today
        self.measurements = measurements
        self.lifts = lifts
        self.heightCm = heightCm
        self.sex = sex
        let days = Formulas.trainDays(lifts: lifts)
        trainDays = days
        weekCount = try Formulas.weekCount(lifts: lifts, today: today)
        monthCount = Digest.monthCount(lifts: lifts, today: today)
        var realmIndex = Tables.noRealmIndex
        var records: [Breakthrough] = []
        var points: [FFMIPoint] = []
        var latest: SteleDigest?
        if let heightCm, let sex {
            records = try Formulas.breakthroughs(
                measurements: measurements, heightCm: heightCm, sex: sex
            )
            if let top = records.last {
                realmIndex = top.stageRank / Tables.stages.count
            }
            let sorted = Formulas.byDate(measurements)
            if let earliest = sorted.first {
                points = try sorted.map { measurement in
                    try Digest.point(of: measurement, heightCm: heightCm, since: earliest.date)
                }
            }
            latest = sorted.last.map { Digest.stele(of: $0, heightCm: heightCm, sex: sex) }
        }
        breakthroughs = records
        ffmiHistory = points
        stele = latest
        sect = Formulas.sectOf(trainDays: days, realmIndex: realmIndex)
        moveCards = Tables.moves.map { move in
            Digest.card(of: move, lifts: lifts, measurements: measurements, sex: sex)
        }
    }

    /// 某一筆修煉自己算出來的等級；沒有體重或沒選性別時為 nil。
    public func level(of lift: LiftEntry) -> Int? {
        guard let sex, let calc = Formulas.liftCalc(lift, measurements: measurements) else {
            return nil
        }
        return Formulas.moveLevel(move: calc.move, ratio: calc.ratio, sex: sex)
    }

    /// 某一天能用的體重（記一筆表單用它做預覽與體重快照）。
    public func bodyweight(on date: String) -> Double? {
        Formulas.bwAt(date: date, measurements: measurements)
    }

    /// 記一筆表單的即時預覽。沒有體重時回 nil，表單改顯示「先量一次體重」。
    public static func preview(
        move: Move, kg: Double, reps: Int, bodyweightKg: Double, sex: Sex
    ) -> LiftPreview? {
        guard bodyweightKg > 0 else { return nil }
        let loadKg = move.usesBodyweight ? bodyweightKg + kg : kg
        let estimated = Formulas.e1rm(loadKg: loadKg, reps: reps)
        let ratio = estimated / bodyweightKg
        let level = Formulas.moveLevel(move: move, ratio: ratio, sex: sex)
        let needed = kgToNextLevel(
            move: move, level: level, estimatedKg: estimated, bodyweightKg: bodyweightKg, sex: sex
        )
        return LiftPreview(
            estimatedOneRepMaxKg: estimated, ratio: ratio, level: level, kgToNextLevel: needed
        )
    }

    // MARK: 組裝

    /// 「大成」在 Tables.levelNames 裡的位置。
    private static let accomplishedLevel = 3
    private static let maximumKgToNext: Double = 9999
    private static let monthPrefixLength = 7

    /// 這個月有記錄的日子有幾天。日期字串的前七個字（yyyy-MM）一樣就是同一個月。
    static func monthCount(lifts: [LiftEntry], today: String) -> Int {
        let month = today.prefix(monthPrefixLength)
        return Set(lifts.map(\.date).filter { $0.prefix(monthPrefixLength) == month }).count
    }

    /// earliestDate 是第一次量測的日子；日期壞掉時 daysBetween 會丟 invalidDate。
    private static func point(
        of measurement: MeasurementEntry, heightCm: Double, since earliestDate: String
    ) throws -> FFMIPoint {
        let leanMassKg = Formulas.leanOf(measurement)
        let dayOffset = try Formulas.daysBetween(earliestDate, measurement.date)
        return FFMIPoint(
            date: measurement.date,
            ffmi: Formulas.ffmi(leanMassKg: leanMassKg, heightCm: heightCm),
            dayOffset: dayOffset
        )
    }

    static func stele(of measurement: MeasurementEntry, heightCm: Double, sex: Sex) -> SteleDigest {
        let leanMassKg = Formulas.leanOf(measurement)
        let ffmi = Formulas.ffmi(leanMassKg: leanMassKg, heightCm: heightCm)
        let standing = Formulas.realmOf(ffmi: ffmi, sex: sex)
        return SteleDigest(
            measurement: measurement, leanMassKg: leanMassKg, ffmi: ffmi, standing: standing,
            gate: Formulas.bodyFatGate(bodyFatPercent: measurement.bodyFatPercent, sex: sex),
            gap: Formulas.nextStageGap(leanMassKg: leanMassKg, heightCm: heightCm, sex: sex),
            stagePercent: Formulas.stageProgressPercent(ffmi: ffmi, standing: standing)
        )
    }

    private static func card(
        of move: Move, lifts: [LiftEntry], measurements: [MeasurementEntry], sex: Sex?
    ) -> MoveCard {
        let own = lifts.filter { $0.move == move.key }
        let calcs = own.compactMap { Formulas.liftCalc($0, measurements: measurements) }
        let ordered = calcs.sorted { left, right in
            (left.lift.date, left.lift.createdAtMs) < (right.lift.date, right.lift.createdAtMs)
        }
        var best: LiftCalc?
        for calc in calcs {
            if let current = best, !(calc.ratio > current.ratio) { continue }
            best = calc
        }
        var level = 0
        var needed: Int?
        var score = 0.0
        if let best, let sex {
            level = Formulas.moveLevel(move: move, ratio: best.ratio, sex: sex)
            score = Formulas.moveScore(move: move, ratio: best.ratio, sex: sex)
            needed = kgToNextLevel(
                move: move, level: level, estimatedKg: best.estimatedOneRepMaxKg,
                bodyweightKg: best.bodyweightKg, sex: sex
            )
        }
        return MoveCard(
            move: move, best: best, hasRecords: !own.isEmpty, level: level, kgToNextLevel: needed,
            history: ordered.map(\.estimatedOneRepMaxKg), score: score
        )
    }

    private static func kgToNextLevel(
        move: Move, level: Int, estimatedKg: Double, bodyweightKg: Double, sex: Sex
    ) -> Int? {
        let thresholds = move.thresholds(for: sex)
        guard level < thresholds.count else { return nil }
        let needed = (thresholds[level] * bodyweightKg - estimatedKg).rounded(.up)
        // 先在浮點數裡夾住再轉整數，離譜的重量才不會讓 Int 轉換當掉。
        return Int(max(1, min(needed, maximumKgToNext)))
    }
}
