import Foundation

// 從健康 app 重建量測（片 E4）。這裡只做純計算，不碰 HealthKit：app 那邊把樣本換成
// HealthSample 丟進來，這裡整理成一天一筆的量測，再跟已經有的量測比，回要新增哪幾筆。
// 規則（.vibe/切片帳本.md 組塊 E）：
//   1. 超出範圍的樣本先丟掉並計數。範圍跟表單同一組（Tables）。
//   2. 同一天同一種有好幾筆，取量的時間最晚的那筆；時間一樣取 key 字串比較大的，結果才固定。
//   3. 那一天要同時有體重與體脂率才成一筆；去脂體重有就帶，沒有就空著，不拿別天的來湊。
//   4. 已經有同一天的量測（手打、匯入、之前帶入的都算）就不動它。
//   5. 體重樣本的 key 當這筆量測的 id；id 已經在既有量測裡的也不再新增
//      （換了時區，同一筆樣本會落在隔壁那一天）。

/// 健康 app 的樣本是哪一種。
public enum HealthSampleKind: String, CaseIterable {
    case weight
    case bodyFat
    case leanMass
}

/// 健康 app 的一筆樣本，單位已經換成跟量測一樣。
public struct HealthSample: Equatable {
    public let kind: HealthSampleKind
    /// 量的那一天（yyyy-MM-dd，手機的時區）。
    public let date: String
    /// 體重與去脂體重是公斤；體脂率是百分比（18 代表 18%，不是 0.18）。
    public let value: Double
    /// 量的時間（毫秒）。
    public let takenAtMs: Int
    /// 健康 app 給這筆樣本的 UUID。
    public let key: String

    public init(kind: HealthSampleKind, date: String, value: Double, takenAtMs: Int, key: String) {
        self.kind = kind
        self.date = date
        self.value = value
        self.takenAtMs = takenAtMs
        self.key = key
    }
}

/// 整理完的結果。三個計數給畫面講「帶進來幾筆、略過幾筆」用。
public struct HealthImportResult: Equatable {
    /// 健康 app 裡湊得成一筆的每一天，照日期由舊到新。
    public let candidates: [MeasurementEntry]
    /// candidates 裡還沒有的、要新增的那幾筆。
    public let additions: [MeasurementEntry]
    /// 數值超出範圍被丟掉的樣本數。
    public let outOfRangeSamples: Int
    /// 有樣本但湊不成一筆的天數（少了體重或體脂率）。
    public let incompleteDays: Int
    /// 已經有量測所以沒動的天數。
    public let alreadyRecordedDays: Int
}

public enum HealthImport {
    /// 把樣本整理成量測，再跟既有的量測比。日期字串壞掉丟 RencanError.invalidDate。
    public static func merge(
        samples: [HealthSample], existing: [MeasurementEntry]
    ) throws -> HealthImportResult {
        for sample in samples {
            _ = try Formulas.dayNumber(of: sample.date)
        }
        let valid = samples.filter { range(of: $0.kind).contains($0.value) }
        let days = latestByDay(valid)
        let candidates = entries(from: days)
        let takenDates = Set(existing.map(\.date))
        let takenIDs = Set(existing.map(\.id))
        let additions = candidates.filter {
            !takenDates.contains($0.date) && !takenIDs.contains($0.id)
        }
        return HealthImportResult(
            candidates: candidates, additions: additions,
            outOfRangeSamples: samples.count - valid.count,
            incompleteDays: days.count - candidates.count,
            alreadyRecordedDays: candidates.count - additions.count
        )
    }

    /// 健康 app 的體脂率是 0 到 1 的比例，換成百分比。四捨五入到小數第 4 位：
    /// 0.07 直接乘 100 會變成 7.000000000000001，剛好在體脂門檻上的人會被算成超過。
    public static func percent(fromFraction fraction: Double) -> Double {
        (fraction * percentPerUnit * percentRoundingScale).rounded() / percentRoundingScale
    }

    /// 百分比換回健康 app 用的比例（寫回去的時候用）。
    public static func fraction(fromPercent percent: Double) -> Double {
        percent / percentPerUnit
    }

    private static let percentPerUnit: Double = 100
    private static let percentRoundingScale: Double = 10_000

    private static func range(of kind: HealthSampleKind) -> ClosedRange<Double> {
        switch kind {
        case .weight:
            return Tables.weightRangeKg
        case .bodyFat:
            return Tables.bodyFatRangePercent
        case .leanMass:
            return Tables.leanMassRangeKg
        }
    }

    /// 每一天、每一種各留最晚的那一筆。
    private static func latestByDay(
        _ samples: [HealthSample]
    ) -> [String: [HealthSampleKind: HealthSample]] {
        var days: [String: [HealthSampleKind: HealthSample]] = [:]
        for sample in samples {
            if let current = days[sample.date]?[sample.kind], !isLater(sample, than: current) {
                continue
            }
            days[sample.date, default: [:]][sample.kind] = sample
        }
        return days
    }

    private static func isLater(_ sample: HealthSample, than other: HealthSample) -> Bool {
        if sample.takenAtMs != other.takenAtMs { return sample.takenAtMs > other.takenAtMs }
        return sample.key > other.key
    }

    /// 同一天有體重也有體脂率的才成一筆，照日期由舊到新。
    private static func entries(
        from days: [String: [HealthSampleKind: HealthSample]]
    ) -> [MeasurementEntry] {
        var result: [MeasurementEntry] = []
        for date in days.keys.sorted() {
            guard let weight = days[date]?[.weight], let bodyFat = days[date]?[.bodyFat] else {
                continue
            }
            result.append(
                MeasurementEntry(
                    id: weight.key, date: date, weightKg: weight.value,
                    bodyFatPercent: bodyFat.value, leanMassKg: days[date]?[.leanMass]?.value,
                    createdAtMs: weight.takenAtMs
                )
            )
        }
        return result
    }
}
