import Foundation
import RencanCore
import SwiftData

/// 量時間用的大量資料（2026-11-26 性能審查）：-rencanSeed heavy。
/// 三年、3000 筆修煉（最舊的 500 筆沒帶體重快照）、200 筆量測，身高 174、男。
/// 跟規則引擎的 DigestPerformanceTests 同一個量級，模擬器上量開 app、回前景、切頁要多久。
@MainActor
enum UITestHeavySeed {
    static let liftCount = 3000
    static let liftsWithoutBodyweight = 500
    static let measurementCount = 200
    static let daySpan = 1095

    static func seed(into services: AppServices) throws {
        #if DEBUG
            let context = services.container.mainContext
            try services.store.saveProfile(heightCm: 174, sex: .male)
            for index in 0..<measurementCount {
                context.insert(measurement(index))
            }
            for index in 0..<liftCount {
                context.insert(lift(index))
            }
        #endif
    }

    #if DEBUG
        /// 第 index 筆落在幾天前：0 號最舊，最後一筆是今天。
        private static func daysAgo(_ index: Int, of count: Int) -> Int {
            daySpan - index * daySpan / max(count - 1, 1)
        }

        private static func measurement(_ index: Int) -> Measurement {
            let weight = 72 + Double(index % 5) / 2
            let bodyFat = 16 - Double(index % 4) / 2
            return Measurement(
                day: DayStamp.day(offsetFromToday: -daysAgo(index, of: measurementCount)),
                weightKg: weight, bodyFatPercent: bodyFat, leanMassKg: nil, source: .manual,
                createdAt: Date(timeIntervalSinceNow: Double(index - measurementCount))
            )
        }

        private static func lift(_ index: Int) -> LiftRecord {
            let moves = MoveKey.allCases
            let hasSnapshot = index >= liftsWithoutBodyweight
            return LiftRecord(
                day: DayStamp.day(offsetFromToday: -daysAgo(index, of: liftCount)),
                move: moves[index % moves.count], kg: 40 + Double(index % 60), reps: 5, sets: 3,
                bodyweightKg: hasSnapshot ? 72 : nil, source: .manual,
                createdAt: Date(timeIntervalSinceNow: Double(index - liftCount))
            )
        }
    #endif
}
