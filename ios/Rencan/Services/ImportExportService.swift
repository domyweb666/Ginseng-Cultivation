import Foundation
import RencanCore

// 這個檔假設 StoreService 有下面這個函式（組塊 F，由主會話貼進 StoreService.swift）：
//   func importRecords(_ plan: WebImportPlan) throws
//     一次寫進 plan 裡要新增的量測、修煉與身高；任何一筆沒過檢查或存檔失敗就整批不寫。
// 「清除所有資料」不經過這裡，畫面直接呼叫 StoreService.eraseAllData()。

/// 匯入匯出這一層自己的錯誤。訊息是給使用者看的中文，不夾數值（規矩檔第 4 節）。
enum ImportExportError: LocalizedError, Equatable {
    /// 選的檔案打不開或讀不出來。
    case unreadable
    /// 檔案超過 WebImportPlan.maximumFileBytes。
    case tooLarge

    var message: String {
        switch self {
        case .unreadable:
            return "檔案讀不出來"
        case .tooLarge:
            return "檔案太大，不像是匯出的紀錄"
        }
    }

    var errorDescription: String? { message }
}

/// 匯出與匯入（.vibe/架構藍圖.md a16；PRD S22、S23）。格式就是網頁版的 JSON，定義在 RencanCore 的
/// WebExport；這裡只管檔案進出與交給 StoreService 寫入，不另寫一套檢查。
/// 匯入檔是外面來的東西：只讀檔案選擇器給的那個位置、最多讀 5 MB、只用 Codable 解、
/// 全部檢查完才寫（安全標準類別 9）。檔案內容與數值不進 log。
@MainActor
enum ImportExportService {
    /// 暫存資料夾底下放匯出檔的子資料夾。每次匯出先清空，舊的匯出檔不會一直留著。
    private static let exportFolderName = "export"

    // MARK: 匯出

    /// 匯出檔的檔名：人蔘修煉-備份-2026-11-19.json（蔬菜家族共用規格，多米 2026-11-19 決定）。
    /// 只改檔名，檔案內容照舊是網頁版匯出的格式；app 匯入只看內容不看檔名，網頁版下載的 rencan-*.json 照樣匯得進來。
    static func exportFileName(day: String) -> String {
        "人蔘修煉-備份-" + day + ".json"
    }

    /// 把本機全部的量測、修煉與身高寫成一個暫存檔，回它的位置，交給系統的分享表單。
    /// 性別不在網頁版的格式裡，所以不在檔案裡。
    static func writeExport(of digest: Digest) throws -> URL {
        let export = WebExport(
            measurements: digest.measurements, lifts: digest.lifts, heightCm: digest.heightCm
        )
        let data = try export.encoded()
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent(
            exportFolderName, isDirectory: true
        )
        if manager.fileExists(atPath: folder.path) {
            try manager.removeItem(at: folder)
        }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(exportFileName(day: DayStamp.today))
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: 匯入

    /// 匯入第一步：讀檔、檢查格式、跟本機的紀錄比對，回「會新增哪幾筆」。這一步不寫任何東西。
    /// 檔案讀不出來或太大丟 ImportExportError；格式或內容不對丟 WebExportError（哪一筆、什麼原因）。
    static func readImport(from url: URL, digest: Digest) throws -> WebImportPlan {
        let file = try WebExport.decode(contents(of: url))
        return WebImportPlan(
            file: file, localMeasurements: digest.measurements, localLifts: digest.lifts,
            localHeightCm: digest.heightCm
        )
    }

    /// 匯入第二步：使用者看過預覽、按了確認才呼叫。全部寫進去或全部不寫。
    /// 匯入的量測不做慶祝判定，也不寫回健康 app。
    static func commit(_ plan: WebImportPlan, to store: StoreService) throws {
        try store.importRecords(plan)
    }

    /// 檔案被拒絕時給使用者看的那句話：壞檔說是哪一筆、什麼原因。
    /// 認不得的錯誤（檔案選擇器自己出錯）一律說讀不出來，不把系統訊息原樣丟出去。
    static func rejectionMessage(for error: Error) -> String {
        if let problem = error as? WebExportError {
            return problem.message
        }
        if let problem = error as? ImportExportError {
            return problem.message
        }
        if let reason = error as? RencanError {
            return reason.message
        }
        return ImportExportError.unreadable.message
    }

    /// 讀檔案選擇器給的那個檔。位置是系統給的安全範圍，用之前要先開、用完要關；不自己拼路徑。
    /// 最多讀到上限再多一個位元組：多出來就知道檔案太大，不用把整個大檔讀進記憶體。
    private static func contents(of url: URL) throws -> Data {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let limit = WebImportPlan.maximumFileBytes
        let data: Data
        do {
            let handle = try FileHandle(forReadingFrom: url)
            data = try handle.read(upToCount: limit + 1) ?? Data()
            try handle.close()
        } catch {
            throw ImportExportError.unreadable
        }
        guard data.count <= limit else { throw ImportExportError.tooLarge }
        return data
    }
}
