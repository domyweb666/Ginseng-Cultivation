import Foundation
import HealthKit
import RencanCore

/// 健康 app 這一層自己的錯誤。訊息是給使用者看的中文，不夾數值（規矩檔第 4 節）。
enum HealthError: LocalizedError, Equatable {
    /// 這台裝置沒有健康 app（例如舊的 iPad）。
    case unavailable
    /// 還沒跳過授權視窗就先去讀。
    case notAsked
    case authorizationFailed
    case readFailed
    /// 使用者沒允許寫入，或只允許了一部分。
    case writeNotAllowed
    /// 從健康 app 帶進來的、匯入的量測不寫回去（安全標準類別 8）。
    case notManual
    case writeFailed

    var message: String {
        switch self {
        case .unavailable:
            return "這台裝置沒有健康 app"
        case .notAsked:
            return "還沒問過健康 app 的授權"
        case .authorizationFailed:
            return "健康 app 的授權沒問成功，請再試一次"
        case .readFailed:
            return "健康 app 的資料讀不出來"
        case .writeNotAllowed:
            return "健康 app 還沒允許寫入體重、體脂率、去脂體重"
        case .notManual:
            return "只有手打的量測會寫回健康 app"
        case .writeFailed:
            return "沒寫進健康 app，請再試一次"
        }
    }

    var errorDescription: String? { message }
}

/// 這個 app 跟健康 app 要的資料種類。讀五種、寫三種，不多要（安全標準類別 8）。
enum HealthTypes {
    static let weight = HKQuantityType(.bodyMass)
    static let bodyFat = HKQuantityType(.bodyFatPercentage)
    static let leanMass = HKQuantityType(.leanBodyMass)
    static let height = HKQuantityType(.height)

    /// 生理性別用回 Optional 的舊寫法拿，拿不到就少要這一種，不強制解包。
    static var readSet: Set<HKObjectType> {
        var types: Set<HKObjectType> = [weight, bodyFat, leanMass, height]
        if let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(biologicalSex)
        }
        return types
    }

    static var writeSet: Set<HKSampleType> {
        [weight, bodyFat, leanMass]
    }

    static func quantityType(for kind: HealthSampleKind) -> HKQuantityType {
        switch kind {
        case .weight:
            return weight
        case .bodyFat:
            return bodyFat
        case .leanMass:
            return leanMass
        }
    }
}

/// 對健康 app 的查詢。HealthKitService 的函式都靠這裡拿樣本，換單位也只在這裡做。
@MainActor
struct HealthQueries {
    let store: HKHealthStore

    /// 跟 DayStamp 同一套：西曆加手機的時區，樣本落在哪一天才會跟存下去的日期字串一致。
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// 某一種樣本，新的在前。start、end 是 nil 就不設那一邊的界線；limit 是 nil 就全部拿。
    /// 使用者拒絕讀取時系統回空陣列（系統不讓 app 知道被拒絕），不會丟錯。
    func samples(
        of type: HKQuantityType, from start: Date?, to end: Date?, limit: Int?
    ) async throws -> [HKQuantitySample] {
        var predicate: NSPredicate?
        if start != nil || end != nil {
            predicate = HKQuery.predicateForSamples(
                withStart: start, end: end, options: .strictStartDate
            )
        }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: limit
        )
        do {
            return try await descriptor.result(for: store)
        } catch {
            throw HealthQueries.readError(error)
        }
    }

    /// 體重、體脂率、去脂體重三種樣本，換成規則引擎吃的純值。
    func bodySamples(from start: Date?, to end: Date?) async throws -> [HealthSample] {
        var result: [HealthSample] = []
        for kind in HealthSampleKind.allCases {
            let type = HealthTypes.quantityType(for: kind)
            let found = try await samples(of: type, from: start, to: end, limit: nil)
            result += found.map { HealthQueries.convert($0, kind: kind) }
        }
        return result
    }

    /// 系統的錯誤換成這一層的錯誤，系統的英文訊息不原樣丟給使用者。
    static func readError(_ error: Error) -> HealthError {
        if let known = error as? HKError, known.code == .errorAuthorizationNotDetermined {
            return .notAsked
        }
        return .readFailed
    }

    /// 健康 app 的體脂率是 0 到 1 的比例，量測存的是百分比，換算住在 RencanCore。
    static func convert(_ sample: HKQuantitySample, kind: HealthSampleKind) -> HealthSample {
        let value: Double
        switch kind {
        case .weight, .leanMass:
            value = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        case .bodyFat:
            let fraction = sample.quantity.doubleValue(for: .percent())
            value = HealthImport.percent(fromFraction: fraction)
        }
        return HealthSample(
            kind: kind, date: DayStamp.string(from: sample.startDate), value: value,
            takenAtMs: sample.startDate.millisecondsSince1970, key: sample.uuid.uuidString
        )
    }

    /// 要寫進健康 app 的一筆樣本。體脂率換回比例。
    static func sample(
        _ kind: HealthSampleKind, value: Double, at moment: Date
    ) -> HKQuantitySample {
        let type = HealthTypes.quantityType(for: kind)
        let quantity: HKQuantity
        switch kind {
        case .weight, .leanMass:
            quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: value)
        case .bodyFat:
            let fraction = HealthImport.fraction(fromPercent: value)
            quantity = HKQuantity(unit: .percent(), doubleValue: fraction)
        }
        return HKQuantitySample(type: type, quantity: quantity, start: moment, end: moment)
    }
}
