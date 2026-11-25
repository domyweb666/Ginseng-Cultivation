import Foundation
import Observation
import RencanCore
import SwiftData

/// 表單填好、準備存的一筆修煉。
struct LiftDraft: Equatable {
    var move: MoveKey
    var kg: Double
    var reps: Int
    var sets: Int
    var day: String
}

/// 表單填好、準備存的一筆量測。
struct MeasurementDraft: Equatable {
    var weightKg: Double
    var bodyFatPercent: Double
    var leanMassKg: Double?
    var day: String
    var source: RecordSource
}

/// 被刪掉的那筆修煉的副本，復原時照樣放回去。
struct LiftSnapshot: Equatable {
    let uid: String
    let day: String
    let move: String
    let kg: Double
    let reps: Int
    let sets: Int
    let bodyweightKg: Double?
    let source: String
    let createdAt: Date

    init(_ record: LiftRecord) {
        uid = record.uid
        day = record.day
        move = record.move
        kg = record.kg
        reps = record.reps
        sets = record.sets
        bodyweightKg = record.bodyweightKg
        source = record.source
        createdAt = record.createdAt
    }
}

/// 改資料的唯一入口（.vibe/架構藍圖.md a10）。全部 throws：存檔失敗要讓畫面顯示錯誤，
/// 絕不假裝成功（PRD S24）。檢查規則只呼叫 RencanCore 的 Validation，這裡不另寫一套。
@MainActor
@Observable
final class StoreService {
    let context: ModelContext
    /// 每次存檔成功之後要做的事。AppServices 在這裡掛「寫小工具快照」（片 G1）；
    /// 畫面與其他服務不要用它，改資料還是只走下面這些方法。
    @ObservationIgnored var afterSave: (() -> Void)?

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: 設定

    /// 設定只有一筆；還沒有就建一筆空的。
    func settings() throws -> UserSettings {
        if let existing = try context.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let created = UserSettings()
        context.insert(created)
        try save()
        return created
    }

    func saveProfile(heightCm: Double, sex: Sex) throws {
        try Validation.check(heightCm: heightCm)
        let current = try settings()
        current.heightCm = heightCm
        current.sex = sex
        try save()
    }

    // MARK: 修煉

    /// 存一筆修煉，回這次是哪一種（LiftOutcome 的七種）。
    /// digest 是存這筆之前的畫面摘要，判定要拿存前的狀態比。
    func addLift(_ draft: LiftDraft, digest: Digest) throws -> LiftJudgement {
        guard let heightCm = digest.heightCm, let sex = digest.sex else {
            throw RencanError.profileMissing
        }
        let record = LiftRecord(
            day: draft.day, move: draft.move, kg: draft.kg, reps: draft.reps, sets: draft.sets,
            bodyweightKg: digest.bodyweight(on: draft.day), source: .manual
        )
        guard let entry = record.entry else { throw RencanError.unknownMove }
        try Validation.check(entry)
        let judgement = try Judgement.liftOutcome(
            new: entry, before: digest.lifts, measurements: digest.measurements,
            heightCm: heightCm, sex: sex
        )
        context.insert(record)
        try save()
        return judgement
    }

    func update(_ record: LiftRecord, with draft: LiftDraft) throws {
        let entry = LiftEntry(
            id: record.uid, date: draft.day, move: draft.move, kg: draft.kg, reps: draft.reps,
            sets: draft.sets, bodyweightKg: record.bodyweightKg
        )
        try Validation.check(entry)
        record.day = draft.day
        record.move = draft.move.rawValue
        record.kg = draft.kg
        record.reps = draft.reps
        record.sets = draft.sets
        try save()
    }

    /// 刪一筆修煉，回它的副本，5 秒內可以用 restore 放回去。
    func delete(_ record: LiftRecord) throws -> LiftSnapshot {
        let snapshot = LiftSnapshot(record)
        context.delete(record)
        try save()
        return snapshot
    }

    func restore(_ snapshot: LiftSnapshot) throws {
        guard let move = MoveKey(rawValue: snapshot.move) else { throw RencanError.unknownMove }
        let source = RecordSource(rawValue: snapshot.source) ?? .manual
        let record = LiftRecord(
            uid: snapshot.uid, day: snapshot.day, move: move, kg: snapshot.kg, reps: snapshot.reps,
            sets: snapshot.sets, bodyweightKg: snapshot.bodyweightKg, source: source,
            createdAt: snapshot.createdAt
        )
        context.insert(record)
        try save()
    }

    // MARK: 量測

    func measurement(on day: String) throws -> Measurement? {
        let sameDay = #Predicate<Measurement> { $0.day == day }
        return try context.fetch(FetchDescriptor<Measurement>(predicate: sameDay)).first
    }

    /// 存一筆量測，回這次是哪一種（根基不穩、踏入仙途、境界突破、結算）。
    /// 同一天已經有一筆而 replacing 是 false 時丟 sameDayMeasurement，畫面先問要不要蓋掉。
    func saveMeasurement(
        _ draft: MeasurementDraft, replacing: Bool, digest: Digest
    ) throws -> MeasurementJudgement {
        guard let heightCm = digest.heightCm, let sex = digest.sex else {
            throw RencanError.profileMissing
        }
        let existing = try measurement(on: draft.day)
        if existing != nil && !replacing { throw RencanError.sameDayMeasurement }
        let record = Measurement(
            day: draft.day, weightKg: draft.weightKg, bodyFatPercent: draft.bodyFatPercent,
            leanMassKg: draft.leanMassKg, source: draft.source
        )
        try Validation.check(record.entry)
        // 判定拿「存這筆之前」的量測比，含同一天要被蓋掉的那筆（跟網頁版一樣）。
        let judgement = try Judgement.measurementOutcome(
            new: record.entry, before: digest.measurements, lifts: digest.lifts,
            heightCm: heightCm, sex: sex
        )
        if let existing {
            context.delete(existing)
        }
        context.insert(record)
        try save()
        return judgement
    }

    func delete(_ record: Measurement) throws {
        context.delete(record)
        try save()
    }

    // MARK: 存檔

    /// 寫不進去就把這次的改動整個退回，資料庫與畫面都不留半套。
    func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw RencanError.saveFailed
        }
        afterSave?()
    }
}
