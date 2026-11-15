import Observation
import RencanCore
import SwiftUI

/// 底部的小提示（網頁版的 toast）。同一句話連出兩次也要重新計時，所以帶一個 id。
struct Toast: Equatable, Identifiable {
    let id = UUID()
    let text: String
}

/// 三頁共用的流程狀態：彈出哪張表單、小提示、全螢幕慶祝、剛刪掉可以復原的那筆。
/// 三頁都會觸發也都要看得到，所以放在一個共用物件裡從 environment 注入（規矩檔第 1 節）。
@MainActor
@Observable
final class AppFlow {
    enum Sheet: Identifiable {
        case liftForm
        case measurementForm
        case editLift(LiftRecord)
        case moveDetail(MoveKey)

        var id: String {
            switch self {
            case .liftForm:
                return "liftForm"
            case .measurementForm:
                return "measurementForm"
            case .editLift(let record):
                return "edit-" + record.uid
            case .moveDetail(let key):
                return "move-" + key.rawValue
            }
        }
    }

    var page: RencanPage = .realm
    var sheet: Sheet?
    var toast: Toast?
    var celebration: Celebration?
    var undo: LiftSnapshot?

    /// 小提示停留秒數（網頁版 2.6 秒）。
    static let toastSeconds: Double = 2.6
    /// 慶祝畫面自動關閉秒數（網頁版 4.5 秒）。
    static let celebrationSeconds: Double = 4.5
    /// 刪除後可以復原的秒數。
    static let undoSeconds: Double = 5

    func showToast(_ text: String) {
        toast = Toast(text: text)
    }

    /// 存檔或讀取出錯時給使用者看的那句話。
    func showError(_ error: Error) {
        toast = Toast(text: RencanError.message(for: error))
    }
}

extension Task where Success == Never, Failure == Never {
    /// 等幾秒。中途被取消（畫面換了、同一個計時重新開始）回 false。
    static func pause(seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }
}
