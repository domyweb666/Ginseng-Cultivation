import Foundation

// 網頁版 index.html L231–331 的公式，一行對一行搬過來，數字不改（PRD 第 3 節）。
// 函式名跟網頁版同名（.vibe/架構藍圖.md 第五節），參數與欄位改成完整名：
//   R.i → realmIndex、R.s → stageIndex、R.nextF → nextFFMI、R.fromF → fromFFMI、
//   idx → stageRank、sectOf 的 ri → rankIndex、pct → progressPercent、
//   liftCalc 的 e → estimatedOneRepMaxKg、bw → bodyweightKg、l → lift。
// 跟網頁版不一樣的只有這幾處：
//   1. 身高不再預設 174，一律由呼叫端傳進來。
//   2. 沒有任何體重可用時 liftCalc 回 nil，不再用 65 公斤硬算（產品定稿砍掉的預設值）。
//   3. 「今天」由呼叫端傳日期字串進來，規則引擎不看時鐘，測試才不會隔天就變。
//   4. 日期字串壞掉時丟 RencanError.invalidDate（網頁版會算出 NaN）。
//   5. bestByMove 的 excludeId 參數網頁版沒人用，不搬。
//   6. sectOf 把境界序號夾在 -1 到 6 之間，離譜的輸入不會查表查出界（網頁版沒夾）。
//   7. 跟性別有關的函式都要傳 sex（片 B5，.vibe/女性版規則.md）；男性的算法跟網頁版一樣。
//      不帶 sex 的版本在 WebParity.swift，只給測試對網頁版用。
//   8. 宗門六階的境界門檻比網頁版各降一階（2026-11-17 多米定的，只改 app），
//      所以 sectOf 的結果跟網頁版不一樣；客卿、執事的規則照舊。細節在 Sect.swift 檔頭。
//   9. 境界看最近三次的平均、只升不降（2026-11-25 多米定），所以 breakthroughs、realmMax
//      跟網頁版不一樣。細節在 RealmAverage.swift 檔頭。

/// realmOf 的結果：在哪個大境界、哪一期、下一期與這一期的 FFMI 門檻。
public struct RealmStanding: Equatable {
    public let realmIndex: Int
    public let stageIndex: Int
    /// 下一期的 FFMI 門檻；已是渡劫後期時為 nil。
    public let nextFFMI: Double?
    /// 這一期的起點 FFMI，進度條從這裡算。
    public let fromFFMI: Double

    public var realm: Realm { Tables.realms[realmIndex] }
    /// 境界加期別，例如「金丹中期」。
    public var label: String { realm.name + Tables.stages[stageIndex] }
    /// 期別序號（大境界序號 × 3 + 期別），突破紀錄用它比高低。
    public var stageRank: Int { realmIndex * Tables.stages.count + stageIndex }
}

/// 距下一期還差多少肌肉（網頁版境界碑那一行）。
public struct StageGap: Equatable {
    public let nextLabel: String
    public let leanNeededKg: Double
}

/// 突破紀錄的一筆：第一次到達某一期。
public struct Breakthrough: Equatable {
    public let date: String
    public let stageRank: Int
    public let label: String
    /// 是不是入道起點（第一筆）。
    public let isFirst: Bool
    /// 距上一階幾天；第一筆是 0。
    public let daysSincePrevious: Int
    /// 那次最近三次平均的 FFMI（女性不換算）。
    public let ffmi: Double
}

/// 一筆修煉算出來的結果。
public struct LiftCalc: Equatable {
    public let move: Move
    public let estimatedOneRepMaxKg: Double
    /// 估計 1RM ÷ 當天體重。
    public let ratio: Double
    public let bodyweightKg: Double
    public let lift: LiftEntry
}

public enum Formulas {
    // MARK: 境界

    public static func ffmi(leanMassKg: Double, heightCm: Double) -> Double {
        let heightMeters = heightCm / 100
        return leanMassKg / (heightMeters * heightMeters) + heightCorrection(heightMeters)
    }

    /// ffmi 的反函式：要到某個 FFMI，去脂體重要幾公斤。
    public static func leanFor(ffmi: Double, heightCm: Double) -> Double {
        let heightMeters = heightCm / 100
        return (ffmi - heightCorrection(heightMeters)) * heightMeters * heightMeters
    }

    /// 身高校正項：6.3 ×（1.8 − 身高公尺）。
    private static func heightCorrection(_ heightMeters: Double) -> Double {
        Tables.ffmiHeightCorrectionPerMeter * (Tables.ffmiReferenceHeightMeters - heightMeters)
    }

    /// 去脂體重：體脂秤有給就用，沒有就用體重與體脂率算。
    public static func leanOf(_ measurement: MeasurementEntry) -> Double {
        if let leanMassKg = measurement.leanMassKg, leanMassKg != 0 { return leanMassKg }
        return measurement.weightKg * (1 - measurement.bodyFatPercent / 100)
    }

    /// 查境界。女性先把 FFMI 換成男性等值再查同一張表，回傳的門檻再換回她自己的 FFMI；
    /// 男性原樣不動（.vibe/女性版規則.md 第一節）。
    public static func realmOf(ffmi: Double, sex: Sex) -> RealmStanding {
        let equivalent = sex.maleEquivalentFFMI(ffmi)
        let lastRealmIndex = Tables.realms.count - 1
        let lastStageIndex = Tables.stages.count - 1
        let realmIndex = Tables.realms.firstIndex { equivalent < $0.upperFFMI } ?? lastRealmIndex
        let lower = Tables.realms[realmIndex].lowerFFMI
        // 先在浮點數裡夾住再轉整數，離譜的輸入才不會讓 Int 轉換當掉。
        let rawStage = ((equivalent - lower) / Tables.stageWidthFFMI).rounded(.down)
        let stageIndex = Int(max(0, min(Double(lastStageIndex), rawStage)))
        let nextEquivalent: Double?
        if equivalent < lower {
            nextEquivalent = lower
        } else if realmIndex == lastRealmIndex && stageIndex == lastStageIndex {
            nextEquivalent = nil
        } else {
            nextEquivalent = lower + Double(stageIndex + 1) * Tables.stageWidthFFMI
        }
        // 網頁版低於煉氣下限時 fromF 寫死 16.5；那時一定是煉氣初期，下限加 0 就是 16.5。
        let fromEquivalent = lower + Double(stageIndex) * Tables.stageWidthFFMI
        return RealmStanding(
            realmIndex: realmIndex, stageIndex: stageIndex,
            nextFFMI: nextEquivalent.map { sex.ownFFMI(fromMaleEquivalent: $0) },
            fromFFMI: sex.ownFFMI(fromMaleEquivalent: fromEquivalent)
        )
    }

    /// 距下一期還差多少肌肉；已是渡劫後期回 nil。
    /// 女性的下一期門檻已經在 realmOf 換回她自己的 FFMI，所以這裡的算法男女一樣。
    public static func nextStageGap(leanMassKg: Double, heightCm: Double, sex: Sex) -> StageGap? {
        let standing = realmOf(ffmi: ffmi(leanMassKg: leanMassKg, heightCm: heightCm), sex: sex)
        return nextStageGap(
            from: standing, leanMassKg: leanMassKg, heightCm: heightCm, sex: sex
        )
    }

    /// 從某一期算到它的下一期。境界不降，現在的去脂體重可能比 standing 那一期的起點還低。
    static func nextStageGap(
        from standing: RealmStanding, leanMassKg: Double, heightCm: Double, sex: Sex
    ) -> StageGap? {
        guard let nextFFMI = standing.nextFFMI else { return nil }
        // 網頁版用「門檻再多一點點」去查下一期叫什麼名字。
        let nextStanding = realmOf(ffmi: nextFFMI + nextStageProbe, sex: sex)
        let needed = leanFor(ffmi: nextFFMI, heightCm: heightCm) - leanMassKg
        return StageGap(nextLabel: nextStanding.label, leanNeededKg: max(0, needed))
    }

    /// 這一期走了百分之幾（網頁版境界碑的進度條，index.html L354）。最少畫 2，才看得到一點點。
    public static func stageProgressPercent(ffmi: Double, standing: RealmStanding) -> Double {
        guard let nextFFMI = standing.nextFFMI else { return fullStagePercent }
        let raw = (ffmi - standing.fromFFMI) / (nextFFMI - standing.fromFFMI) * fullStagePercent
        return max(minimumStagePercent, min(fullStagePercent, raw))
    }

    /// 體脂對根基的影響（網頁版 index.html L357–361）。男性：超過 20 不穩、18 到 20 浮動，
    /// 其他穩固。女性各加 7 個百分點。網頁版低於 10 的「偏低」沒找到可引用的出處，2026-11-23 拿掉。
    public static func bodyFatGate(bodyFatPercent: Double, sex: Sex) -> BodyFatGate {
        let limit = sex.bodyFatStableThresholdPercent
        if bodyFatPercent > limit { return .unstable(overBy: bodyFatPercent - limit) }
        if bodyFatPercent > limit - Tables.bodyFatWaveringBandPercent { return .wavering }
        return .stable
    }

    /// 突破紀錄：照日期排，只採計體脂在門檻以下的量測，最近三次的平均到達更高的期別就記一筆。
    public static func breakthroughs(
        measurements: [MeasurementEntry], heightCm: Double, sex: Sex
    ) throws -> [Breakthrough] {
        let stable = byDate(measurements).filter { isWithinBodyFatLimit($0, sex: sex) }
        var result: [Breakthrough] = []
        var highestRank = -1
        var previousDate: String?
        for (index, measurement) in stable.enumerated() {
            let average = try leanAverage(of: measurement, earlier: stable[..<index])
            let averageFFMI = ffmi(leanMassKg: average.leanMassKg, heightCm: heightCm)
            let standing = realmOf(ffmi: averageFFMI, sex: sex)
            guard standing.stageRank > highestRank else { continue }
            var daysSincePrevious = 0
            if let previousDate {
                daysSincePrevious = try daysBetween(previousDate, measurement.date)
            }
            result.append(
                Breakthrough(
                    date: measurement.date, stageRank: standing.stageRank, label: standing.label,
                    isFirst: highestRank < 0, daysSincePrevious: daysSincePrevious,
                    ffmi: averageFFMI
                )
            )
            highestRank = standing.stageRank
            previousDate = measurement.date
        }
        return result
    }

    /// 曾到達的最高大境界序號；還沒有任何穩固量測回 -1。
    public static func realmMax(
        measurements: [MeasurementEntry], heightCm: Double, sex: Sex
    ) throws -> Int {
        let all = try breakthroughs(measurements: measurements, heightCm: heightCm, sex: sex)
        guard let top = all.last else { return Tables.noRealmIndex }
        return top.stageRank / Tables.stages.count
    }

    // MARK: 功法

    /// Epley 估計 1RM。只做一下就是那個重量本身。
    public static func e1rm(loadKg: Double, reps: Int) -> Double {
        guard reps > 1 else { return loadKg }
        return loadKg * (1 + Double(reps) / Tables.epleyRepsDivisor)
    }

    /// 比值過了幾個門檻就是第幾階（0 是未入門）。男女的門檻不一樣。
    public static func moveLevel(move: Move, ratio: Double, sex: Sex) -> Int {
        var level = 0
        for (index, threshold) in move.thresholds(for: sex).enumerated() where ratio >= threshold {
            level = index + 1
        }
        return level
    }

    /// 功法雷達圖的分數：0 到 5，整數部分是等級，小數部分是往下一階走了幾成。
    /// 例：男性深蹲入門 0.75、小成 1.0，比值 0.875 是 1.5 分。未入門從 0 起算，化境封頂 5 分。
    /// 雷達圖只看等級會一格一格跳，加上小數才看得出「快到了」（2026-11-18 多米要的雷達圖）。
    public static func moveScore(move: Move, ratio: Double, sex: Sex) -> Double {
        let thresholds = move.thresholds(for: sex)
        guard ratio.isFinite, ratio > 0 else { return 0 }
        var lower = 0.0
        for (index, upper) in thresholds.enumerated() {
            if ratio < upper {
                return Double(index) + (ratio - lower) / (upper - lower)
            }
            lower = upper
        }
        return Double(thresholds.count)
    }

    /// 某一天的體重：那天（含）以前最近的一筆量測；都在那天之後就用最新的一筆。
    public static func bwAt(date: String, measurements: [MeasurementEntry]) -> Double? {
        let sorted = byDate(measurements)
        let onOrBefore = sorted.last { $0.date <= date }
        guard let chosen = onOrBefore ?? sorted.last, chosen.weightKg != 0 else { return nil }
        return chosen.weightKg
    }

    /// 一筆修煉的估計 1RM 與比值。沒有任何體重可用時回 nil（網頁版會用 65 公斤硬算）。
    public static func liftCalc(_ lift: LiftEntry, measurements: [MeasurementEntry]) -> LiftCalc? {
        guard let move = Tables.moves.first(where: { $0.key == lift.move }) else { return nil }
        var bodyweightKg = lift.bodyweightKg ?? 0
        if bodyweightKg == 0 {
            bodyweightKg = bwAt(date: lift.date, measurements: measurements) ?? 0
        }
        guard bodyweightKg != 0 else { return nil }
        let loadKg = move.usesBodyweight ? bodyweightKg + lift.kg : lift.kg
        let estimated = e1rm(loadKg: loadKg, reps: lift.reps)
        return LiftCalc(
            move: move, estimatedOneRepMaxKg: estimated, ratio: estimated / bodyweightKg,
            bodyweightKg: bodyweightKg, lift: lift
        )
    }

    /// 每門功法比值最高的那一筆。比值一樣時留先記的那筆（網頁版用嚴格大於）。
    public static func bestByMove(
        lifts: [LiftEntry], measurements: [MeasurementEntry]
    ) -> [MoveKey: LiftCalc] {
        var best: [MoveKey: LiftCalc] = [:]
        for lift in lifts {
            guard let calc = liftCalc(lift, measurements: measurements) else { continue }
            if let current = best[lift.move], !(calc.ratio > current.ratio) { continue }
            best[lift.move] = calc
        }
        return best
    }

    // MARK: 天數

    /// 累計修煉天數：有記錄的日子有幾天，同一天記幾筆都只算一天。
    public static func trainDays(lifts: [LiftEntry]) -> Int {
        Set(lifts.map(\.date)).count
    }

    /// 本週修煉天數：這週一（含）以後有記錄的日子有幾天。
    public static func weekCount(lifts: [LiftEntry], today: String) throws -> Int {
        try daysThisWeek(lifts.map(\.date), today: today).count
    }

    /// 這週一（含）以後有出現的日子，不重複、由早到晚。
    /// 小工具的快照只帶這幾個日期，過了一週它自己拿當天再算一次，天數才會歸零。
    public static func daysThisWeek(_ days: [String], today: String) throws -> [String] {
        let todayNumber = try dayNumber(of: today)
        // 餘數再加 7 取一次，1970 年以前的日期（負的天數）也算得對。
        let remainder = (todayNumber + epochToMondayShift) % daysPerWeek
        let mondayNumber = todayNumber - (remainder + daysPerWeek) % daysPerWeek
        var counted: Set<String> = []
        for day in days {
            let number = try dayNumber(of: day)
            if number >= mondayNumber { counted.insert(day) }
        }
        return counted.sorted()
    }

    public static func daysBetween(_ from: String, _ until: String) throws -> Int {
        try dayNumber(of: until) - dayNumber(of: from)
    }

    /// 天數寫成人話：不到 60 天寫天，不到一年寫月，其餘寫幾年幾個月。
    public static func durTxt(days: Int) -> String {
        if days < daysShownAsDaysBelow { return "\(days) 天" }
        if days < daysPerYear { return "\(roundedMonths(days)) 個月" }
        let years = days / daysPerYear
        let months = roundedMonths(days % daysPerYear)
        return months == 0 ? "\(years) 年" : "\(years) 年 \(months) 個月"
    }

    /// 數字寫成固定小數位（網頁版的 fmt，index.html L336）：先四捨五入（5 一律進位）再補零。
    public static func fmt(_ value: Double, digits: Int) -> String {
        let scale = pow(10, Double(digits))
        let rounded = (value * scale + 0.5).rounded(.down) / scale
        return String(format: "%.\(digits)f", rounded)
    }

    /// 照日期排序；同一天照建立時間。網頁版是把日期和時間接成一個字串來比。
    public static func byDate(_ measurements: [MeasurementEntry]) -> [MeasurementEntry] {
        let keys = measurements.map { $0.date + String($0.createdAtMs) }
        let order = measurements.indices.sorted { left, right in
            keys[left] == keys[right] ? left < right : keys[left] < keys[right]
        }
        return order.map { measurements[$0] }
    }
}

// MARK: 日期與常數

extension Formulas {
    private static let minimumStagePercent: Double = 2
    private static let fullStagePercent: Double = 100
    /// 查下一期叫什麼名字時，在門檻上多加的一點點。
    private static let nextStageProbe = 0.001
    private static let daysShownAsDaysBelow = 60
    private static let daysPerYear = 365
    private static let daysPerMonth: Double = 30
    private static let daysPerWeek = 7
    /// 1970-01-01 是星期四，加 3 之後除以 7 的餘數就是「離星期一幾天」。
    private static let epochToMondayShift = 3

    private static func roundedMonths(_ days: Int) -> Int {
        Int((Double(days) / daysPerMonth).rounded())
    }

    /// 「yyyy-MM-dd」換成從 1970-01-01 起算的天數。網頁版是 new Date(字串) 相減再除以一天；
    /// 這裡用純整數的曆法算法（Howard Hinnant 的 days_from_civil），不靠時區與 Calendar，
    /// Linux 與 iOS 算出來才會一樣。式子裡的數字是那個算法本身的常數。
    static func dayNumber(of date: String) throws -> Int {
        let parts = date.split(separator: "-", omittingEmptySubsequences: false)
        let lengths = [4, 2, 2]
        guard parts.count == lengths.count else { throw RencanError.invalidDate }
        var numbers: [Int] = []
        for (part, length) in zip(parts, lengths) {
            let isDigits = part.allSatisfy { $0.isASCII && $0.isNumber }
            guard part.count == length, isDigits, let number = Int(part) else {
                throw RencanError.invalidDate
            }
            numbers.append(number)
        }
        let year = numbers[0]
        let month = numbers[1]
        let day = numbers[2]
        guard (1...12).contains(month), (1...daysInMonth(month, year: year)).contains(day) else {
            throw RencanError.invalidDate
        }
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func daysInMonth(_ month: Int, year: Int) -> Int {
        let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let lengths = [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return lengths[month - 1]
    }
}
