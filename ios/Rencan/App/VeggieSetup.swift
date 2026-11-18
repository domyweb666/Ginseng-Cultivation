import SwiftUI
import VeggieKit

// 蔬菜家族共用元件（VeggieKit，2026-11-19 多米決定現在就拆成自家套件）在人蔘修煉的那一份設定。
// 只有這個檔知道人蔘修煉的名字、信箱、網址；設定頁各區從這裡拿。

extension VeggieConfig {
    static let rencan = VeggieConfig(
        name: "人蔘修煉",
        slug: "rencan",
        // 2026-11-19 多米選：跟 App Store 副標同一句，朋友點進商店看到的字一樣
        tagline: "量完體組成，看你練到哪個境界",
        // Apple ID 還沒填：填了「在 App Store 給我們評分」那列才出現，分享的字也會換成下載連結
        appStoreID: nil,
        // 2026-11-19 多米給的信箱，跟蒜日子同一個
        supportEmail: "charlie@domyweb.org",
        // 1.0 送審填的就是這一頁；規格的新路徑 domyweb.org/apps/rencan/privacy 等下一版再換（多米 2026-11-19 決定）
        privacyURL: URL(string: "https://domyweb.org/rencan/privacy")
    )
}

extension VeggieStyle {
    /// 共用元件照人蔘修煉的金棕色票與字
    static let rencan = VeggieStyle(
        textPrimary: Color.rencan.textPrimary,
        textSecondary: Color.rencan.textSecondary,
        textTertiary: Color.rencan.textTertiary,
        accent: Color.rencan.strong,
        destructive: Color.rencan.destructive,
        canvas: Color.rencan.canvas,
        surface: Color.rencan.surface,
        body: RencanType.body,
        headline: RencanType.headline,
        subheadline: RencanType.subheadline,
        footnote: RencanType.footnote,
        rowHeight: RencanLayout.rowHeight
    )
}

extension VeggieLicense {
    /// 隨 app 發布要附授權全文的東西。app 沒有用別人的程式套件，只有字型
    static let rencan = [
        VeggieLicense(
            name: "霞鶩文楷 TC", license: "SIL Open Font License 1.1", file: "OFL-LXGWWenKaiTC.txt"
        )
    ]
}
