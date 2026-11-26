import Foundation

// 查某一天的體重時，量測只排一次（2026-11-26 性能審查）。
// 原本 bwAt 每查一次就用 byDate 把全部量測重排，Digest 對沒帶體重快照的修煉每筆都查，
// 3000 筆修煉就要排 3000 次。改成先建一份 MeasurementsByDate，之後每次查用二分搜尋。
// 結果跟 bwAt(date:measurements:) 一模一樣，理由：
//   1. entries 就是 byDate 的結果，跟舊版每次排出來的是同一個陣列，連同一天多筆的先後都一樣。
//   2. byDate 的排序鍵是「日期字串接建立時間」。日期都是 yyyy-MM-dd（一樣長）時，
//      鍵的前十個字就是日期，排好的陣列日期一定由早到晚，「日期 <= 那天」成立的是開頭一段。
//      二分搜尋找這段的最後一筆，就是舊版 last { $0.date <= date } 找到的同一筆。
//   3. 有壞掉的日期（長短不一，例如一個日期是另一個的開頭）時，排好的不保證照日期，
//      isDateAscending 是 false，退回跟舊版一樣從後面逐筆找。
// 從 Formulas.swift 拆出來只因為 SwiftLint 一個檔最多 400 行；它仍是 Formulas 的一部分。

/// 照 byDate 排好的量測。排一次，查很多天的體重。
struct MeasurementsByDate: Equatable {
    /// Formulas.byDate 排好的全部量測。
    let entries: [MeasurementEntry]
    /// 排好的日期是不是由早到晚，是才能二分搜尋。
    let isDateAscending: Bool

    init(_ measurements: [MeasurementEntry]) {
        let sorted = Formulas.byDate(measurements)
        entries = sorted
        isDateAscending = zip(sorted, sorted.dropFirst()).allSatisfy { pair in
            pair.0.date <= pair.1.date
        }
    }

    /// 那天（含）以前排在最後的一筆，同一天多筆就是 byDate 排在最後的那筆。都在那天之後回 nil。
    func latest(onOrBefore date: String) -> MeasurementEntry? {
        guard isDateAscending else { return entries.last { $0.date <= date } }
        // 找完 low 是第一個日期晚於那天的位置，它前一筆就是答案。
        var low = 0
        var high = entries.count
        while low < high {
            let middle = low + (high - low) / 2
            if entries[middle].date <= date {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low > 0 ? entries[low - 1] : nil
    }
}

extension Formulas {
    /// bwAt(date:measurements:) 的排好版：那天（含）以前最近的一筆；都在那天之後就用最新的一筆。
    static func bwAt(date: String, byDate measurements: MeasurementsByDate) -> Double? {
        let onOrBefore = measurements.latest(onOrBefore: date)
        guard let chosen = onOrBefore ?? measurements.entries.last, chosen.weightKg != 0 else {
            return nil
        }
        return chosen.weightKg
    }

    /// liftCalc(_:measurements:) 的排好版，算法同一段。
    static func liftCalc(_ lift: LiftEntry, byDate measurements: MeasurementsByDate) -> LiftCalc? {
        liftCalc(lift, bodyweightOnDay: { bwAt(date: lift.date, byDate: measurements) })
    }
}
