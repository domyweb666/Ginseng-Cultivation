import Foundation
import RencanCore

/// 深連結進來要換到哪一頁。通知、小工具、Siri 開 app 都只准換到三頁其中一頁。
/// 認不認得由 RencanCore 的 DeepLinkPage 決定（規則與測試都在那邊），這裡只把結果對到 RencanPage。
/// 連結與通知都不帶資料，參數一律不讀（安全標準類別 1、類別 5）。
enum DeepLink {
    /// 通知的 userInfo 用這個鍵帶頁名，值是 DeepLinkPage 的 rawValue。
    static let pageKey = "page"

    /// 連結（例如小工具的「rencan://realm」）。不合規則回 nil，呼叫的地方就當沒收到。
    static func page(for url: URL) -> RencanPage? {
        DeepLinkPage(urlText: url.absoluteString).map(rencanPage)
    }

    /// 頁名（通知裡帶的那個字）。不認得回 nil。
    static func page(named name: String) -> RencanPage? {
        DeepLinkPage(name: name).map(rencanPage)
    }

    private static func rencanPage(_ target: DeepLinkPage) -> RencanPage {
        switch target {
        case .settings:
            return .settings
        case .realm:
            return .realm
        case .analysis:
            return .analysis
        }
    }
}
