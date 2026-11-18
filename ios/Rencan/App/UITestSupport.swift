import Foundation
import RencanCore
import SwiftData

/// UI 測試用的啟動參數（ios/RencanUITests）。只在 Debug 版有作用；Release 版（TestFlight、上架）
/// 這些參數一律當作沒看到，不會有人用啟動參數清掉真實資料。
///   -rencanUITest          用記憶體裡的資料庫，不碰健康 app、不排通知
///   -rencanSeed profile    預先填好身高 174、男
///   -rencanSeed demo       另外塞幾筆量測與修煉，畫面有東西可以截圖
///   -rencanSeed female     身高 160、女，加一筆量測
///   -rencanSeed realm0     身高 174、男，一筆落在煉氣中段的量測；realm1 到 realm6 是築基到渡劫
///   -rencanSeed unstable   身高 174、男，金丹但體脂 24%（根基不穩）
///   -rencanPlayPortrait    境界碑的立繪照播動畫（測試模式預設不播）
///   -rencanHoldCelebration 全螢幕慶祝不自己關，等測試點掉（XCUITest 用；Limrun 走流程不帶）
///   -rencanOwn ink,celadon 假商店裡先算已經買了這幾種造型；all 是全套（PurchaseService）
///   -rencanStyle celadon   示範資料塞好後把立繪造型設成這一種（要搭配 -rencanOwn 才看得到）
@MainActor
enum UITestSupport {
    /// 假商店的價格字串。真的價格由 Apple 給，這兩個只出現在 UI 測試的截圖裡。
    static let testSinglePrice = "NT$120"
    static let testBundlePrice = "NT$480"

    /// -rencanOwn 後面那串造型代碼。測試模式以外一律是空的。
    static var ownedStyleCodes: [String] {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard isUITest, let index = arguments.firstIndex(of: "-rencanOwn"),
                arguments.indices.contains(index + 1)
            else { return [] }
            return arguments[index + 1].split(separator: ",").map(String.init)
        #else
            return []
        #endif
    }

    static var isUITest: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.arguments.contains("-rencanUITest")
        #else
            return false
        #endif
    }

    /// 慶祝畫面要不要等人點才關。XCUITest 每個動作前會等 app 閒下來，等得久的時候
    /// 4.5 秒的慶祝已經自己關了，測試就看不到（第三輪檢查線紅過一次，Limrun 實機上是正常的）。
    static var holdsCelebration: Bool {
        #if DEBUG
            return isUITest && ProcessInfo.processInfo.arguments.contains("-rencanHoldCelebration")
        #else
            return false
        #endif
    }

    /// 測試模式下境界碑的立繪不動：畫面一直在換格，XCUITest 每個動作前等 app 閒下來會等很久。
    /// 帶 -rencanPlayPortrait 的那一支測試例外，它專門隔幾秒截兩張圖比有沒有換格。
    static var holdsPortraitStill: Bool {
        #if DEBUG
            return isUITest && !ProcessInfo.processInfo.arguments.contains("-rencanPlayPortrait")
        #else
            return false
        #endif
    }

    static func seedIfAsked(_ services: AppServices) throws {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard isUITest, let index = arguments.firstIndex(of: "-rencanSeed") else { return }
            guard arguments.indices.contains(index + 1) else { return }
            try seed(arguments[index + 1], into: services)
            try applyStyleIfAsked(arguments, to: services)
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
            case "unstable":
                try services.store.saveProfile(heightCm: seedHeightCm, sex: .male)
                context.insert(realmMeasurement(realmIndex: 2, bodyFat: 24))
            default:
                guard name.hasPrefix(realmSeedPrefix),
                    let realmIndex = Int(name.dropFirst(realmSeedPrefix.count)),
                    Tables.realms.indices.contains(realmIndex)
                else { return }
                try services.store.saveProfile(heightCm: seedHeightCm, sex: .male)
                context.insert(realmMeasurement(realmIndex: realmIndex, bodyFat: 12))
            }
            try context.save()
        }

        /// -rencanStyle 帶的造型代碼認得就設上去；認不得照原版，不報錯（跟 UserSettings 一樣）。
        private static func applyStyleIfAsked(
            _ arguments: [String], to services: AppServices
        ) throws {
            guard let index = arguments.firstIndex(of: "-rencanStyle"),
                arguments.indices.contains(index + 1),
                let style = PortraitStyle(rawValue: arguments[index + 1])
            else { return }
            try services.store.setPortraitStyle(style)
        }

        private static let seedHeightCm: Double = 174
        private static let realmSeedPrefix = "realm"

        /// 剛好落在某一境中段的量測：FFMI 取那一境的下限加半境，去脂體重用規則引擎反推。
        private static func realmMeasurement(realmIndex: Int, bodyFat: Double) -> Measurement {
            let realm = Tables.realms[realmIndex]
            let ffmi = (realm.lowerFFMI + realm.upperFFMI) / 2
            let lean = Formulas.leanFor(ffmi: ffmi, heightCm: seedHeightCm)
            let weight = lean / (1 - bodyFat / 100)
            return measurement(weight, bodyFat, daysAgo: 1, lean: lean)
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
