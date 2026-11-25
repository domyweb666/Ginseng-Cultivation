import Foundation

// 境界看最近三次量測的平均，而且只升不降（2026-11-25 多米定，依據在 .vibe/研究對照-2026-11-25.md）。
// 一期只有約 1.5 公斤去脂體重，體脂秤每次就差半公斤上下，看單次會亂升亂掉。
// 規則：
//   1. 平均的是去脂體重：這次加上往回 90 天內最近的兩次。只有一次就是那一次，第一次量照樣有境界。
//   2. 體脂門檻照舊看這次的體脂率，不平均：降到門檻以下那次就生效（產品定稿）。
//   3. 門檻以內的只跟門檻以內的平均，超過的只跟超過的平均，突破才不會被體脂高的那幾次灌水。
//   4. 畫面上的境界是突破紀錄裡最高的那一期；還沒有任何突破就是現在的平均。
// 網頁版看單次、取最新一筆，所以突破紀錄與最高境界從這天起跟網頁版不一樣。
// 從 Formulas.swift 拆出來只因為 SwiftLint 一個檔最多 400 行；它仍是 Formulas 的一部分。

/// 最近幾次量測平均起來的去脂體重。
public struct LeanAverage: Equatable {
    /// 平均了幾次，1 到 3。
    public let count: Int
    public let leanMassKg: Double
}

extension Formulas {
    /// measurement 那一次的平均。all 可以不照日期排，含不含 measurement 自己都行。
    public static func leanAverage(
        of measurement: MeasurementEntry, among all: [MeasurementEntry], sex: Sex
    ) throws -> LeanAverage {
        let isStable = isWithinBodyFatLimit(measurement, sex: sex)
        let sameSide = byDate(all).filter { isWithinBodyFatLimit($0, sex: sex) == isStable }
        return try leanAverage(of: measurement, earlier: sameSide[...])
    }

    /// earlier 要照日期排好，而且跟 measurement 在體脂門檻的同一邊；同一天與之後的不會採計。
    static func leanAverage(
        of measurement: MeasurementEntry, earlier: ArraySlice<MeasurementEntry>
    ) throws -> LeanAverage {
        var picked = [measurement]
        var nearestDate = measurement.date
        for candidate in earlier.reversed() {
            guard picked.count < Tables.realmAverageCount else { break }
            guard candidate.date < nearestDate else { continue }
            let days = try daysBetween(candidate.date, measurement.date)
            guard days <= Tables.realmAverageWindowDays else { break }
            picked.append(candidate)
            nearestDate = candidate.date
        }
        let total = picked.map(leanOf).reduce(0, +)
        return LeanAverage(count: picked.count, leanMassKg: total / Double(picked.count))
    }

    /// 體脂率在門檻以內（剛好等於也算）。
    static func isWithinBodyFatLimit(_ measurement: MeasurementEntry, sex: Sex) -> Bool {
        measurement.bodyFatPercent <= sex.bodyFatStableThresholdPercent
    }

    /// 畫面上的境界：最高的那次突破；還沒有任何突破就照現在的平均查。
    static func shownStanding(
        top: Breakthrough?, averageFFMI: Double, sex: Sex
    ) -> RealmStanding {
        realmOf(ffmi: top?.ffmi ?? averageFFMI, sex: sex)
    }
}
