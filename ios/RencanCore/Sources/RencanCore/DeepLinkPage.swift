import Foundation

// 深連結只認三個固定頁名（安全標準類別 5；片 I2）。通知、小工具、Siri 開 app 都走這裡，
// app 那邊再把結果對到三頁其中一頁。
// 規則：
//   1. 頁名只有 settings（設定）、realm（境界）、analysis（分析），大小寫不分。其他字一律不理。
//   2. 連結寫成「rencan://頁名」。scheme 不是 rencan 的不理。
//   3. 頁名後面還有別的路徑（rencan://realm/什麼）整條不理：那已經不是固定的頁名。
//      結尾多一條斜線不算多餘路徑。
//   4. 問號與井號後面的東西完全不讀。資料不准放在連結裡（安全標準類別 1），帶了也沒有人收。
//   5. 頁名要一字不差：前後有空白、用百分號編碼、夾帳號或埠號的都不理。
// 連結用字串自己拆，不靠 URL 的 host 與 path：自訂 scheme 在 iOS 與 Linux 上拆出來的結果不保證一樣，
// 自己拆才能讓 Linux 上的測試說了算。

public enum DeepLinkPage: String, CaseIterable, Equatable {
    case settings
    case realm
    case analysis

    /// 這個 app 的連結開頭。
    public static let scheme = "rencan"

    /// 頁名（通知裡帶的那個字）。不認得就是 nil。
    public init?(name: String) {
        self.init(rawValue: name.lowercased())
    }

    /// 連結全文（例如「rencan://realm」）。不合規則就是 nil。
    public init?(urlText: String) {
        guard let colon = urlText.firstIndex(of: ":") else { return nil }
        guard urlText[..<colon].lowercased() == DeepLinkPage.scheme else { return nil }
        let afterScheme = urlText[urlText.index(after: colon)...]
        let beforeExtras = afterScheme.prefix(while: { $0 != "?" && $0 != "#" })
        let segments = beforeExtras.split(separator: "/")
        guard segments.count == 1 else { return nil }
        self.init(name: String(segments[0]))
    }
}
