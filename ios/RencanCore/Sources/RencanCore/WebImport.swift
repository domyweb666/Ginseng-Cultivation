import Foundation

// 匯入網頁版 JSON 之前，先算好「要寫哪幾筆」（片 F3）。這裡只比對，不讀檔、不碰資料庫。
// 檔案的格式與範圍檢查在 WebExport.decode；這裡拿到的已經是通過檢查的內容。
// 去重規則（標準清單沒列，2026-11-16 代決）：
//   1. 量測：本機同一天已經有一筆，或本機有同一個 id，就跳過，本機那筆不動。
//      網頁版量測的 id 就是日期，所以對網頁版的檔案來說這兩條是同一件事。
//   2. 檔案裡同一天有好幾筆本機還沒有的量測：只留建立時間最晚的那筆，時間一樣留檔案裡後面那筆。
//      iOS 一天只准一筆；網頁版同一天再量一次也是蓋掉前一筆。
//   3. 修煉：本機有同一個 id 就跳過。
//   4. 身高：檔案有、而且跟本機不一樣，匯入時改成檔案的（PRD S22「量測、修煉、身高一筆不少」）。
//      性別不在網頁版的格式裡，匯入不會動它。

/// 一次匯入要做的事。量測與修煉都照檔案裡的順序。
public struct WebImportPlan: Equatable {
    /// 匯入檔最大幾個位元組。安全標準類別 9 沒寫數字，定 5 MB：
    /// 一筆修煉大約 110 個位元組，裝得下四萬多筆，正常的匯出檔碰不到。
    public static let maximumFileBytes = 5 * 1024 * 1024

    /// 檔案裡的量測有幾筆。
    public let measurementTotal: Int
    /// 檔案裡的修煉有幾筆。
    public let liftTotal: Int
    /// 要新增的量測。
    public let measurements: [MeasurementEntry]
    /// 要新增的修煉。
    public let lifts: [LiftEntry]
    /// 本機已經有、所以跳過的筆數（量測加修煉）。
    public let alreadyHaveCount: Int
    /// 檔案裡同一天多出來、沒被留下的量測筆數。
    public let sameDayExtraCount: Int
    /// 匯入後身高要改成多少；不用改就是 nil。
    public let heightCm: Double?

    /// 會新增幾筆（量測加修煉）。
    public var addCount: Int { measurements.count + lifts.count }

    /// 這次匯入會不會改到本機的任何東西。
    public var hasChanges: Bool {
        !measurements.isEmpty || !lifts.isEmpty || heightCm != nil
    }

    public init(
        file: WebExport, localMeasurements: [MeasurementEntry], localLifts: [LiftEntry],
        localHeightCm: Double?
    ) {
        let takenDays = Set(localMeasurements.map(\.date))
        let takenMeasurementIDs = Set(localMeasurements.map(\.id))
        let fresh = file.measurements.filter {
            !takenDays.contains($0.date) && !takenMeasurementIDs.contains($0.id)
        }
        let kept = WebImportPlan.latestPerDay(fresh)
        let takenLiftIDs = Set(localLifts.map(\.id))
        let newLifts = file.lifts.filter { !takenLiftIDs.contains($0.id) }
        let skippedMeasurements = file.measurements.count - fresh.count
        let skippedLifts = file.lifts.count - newLifts.count
        measurementTotal = file.measurements.count
        liftTotal = file.lifts.count
        measurements = kept
        lifts = newLifts
        alreadyHaveCount = skippedMeasurements + skippedLifts
        sameDayExtraCount = fresh.count - kept.count
        heightCm = file.heightCm == localHeightCm ? nil : file.heightCm
    }

    /// 每一天只留建立時間最晚的那筆，時間一樣留後面那筆；留下來的照原本的順序。
    private static func latestPerDay(_ entries: [MeasurementEntry]) -> [MeasurementEntry] {
        var winners: [String: Int] = [:]
        for (offset, entry) in entries.enumerated() {
            if let current = winners[entry.date], entries[current].createdAtMs > entry.createdAtMs {
                continue
            }
            winners[entry.date] = offset
        }
        var kept: [MeasurementEntry] = []
        for (offset, entry) in entries.enumerated() where winners[entry.date] == offset {
            kept.append(entry)
        }
        return kept
    }
}

extension WebExportError {
    /// 給使用者看的那句話：哪一筆、什麼原因，例如「第 3 筆量測：體重超出範圍」。
    /// 只說第幾筆，不夾那一筆的數值（安全標準類別 1）。
    public var message: String {
        switch record {
        case .file:
            return reason.message
        case .measurement(let number):
            return "第 \(number) 筆量測：" + reason.message
        case .lift(let number):
            return "第 \(number) 筆修煉：" + reason.message
        case .settings:
            return "身高設定：" + reason.message
        }
    }
}
