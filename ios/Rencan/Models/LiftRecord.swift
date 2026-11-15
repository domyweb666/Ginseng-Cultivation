import Foundation
import RencanCore
import SwiftData

/// 一筆修煉：某門功法最重、做得最完整的那一組。跟網頁版一筆一筆對應。
@Model
final class LiftRecord {
    var uid: String = UUID().uuidString
    var day: String = ""
    /// 功法代號（squat、dead、bench、ohp、row、pull），跟網頁版同字。
    var move: String = MoveKey.squat.rawValue
    /// 槓上的重量；引體向上是額外加重，徒手是 0。
    var kg: Double = 0
    var reps: Int = 1
    var sets: Int = 1
    /// 記這筆當下的體重快照；沒量過體重就是 nil。
    var bodyweightKg: Double?
    var source: String = RecordSource.manual.rawValue
    var createdAt: Date = Date()

    init(
        uid: String = UUID().uuidString, day: String, move: MoveKey, kg: Double, reps: Int,
        sets: Int, bodyweightKg: Double?, source: RecordSource, createdAt: Date = Date()
    ) {
        self.uid = uid
        self.day = day
        self.move = move.rawValue
        self.kg = kg
        self.reps = reps
        self.sets = sets
        self.bodyweightKg = bodyweightKg
        self.source = source.rawValue
        self.createdAt = createdAt
    }

    /// 給規則引擎用的純值。功法代號不認得（資料壞掉）時是 nil。
    var entry: LiftEntry? {
        guard let key = MoveKey(rawValue: move) else { return nil }
        return LiftEntry(
            id: uid, date: day, move: key, kg: kg, reps: reps, sets: sets,
            bodyweightKg: bodyweightKg, createdAtMs: createdAt.millisecondsSince1970
        )
    }
}
