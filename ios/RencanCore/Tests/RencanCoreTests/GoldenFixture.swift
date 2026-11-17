import Foundation

@testable import RencanCore

// 黃金集檔案 Fixtures/web-export.json 的形狀。那個檔由 .vibe/tools/golden_build.mjs 產生：
// 每一組的 export 是網頁版存檔的格式（meas、lift、cfg），expected 是網頁版原版程式算出來的答案。
// 這裡的型別只給測試讀檔用；正式的匯入格式與檢查在 Sources 的 WebExport.swift（片 B4）。
// 網頁版的欄位名太短（bf、bw、t），用 CodingKeys 對到完整名。
// 檔案裡還有宗門身分的答案（sectGrid、各組的 sect），2026-11-17 起不讀：app 的宗門規則跟網頁版不一樣了。

struct GoldenFile: Decodable {
    let today: String
    let groups: [GoldenGroup]
    let ladder: [GoldenLadderStep]
    let durations: [GoldenDuration]
    let dayGaps: [GoldenDayGap]
}

struct GoldenGroup: Decodable {
    let name: String
    let export: GoldenExport
    let expected: GoldenExpected
}

struct GoldenExport: Decodable {
    let meas: [GoldenMeasurement]
    let lift: [GoldenLift]
    let cfg: GoldenConfig
}

struct GoldenConfig: Decodable {
    let height: Double
}

struct GoldenMeasurement: Decodable {
    let id: String
    let date: String
    let weight: Double
    let bodyFat: Double
    let lean: Double?
    let createdAtMs: Int

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case weight
        case bodyFat = "bf"
        case lean
        case createdAtMs = "t"
    }

    var entry: MeasurementEntry {
        MeasurementEntry(
            id: id, date: date, weightKg: weight, bodyFatPercent: bodyFat, leanMassKg: lean,
            createdAtMs: createdAtMs
        )
    }
}

struct GoldenLift: Decodable {
    let id: String
    let date: String
    let move: String
    let kg: Double
    let reps: Int
    let sets: Int
    let bodyweight: Double?
    let createdAtMs: Int

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case move
        case kg
        case reps
        case sets
        case bodyweight = "bw"
        case createdAtMs = "t"
    }

    /// 假資料裡的功法代號一定認得；不認得就回 nil，讓測試當場失敗。
    var entry: LiftEntry? {
        guard let key = MoveKey(rawValue: move) else { return nil }
        return LiftEntry(
            id: id, date: date, move: key, kg: kg, reps: reps, sets: sets,
            bodyweightKg: bodyweight, createdAtMs: createdAtMs
        )
    }
}

struct GoldenExpected: Decodable {
    let measurements: [GoldenStanding]
    let breakthroughs: [GoldenBreakthrough]
    let realmMax: Int
    let trainDays: Int
    let weekCount: Int
    let lifts: [GoldenLiftAnswer]
    let best: [GoldenLiftAnswer]
}

/// 一筆量測在網頁版算出來的境界。
struct GoldenStanding: Decodable {
    let date: String
    let lean: Double
    let ffmi: Double
    let realmIndex: Int
    let stageIndex: Int
    let label: String
    let nextFFMI: Double?
    let fromFFMI: Double
    let nextLabel: String?
    let leanNeeded: Double?
}

struct GoldenBreakthrough: Decodable {
    let date: String
    let stageRank: Int
    let label: String
    let first: Bool
    let days: Int
}

/// 一筆修煉的答案。best 裡的每一筆多帶功法代號。
struct GoldenLiftAnswer: Decodable {
    let move: String?
    let id: String
    let e1rm: Double
    let ratio: Double
    let bodyweight: Double
    let level: Int
}

struct GoldenLadderStep: Decodable {
    let ffmi: Double
    let label: String
    let nextFFMI: Double?
    let fromFFMI: Double
}

struct GoldenDuration: Decodable {
    let days: Int
    let text: String
}

struct GoldenDayGap: Decodable {
    let from: String
    let until: String
    let days: Int
}

extension GoldenGroup {
    var measurements: [MeasurementEntry] { export.meas.map(\.entry) }
    var lifts: [LiftEntry] { export.lift.compactMap(\.entry) }
    var heightCm: Double { export.cfg.height }
}
