import Foundation
import RencanCore
import SwiftData

/// 紀錄從哪來。跟網頁版 JSON 無關，是 iOS 版自己記的。
enum RecordSource: String {
    /// 在 app 裡手打的
    case manual
    /// 從健康 app 帶進來的
    case health
    /// 從網頁版或另一支手機匯入的
    case imported
}

/// 一筆體組成量測。同一天只准一筆，由 StoreService 擋（.vibe/架構藍圖.md 第四節）。
/// 日期存成跟網頁版一樣的「yyyy-MM-dd」字串：規則引擎吃這個格式，也不會有時區換日的問題。
@Model
final class Measurement {
    /// 這筆的身分證。匯出時是 JSON 的 id，匯入時拿來去重。
    var uid: String = UUID().uuidString
    var day: String = ""
    var weightKg: Double = 0
    var bodyFatPercent: Double = 0
    /// 體脂秤給的去脂體重；沒有就用體重與體脂率算。
    var leanMassKg: Double?
    var source: String = RecordSource.manual.rawValue
    var createdAt: Date = Date()

    init(
        uid: String = UUID().uuidString, day: String, weightKg: Double, bodyFatPercent: Double,
        leanMassKg: Double?, source: RecordSource, createdAt: Date = Date()
    ) {
        self.uid = uid
        self.day = day
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.leanMassKg = leanMassKg
        self.source = source.rawValue
        self.createdAt = createdAt
    }

    /// 給規則引擎用的純值。
    var entry: MeasurementEntry {
        MeasurementEntry(
            id: uid, date: day, weightKg: weightKg, bodyFatPercent: bodyFatPercent,
            leanMassKg: leanMassKg, createdAtMs: createdAt.millisecondsSince1970
        )
    }
}

extension Date {
    /// 網頁版的 t：從 1970 年起算的毫秒數。
    var millisecondsSince1970: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }

    init(millisecondsSince1970 milliseconds: Int) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}
