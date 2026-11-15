import Foundation

// 網頁版匯出的 JSON（片 B4）。匯入匯出同一個格式（.vibe/架構藍圖.md 第四節）：
//   { meas:[{id,date,weight,bf,lean?,t}], lift:[{id,date,move,kg,reps,sets,bw,t}], cfg:{height} }
// 這裡只做「讀進來、檢查、寫出去」，不碰資料庫（寫入是組塊 F）。
// 壞檔一律整份拒絕並說是哪一筆、什麼原因，不猜一個值補上。
// 檢查規則（Validation）只住在這一處，表單、Siri、匯入三個入口都呼叫它（規矩檔第 2 節）。

/// 輸入檢查。範圍跟網頁版表單一樣，數字在 Tables。
public enum Validation {
    public static func check(_ measurement: MeasurementEntry) throws {
        _ = try Formulas.dayNumber(of: measurement.date)
        guard Tables.weightRangeKg.contains(measurement.weightKg) else {
            throw RencanError.weightOutOfRange
        }
        guard Tables.bodyFatRangePercent.contains(measurement.bodyFatPercent) else {
            throw RencanError.bodyFatOutOfRange
        }
        if let leanMassKg = measurement.leanMassKg {
            guard Tables.leanMassRangeKg.contains(leanMassKg) else {
                throw RencanError.leanMassOutOfRange
            }
        }
    }

    public static func check(_ lift: LiftEntry) throws {
        _ = try Formulas.dayNumber(of: lift.date)
        guard lift.kg >= 0 else { throw RencanError.negativeLoad }
        guard Tables.repsRange.contains(lift.reps) else { throw RencanError.repsOutOfRange }
        guard Tables.setsRange.contains(lift.sets) else { throw RencanError.setsOutOfRange }
        // 體重快照是 0 代表沒有（網頁版同樣當成沒有）；有的話要是合理的體重。
        if let bodyweightKg = lift.bodyweightKg, bodyweightKg != 0 {
            guard Tables.weightRangeKg.contains(bodyweightKg) else {
                throw RencanError.weightOutOfRange
            }
        }
    }

    public static func check(heightCm: Double) throws {
        guard Tables.heightRangeCm.contains(heightCm) else { throw RencanError.heightOutOfRange }
    }
}

/// 壞的是檔案的哪一部分。筆數從 1 起算，照檔案裡的順序。
public enum WebExportRecord: Equatable {
    case file
    case measurement(Int)
    case lift(Int)
    case settings
}

/// 匯入被拒絕的原因：哪一筆、為什麼。
public struct WebExportError: Error, Equatable {
    public let record: WebExportRecord
    public let reason: RencanError
}

/// 一份網頁版匯出檔的內容，已經通過檢查。
public struct WebExport: Equatable {
    public let measurements: [MeasurementEntry]
    public let lifts: [LiftEntry]
    /// 網頁版設定裡的身高；檔案裡沒有就是 nil，不補預設值。
    public let heightCm: Double?

    public init(measurements: [MeasurementEntry], lifts: [LiftEntry], heightCm: Double?) {
        self.measurements = measurements
        self.lifts = lifts
        self.heightCm = heightCm
    }

    /// 讀一份匯出檔。任何一筆壞掉就整份拒絕，丟 WebExportError。
    public static func decode(_ data: Data) throws -> WebExport {
        let file: WebFile
        do {
            file = try JSONDecoder().decode(WebFile.self, from: data)
        } catch let error as DecodingError {
            throw problem(from: error)
        }
        let measurements = try checkedMeasurements(file.meas)
        let lifts = try checkedLifts(file.lift)
        if let heightCm = file.cfg?.height {
            do {
                try Validation.check(heightCm: heightCm)
            } catch let reason as RencanError {
                throw WebExportError(record: .settings, reason: reason)
            }
        }
        return WebExport(measurements: measurements, lifts: lifts, heightCm: file.cfg?.height)
    }

    /// 寫成網頁版的格式。欄位照字母排，同一份資料每次寫出來都一樣。
    public func encoded() throws -> Data {
        let config = heightCm.map { WebConfig(height: $0) }
        let file = WebFile(
            meas: measurements.map(WebMeasurement.init(entry:)),
            lift: lifts.map(WebLift.init(entry:)), cfg: config
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(file)
    }

    private static func checkedMeasurements(_ raws: [WebMeasurement]) throws -> [MeasurementEntry] {
        var seen: Set<String> = []
        var entries: [MeasurementEntry] = []
        for (offset, raw) in raws.enumerated() {
            let entry = raw.entry
            do {
                guard seen.insert(raw.id).inserted else { throw RencanError.duplicateID }
                try Validation.check(entry)
            } catch let reason as RencanError {
                throw WebExportError(record: .measurement(offset + 1), reason: reason)
            }
            entries.append(entry)
        }
        return entries
    }

    private static func checkedLifts(_ raws: [WebLift]) throws -> [LiftEntry] {
        var seen: Set<String> = []
        var entries: [LiftEntry] = []
        for (offset, raw) in raws.enumerated() {
            do {
                guard seen.insert(raw.id).inserted else { throw RencanError.duplicateID }
                guard let entry = raw.entry else { throw RencanError.unknownMove }
                try Validation.check(entry)
                entries.append(entry)
            } catch let reason as RencanError {
                throw WebExportError(record: .lift(offset + 1), reason: reason)
            }
        }
        return entries
    }

    /// 把 JSON 解不開的原因翻成「哪一筆、什麼原因」。
    private static func problem(from error: DecodingError) -> WebExportError {
        switch error {
        case .keyNotFound(_, let context):
            return WebExportError(record: record(at: context.codingPath), reason: .missingField)
        case .valueNotFound(_, let context):
            return WebExportError(record: record(at: context.codingPath), reason: .missingField)
        case .typeMismatch(_, let context):
            return WebExportError(record: record(at: context.codingPath), reason: .wrongFieldType)
        case .dataCorrupted(let context):
            // 路徑是空的代表整份檔案就不是 JSON；有路徑代表某個欄位的值解不開。
            let reason: RencanError = context.codingPath.isEmpty ? .notJSON : .wrongFieldType
            return WebExportError(record: record(at: context.codingPath), reason: reason)
        @unknown default:
            return WebExportError(record: .file, reason: .notJSON)
        }
    }

    /// 解碼器回報的路徑長這樣：meas → 第幾個 → 欄位名。
    private static func record(at path: [CodingKey]) -> WebExportRecord {
        guard let section = path.first?.stringValue else { return .file }
        let offset = path.dropFirst().first?.intValue
        switch section {
        case "meas":
            return offset.map { WebExportRecord.measurement($0 + 1) } ?? .file
        case "lift":
            return offset.map { WebExportRecord.lift($0 + 1) } ?? .file
        case "cfg":
            return .settings
        default:
            return .file
        }
    }
}

// MARK: 檔案裡的原樣（欄位名照網頁版）

private struct WebFile: Codable {
    let meas: [WebMeasurement]
    let lift: [WebLift]
    let cfg: WebConfig?
}

private struct WebConfig: Codable {
    let height: Double?
}

private struct WebMeasurement: Codable {
    let id: String
    let date: String
    let weight: Double
    let bodyFat: Double
    let lean: Double?
    let createdAtMs: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case weight
        case bodyFat = "bf"
        case lean
        case createdAtMs = "t"
    }

    init(entry: MeasurementEntry) {
        id = entry.id
        date = entry.date
        weight = entry.weightKg
        bodyFat = entry.bodyFatPercent
        lean = entry.leanMassKg
        createdAtMs = entry.createdAtMs
    }

    var entry: MeasurementEntry {
        MeasurementEntry(
            id: id, date: date, weightKg: weight, bodyFatPercent: bodyFat, leanMassKg: lean,
            createdAtMs: createdAtMs ?? 0
        )
    }
}

private struct WebLift: Codable {
    let id: String
    let date: String
    let move: String
    let kg: Double
    let reps: Int
    let sets: Int
    let bodyweight: Double?
    let createdAtMs: Int?

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

    init(entry: LiftEntry) {
        id = entry.id
        date = entry.date
        move = entry.move.rawValue
        kg = entry.kg
        reps = entry.reps
        sets = entry.sets
        bodyweight = entry.bodyweightKg
        createdAtMs = entry.createdAtMs
    }

    /// 功法代號不認得就回 nil。
    var entry: LiftEntry? {
        guard let key = MoveKey(rawValue: move) else { return nil }
        return LiftEntry(
            id: id, date: date, move: key, kg: kg, reps: reps, sets: sets,
            bodyweightKg: bodyweight, createdAtMs: createdAtMs ?? 0
        )
    }
}
