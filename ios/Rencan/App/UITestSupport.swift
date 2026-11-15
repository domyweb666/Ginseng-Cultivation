import Foundation
import RencanCore
import SwiftData

/// UI 測試用的啟動參數（ios/RencanUITests）。只在 Debug 版有作用；Release 版（TestFlight、上架）
/// 這些參數一律當作沒看到，不會有人用啟動參數清掉真實資料。
///   -rencanUITest          用記憶體裡的資料庫，不碰健康 app、不排通知
///   -rencanSeed profile    預先填好身高 174、男
///   -rencanSeed demo       另外塞幾筆量測與修煉，畫面有東西可以截圖
///   -rencanSeed female     身高 160、女，加一筆量測
@MainActor
enum UITestSupport {
    static var isUITest: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.arguments.contains("-rencanUITest")
        #else
            return false
        #endif
    }

    static func seedIfAsked(_ services: AppServices) throws {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard isUITest, let index = arguments.firstIndex(of: "-rencanSeed"),
                arguments.indices.contains(index + 1)
            else { return }
            try seed(arguments[index + 1], into: services)
        #endif
    }

    #if DEBUG
        private static func seed(_ name: String, into services: AppServices) throws {
            let context = services.container.mainContext
            switch name {
            case "profile":
                try services.store.saveProfile(heightCm: 174, sex: .male)
            case "female":
                try services.store.saveProfile(heightCm: 160, sex: .female)
                context.insert(measurement(60, 23, daysAgo: 3, lean: 46))
            case "demo":
                try services.store.saveProfile(heightCm: 174, sex: .male)
                context.insert(measurement(71, 18, daysAgo: 70, lean: nil))
                context.insert(measurement(70.8, 16, daysAgo: 40, lean: nil))
                context.insert(measurement(70.4, 14.2, daysAgo: 9, lean: nil))
                for record in demoLifts() {
                    context.insert(record)
                }
            default:
                return
            }
            try context.save()
        }

        private static func measurement(
            _ kg: Double, _ bodyFat: Double, daysAgo: Int, lean: Double?
        ) -> Measurement {
            Measurement(
                day: DayStamp.day(offsetFromToday: -daysAgo), weightKg: kg,
                bodyFatPercent: bodyFat, leanMassKg: lean, source: .manual
            )
        }

        /// 九天、四門功法，重量慢慢加；最後兩筆在今天。
        private static func demoLifts() -> [LiftRecord] {
            var records: [LiftRecord] = []
            func add(_ move: MoveKey, _ kg: Double, daysAgo: Int) {
                let record = LiftRecord(
                    day: DayStamp.day(offsetFromToday: -daysAgo), move: move, kg: kg, reps: 5,
                    sets: 3, bodyweightKg: nil, source: .manual,
                    createdAt: Date(timeIntervalSinceNow: Double(records.count - 100))
                )
                records.append(record)
            }
            add(.squat, 80, daysAgo: 30)
            add(.bench, 55, daysAgo: 30)
            add(.squat, 85, daysAgo: 24)
            add(.dead, 110, daysAgo: 24)
            add(.bench, 57.5, daysAgo: 18)
            add(.pull, 0, daysAgo: 18)
            add(.squat, 90, daysAgo: 12)
            add(.dead, 120, daysAgo: 8)
            add(.bench, 60, daysAgo: 6)
            add(.pull, 5, daysAgo: 4)
            add(.squat, 95, daysAgo: 2)
            add(.squat, 100, daysAgo: 0)
            add(.bench, 62.5, daysAgo: 0)
            return records
        }
    #endif
}
