import Foundation
import HealthKit
import Observation
import RencanCore

/// 跟健康 app 往來的唯一入口（.vibe/架構藍圖.md a07）。授權、讀、寫都走這裡，全部 throws。
/// 讀五種（身高、體重、體脂率、去脂體重、生理性別）、寫三種（體重、體脂率、去脂體重），不多要。
/// 健康數值不進 log；錯誤換成 HealthError 往上丟，系統的訊息不原樣給使用者看。
/// UI 測試模式（-rencanUITest）不碰健康 app：每個函式都當作沒有資料。
/// 回寫開關（UserSettings.healthWriteEnabled）由呼叫的畫面看，這裡不讀設定。
@MainActor
@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    private var queries: HealthQueries {
        HealthQueries(store: store)
    }

    private var isOff: Bool {
        UITestSupport.isUITest
    }

    /// 這台裝置有沒有健康 app。UI 測試模式一律當作沒有。
    var isAvailable: Bool {
        !isOff && HKHealthStore.isHealthDataAvailable()
    }

    // MARK: 授權

    /// 讀取授權，一次問五種。系統只會跳一次視窗，問過以後再呼叫不會再跳。
    /// 使用者按了不允許也不會丟錯（系統不讓 app 知道），之後讀到的就是沒有資料。
    func requestReadAuthorization() async throws {
        guard try isReady() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: HealthTypes.readSet)
        } catch {
            throw HealthError.authorizationFailed
        }
    }

    /// 寫入授權，只在使用者打開「回寫健康 app」那一刻問。回三種是不是都允許了；
    /// 回 false 時開關要留在關的位置。
    func requestWriteAuthorization() async throws -> Bool {
        guard try isReady() else { return false }
        do {
            try await store.requestAuthorization(toShare: HealthTypes.writeSet, read: [])
        } catch {
            throw HealthError.authorizationFailed
        }
        return isWriteAuthorized
    }

    /// 體重、體脂率、去脂體重三種是不是都允許寫入。
    var isWriteAuthorized: Bool {
        guard isAvailable else { return false }
        return HealthTypes.writeSet.allSatisfy { isAuthorizedToWrite($0) }
    }

    // MARK: 讀

    /// 健康 app 裡最新的身高（公分）。沒有、讀不到、或超出表單的合理範圍都回 nil，
    /// 畫面就照常問身高。
    func latestHeightCm() async throws -> Double? {
        guard try isReady() else { return nil }
        let found = try await queries.samples(of: HealthTypes.height, from: nil, to: nil, limit: 1)
        guard let newest = found.first else { return nil }
        let heightCm = newest.quantity.doubleValue(for: .meterUnit(with: .centi))
        guard Tables.heightRangeCm.contains(heightCm) else { return nil }
        return heightCm
    }

    /// 健康 app 裡的生理性別。沒設定、選「其他」、讀不到都回 nil，不猜（女性版規則第五節）。
    func biologicalSex() throws -> Sex? {
        guard try isReady() else { return nil }
        let value: HKBiologicalSex
        do {
            value = try store.biologicalSex().biologicalSex
        } catch {
            if let known = error as? HKError, known.code == .errorNoData { return nil }
            throw HealthQueries.readError(error)
        }
        switch value {
        case .male:
            return .male
        case .female:
            return .female
        case .notSet, .other:
            return nil
        @unknown default:
            return nil
        }
    }

    /// 最新一筆體組成：體重與體脂率都有的最近那一天（去脂體重那天有才帶）。
    /// 完整的一天一定有體脂率，所以先看最新那筆體脂率的那一天；那天湊不成一筆
    /// （沒量體重、數值超出範圍）才把全部樣本拿來找。規則跟重建歷史同一套（HealthImport）。
    func latestBodyComposition() async throws -> MeasurementEntry? {
        guard try isReady() else { return nil }
        let newest = try await queries.samples(
            of: HealthTypes.bodyFat, from: nil, to: nil, limit: 1
        )
        guard let anchor = newest.first else { return nil }
        if let day = HealthQueries.calendar.dateInterval(of: .day, for: anchor.startDate) {
            let sameDay = try await queries.bodySamples(from: day.start, to: day.end)
            let merged = try HealthImport.merge(samples: sameDay, existing: [])
            if let entry = merged.candidates.last { return entry }
        }
        let everything = try await queries.bodySamples(from: nil, to: nil)
        return try HealthImport.merge(samples: everything, existing: []).candidates.last
    }

    /// 某一天（含）以後的全部體重、體脂率、去脂體重樣本，交給 HealthImport.merge 整理。
    /// day 是 nil 就從最早的開始拿（換手機重建歷史）。
    func bodySamples(since day: String?) async throws -> [HealthSample] {
        guard try isReady() else { return [] }
        guard let day else { return try await everyBodySample() }
        guard let noon = DayStamp.date(from: day) else { throw RencanError.invalidDate }
        let start = HealthQueries.calendar.startOfDay(for: noon)
        return try await queries.bodySamples(from: start, to: nil)
    }

    // MARK: 寫

    /// 把一筆手打的量測寫回健康 app。只寫手打的；去脂體重沒填就不寫（不寫算出來的數字）。
    /// 要寫的那幾種只要有一種沒被允許，就整筆不寫並丟 writeNotAllowed，不留半套。
    func writeBack(_ draft: MeasurementDraft) async throws {
        guard try isReady() else { return }
        guard draft.source == .manual else { throw HealthError.notManual }
        let entry = MeasurementEntry(
            id: "", date: draft.day, weightKg: draft.weightKg,
            bodyFatPercent: draft.bodyFatPercent, leanMassKg: draft.leanMassKg
        )
        try Validation.check(entry)
        let moment = try sampleMoment(for: draft.day)
        var samples: [HKQuantitySample] = []
        samples.append(HealthQueries.sample(.weight, value: draft.weightKg, at: moment))
        samples.append(HealthQueries.sample(.bodyFat, value: draft.bodyFatPercent, at: moment))
        if let leanMassKg = draft.leanMassKg {
            samples.append(HealthQueries.sample(.leanMass, value: leanMassKg, at: moment))
        }
        guard samples.allSatisfy({ isAuthorizedToWrite($0.quantityType) }) else {
            throw HealthError.writeNotAllowed
        }
        do {
            try await store.save(samples)
        } catch {
            throw HealthError.writeFailed
        }
    }

    // MARK: 內部

    /// app 裡一筆量測都沒有時，從健康 app 最早的樣本開始拿。
    /// 湊得成一筆的那天一定要有體脂率（HealthImport），所以先讀體脂率：一筆都沒有，
    /// 體重與去脂體重各只拿最新一筆。原本只有體重的人每次回前景都把整段體重歷史讀一遍
    /// （2026-11-26 性能審查）。有沒有拿到樣本照舊，境界頁判斷讀不讀得到的結果不變。
    private func everyBodySample() async throws -> [HealthSample] {
        let fat = try await queries.samples(of: HealthTypes.bodyFat, from: nil, to: nil, limit: nil)
        let limit: Int? = fat.isEmpty ? 1 : nil
        var result = fat.map { HealthQueries.convert($0, kind: .bodyFat) }
        for kind in [HealthSampleKind.weight, .leanMass] {
            let type = HealthTypes.quantityType(for: kind)
            let found = try await queries.samples(of: type, from: nil, to: nil, limit: limit)
            result += found.map { HealthQueries.convert($0, kind: kind) }
        }
        return result
    }

    /// 可以去問健康 app 了嗎。UI 測試模式回 false，呼叫的函式直接回沒有資料；
    /// 裝置沒有健康 app 就丟錯。
    private func isReady() throws -> Bool {
        guard !isOff else { return false }
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        return true
    }

    private func isAuthorizedToWrite(_ type: HKObjectType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }

    /// 今天的量測用現在的時間；補登以前的日子不知道幾點量的，用那天中午。
    private func sampleMoment(for day: String) throws -> Date {
        if day == DayStamp.today { return Date() }
        guard let noon = DayStamp.date(from: day) else { throw RencanError.invalidDate }
        return noon
    }
}
