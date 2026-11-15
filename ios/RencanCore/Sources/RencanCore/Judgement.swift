import Foundation

// 慶祝判定（片 B3）：記一筆修煉是五選一，量一次體組成是四選一。
// 規則照 .vibe/標準清單.md 的兩張「判定規則白話表」，由上往下第一個成立的就是答案。
// 底子是網頁版 index.html L520–569 的 onLift、onMeas；跟網頁版不一樣的三處：
//   1. 功法精進改看估計 1RM 有沒有比這門功法歷來最高的還高（網頁版看比值，減重也會放）。
//   2. 體脂超過門檻是獨立的一種結果「根基不穩」（網頁版只是換一句提示）。
//   3. 沒有任何體重可用時只判宗門晉升，其餘一律修煉 +1（網頁版用 65 公斤硬算）。
// 這裡只回答「這次是哪一種」和畫面要寫的數字，不碰畫面、震動、資料庫。

/// 記一筆修煉的五種結果。
public enum LiftOutcome: Equatable {
    /// 宗門晉升：這筆讓宗門身分變了。全螢幕煙火。
    case sectPromotion
    /// 開練：這門功法以前一筆都沒有。小提示。
    case firstRecord
    /// 功法突破：比值跨過下一階門檻。全螢幕煙火。
    case levelUp
    /// 功法精進：估計 1RM 比這門功法歷來最高的還高。全螢幕煙火。
    case personalBest
    /// 修煉 +1。小提示。
    case logged
}

public struct LiftJudgement: Equatable {
    public let outcome: LiftOutcome
    /// 這筆的估計 1RM 與比值；沒有任何體重可用時為 nil。
    public let calc: LiftCalc?
    /// 這筆算出來的等級（0 是未入門）；沒有體重時為 nil。
    public let level: Int?
    /// 這筆有沒有讓等級升一階。宗門晉升時畫面會順便提一句。
    public let isLevelUp: Bool
    /// 比歷來最高的估計 1RM 多幾公斤；沒有更高時為 nil。
    public let gainKg: Double?
    public let trainDaysAfter: Int
    public let sectAfter: SectStatus
}

/// 量一次體組成的四種結果（境界突破再分大小，所以有五個）。
public enum MeasurementOutcome: Equatable {
    /// 根基不穩：體脂超過門檻。照樣算出境界，不放煙火、不算突破、不動宗門。
    case unstable
    /// 踏入仙途：第一筆體脂在門檻以下的量測。全螢幕煙火。
    case enteredPath
    /// 境界突破：期別比歷來最高還高，而且不是補登。全螢幕煙火。
    case breakthrough
    /// 大境界突破：突破的同時跨進新的大境界。全螢幕煙火。
    case majorBreakthrough
    /// 結算：以上都不是，含補登過去日期。小提示。
    case settled
}

public struct MeasurementJudgement: Equatable {
    public let outcome: MeasurementOutcome
    public let ffmi: Double
    public let standing: RealmStanding
    /// 距上一階幾天；只有境界突破、大境界突破時有值。
    public let daysSincePrevious: Int?
    /// 宗門身分因為這筆升了的話是新的身分；只有放煙火的結果會帶。
    public let promotedSectTitle: String?
}

public enum Judgement {
    /// 比大小時的容許誤差，跟網頁版 onLift 的 1e-6 一樣。
    private static let epsilon = 1e-6

    /// 這筆修煉跟同一門功法以前的紀錄比起來怎麼樣。
    private struct MoveProgress {
        let calc: LiftCalc
        let level: Int
        let isFirst: Bool
        let isLevelUp: Bool
        let gainKg: Double?
    }

    /// 記一筆修煉是哪一種。lifts 是存這筆之前的全部修煉。
    public static func liftOutcome(
        new lift: LiftEntry, before lifts: [LiftEntry], measurements: [MeasurementEntry],
        heightCm: Double
    ) throws -> LiftJudgement {
        let daysBefore = Formulas.trainDays(lifts: lifts)
        let isNewDay = !lifts.contains { $0.date == lift.date }
        let daysAfter = isNewDay ? daysBefore + 1 : daysBefore
        let realmIndex = try Formulas.realmMax(measurements: measurements, heightCm: heightCm)
        let sectBefore = Formulas.sectOf(trainDays: daysBefore, realmIndex: realmIndex)
        let sectAfter = Formulas.sectOf(trainDays: daysAfter, realmIndex: realmIndex)
        let progress = moveProgress(new: lift, before: lifts, measurements: measurements)
        let outcome = pick(isSectChanged: sectAfter.title != sectBefore.title, progress: progress)
        return LiftJudgement(
            outcome: outcome, calc: progress?.calc, level: progress?.level,
            isLevelUp: progress?.isLevelUp ?? false, gainKg: progress?.gainKg,
            trainDaysAfter: daysAfter, sectAfter: sectAfter
        )
    }

    /// 白話表由上往下：宗門晉升、開練、功法突破、功法精進、修煉 +1。
    private static func pick(isSectChanged: Bool, progress: MoveProgress?) -> LiftOutcome {
        if isSectChanged { return .sectPromotion }
        // 從沒量過體重：等級與精進都算不出來，只算修煉 +1。
        guard let progress else { return .logged }
        if progress.isFirst { return .firstRecord }
        if progress.isLevelUp { return .levelUp }
        if progress.gainKg != nil { return .personalBest }
        return .logged
    }

    private static func moveProgress(
        new lift: LiftEntry, before lifts: [LiftEntry], measurements: [MeasurementEntry]
    ) -> MoveProgress? {
        guard let calc = Formulas.liftCalc(lift, measurements: measurements) else { return nil }
        let level = Formulas.moveLevel(move: calc.move, ratio: calc.ratio)
        let earlier = lifts.filter { $0.move == lift.move }.compactMap {
            Formulas.liftCalc($0, measurements: measurements)
        }
        let bestRatio = earlier.map(\.ratio).max()
        let bestOneRepMaxKg = earlier.map(\.estimatedOneRepMaxKg).max()
        guard let bestRatio, let bestOneRepMaxKg else {
            return MoveProgress(
                calc: calc, level: level, isFirst: true, isLevelUp: false, gainKg: nil
            )
        }
        // 功法突破看比值（減重跨過門檻也算），功法精進看 1RM 本身（減重不算）。
        let previousLevel = Formulas.moveLevel(move: calc.move, ratio: bestRatio)
        let gainKg = calc.estimatedOneRepMaxKg - bestOneRepMaxKg
        return MoveProgress(
            calc: calc, level: level, isFirst: false, isLevelUp: level > previousLevel,
            gainKg: gainKg > epsilon ? gainKg : nil
        )
    }

    /// 量一次體組成是哪一種。measurements 是存這筆之前的全部量測。
    public static func measurementOutcome(
        new measurement: MeasurementEntry, before measurements: [MeasurementEntry],
        lifts: [LiftEntry], heightCm: Double
    ) throws -> MeasurementJudgement {
        let leanMassKg = Formulas.leanOf(measurement)
        let ffmi = Formulas.ffmi(leanMassKg: leanMassKg, heightCm: heightCm)
        let standing = Formulas.realmOf(ffmi: ffmi)
        func judged(
            _ outcome: MeasurementOutcome, days: Int? = nil, promoted: String? = nil
        ) -> MeasurementJudgement {
            MeasurementJudgement(
                outcome: outcome, ffmi: ffmi, standing: standing, daysSincePrevious: days,
                promotedSectTitle: promoted
            )
        }
        guard measurement.bodyFatPercent <= Tables.bodyFatStableThresholdPercent else {
            return judged(.unstable)
        }
        let history = try Formulas.breakthroughs(measurements: measurements, heightCm: heightCm)
        let realmBefore = history.last.map { $0.stageRank / Tables.stages.count }
        let promoted = promotedSectTitle(
            lifts: lifts, realmBefore: realmBefore ?? Tables.noRealmIndex,
            realmNow: standing.realmIndex
        )
        guard let top = history.last, let realmBefore else {
            return judged(.enteredPath, promoted: promoted)
        }
        // 日期早於上次突破那天就是補登，不放煙火。
        guard standing.stageRank > top.stageRank, measurement.date >= top.date else {
            return judged(.settled)
        }
        let days = try Formulas.daysBetween(top.date, measurement.date)
        let isMajor = standing.realmIndex > realmBefore
        return judged(isMajor ? .majorBreakthrough : .breakthrough, days: days, promoted: promoted)
    }

    /// 這筆量測讓最高境界變高、宗門身分跟著升的話，回新的身分。
    private static func promotedSectTitle(
        lifts: [LiftEntry], realmBefore: Int, realmNow: Int
    ) -> String? {
        let days = Formulas.trainDays(lifts: lifts)
        let before = Formulas.sectOf(trainDays: days, realmIndex: realmBefore)
        let after = Formulas.sectOf(trainDays: days, realmIndex: max(realmBefore, realmNow))
        return after.title == before.title ? nil : after.title
    }
}
