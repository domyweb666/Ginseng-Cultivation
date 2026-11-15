import Foundation

// 量測與修煉的純值。欄位跟網頁版存的一筆一筆對應（.vibe/架構藍圖.md 第四節）：
//   meas：weight → weightKg、bf → bodyFatPercent、lean → leanMassKg、t → createdAtMs
//   lift：bw → bodyweightKg、t → createdAtMs
// 日期一律是「yyyy-MM-dd」字串，跟網頁版同一格式，天數才算得一模一樣（規矩檔第 1 節）。

/// 一筆體組成量測。
public struct MeasurementEntry: Equatable {
    public let id: String
    public let date: String
    public let weightKg: Double
    public let bodyFatPercent: Double
    /// 體脂秤給的去脂體重；沒有就用體重與體脂率算。
    public let leanMassKg: Double?
    /// 建立時間（毫秒）。網頁版同一天多筆時靠它排先後。
    public let createdAtMs: Int

    public init(
        id: String, date: String, weightKg: Double, bodyFatPercent: Double,
        leanMassKg: Double? = nil, createdAtMs: Int = 0
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.leanMassKg = leanMassKg
        self.createdAtMs = createdAtMs
    }
}

/// 一筆修煉（某門功法最重的那一組）。
public struct LiftEntry: Equatable {
    public let id: String
    public let date: String
    public let move: MoveKey
    /// 槓上的重量；引體向上是額外加重，徒手是 0。
    public let kg: Double
    public let reps: Int
    public let sets: Int
    /// 記這筆當下的體重快照；沒有就用量測紀錄找。
    public let bodyweightKg: Double?
    public let createdAtMs: Int

    public init(
        id: String, date: String, move: MoveKey, kg: Double, reps: Int, sets: Int,
        bodyweightKg: Double? = nil, createdAtMs: Int = 0
    ) {
        self.id = id
        self.date = date
        self.move = move
        self.kg = kg
        self.reps = reps
        self.sets = sets
        self.bodyweightKg = bodyweightKg
        self.createdAtMs = createdAtMs
    }
}
