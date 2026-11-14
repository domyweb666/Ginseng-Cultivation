import SwiftUI

/// 設計代號的唯一取用處（.vibe/架構藍圖.md 第六節）。2026-11-15 起照 domy-design 金棕主題。
/// 顏色住在 Resources/Assets.xcassets/Colors 的顏色集，由 .vibe/tools/domy_colors.mjs 從
/// domy-design 的 tokens.json 產生，深淺色由系統切換；
/// 畫面檔只准寫 Color.rencan.xxx，不准出現色碼（pre-commit hook 與 SwiftLint 會擋）。
struct RencanPalette {
    /// 頁底（暖米白／暖黑）
    let canvas = Color("Canvas")
    /// 卡片、分組底
    let surface = Color("Surface")
    /// 次要按鈕、分段控制底
    let surfaceMuted = Color("SurfaceMuted")
    let separator = Color("Separator")
    let fieldBorder = Color("FieldBorder")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    /// 只給裝飾（頁點未選），不准拿來寫字：對比不夠
    let textTertiary = Color("TextTertiary")
    /// 刪除、根基不穩
    let destructive = Color("Destructive")
    let destructiveSoft = Color("DestructiveSoft")
    /// 卡片陰影，透明度在 RencanLayout.shadowOpacity
    let shadow = Color("Shadow")
    /// 產品色：主按鈕底、進度條、選中
    let accent = Color("Accent")
    let onAccent = Color("OnAccent")
    /// 產品色的字：境界名、標題、文字按鈕
    let strong = Color("Strong")
    /// 標籤底、進度條底
    let soft = Color("Soft")
    /// 統計格、立繪底
    let tint = Color("Tint")
    /// 慶祝畫面的亮金
    let bright = Color("Bright")
    let onBright = Color("OnBright")
}

extension Color {
    static let rencan = RencanPalette()
}

/// 字體只從這裡取。內文用系統字（domy 字級），跟著系統文字大小縮放。
/// 境界名、功法名、頁標題用 LXGW 文楷 TC（OFL 授權），檔案在 Resources/Fonts，Info.plist 的 UIAppFonts 已登記。
enum RencanType {
    /// PostScript 名稱要跟 ttf 內的 name table 一字不差；寫錯會靜默退回系統字，所以只放這一處。
    private static let displayFontName = "LXGWWenKaiTC-Regular"

    /// 側頁大標題（設定、分析）
    static var pageTitle: Font { display(34, relativeTo: .largeTitle) }
    /// 境界頁頂端的小標題
    static var realmHeader: Font { display(22, relativeTo: .title2) }
    /// 境界名（金丹）
    static var realmName: Font { display(44, relativeTo: .largeTitle) }
    /// 功法名、宗門身分這類行內修仙名詞
    static var term: Font { display(20, relativeTo: .title3) }

    static let title3 = Font.system(.title3).weight(.semibold)
    static let headline = Font.system(.headline)
    static let body = Font.system(.body)
    static let subheadline = Font.system(.subheadline)
    static let footnote = Font.system(.footnote)
    static let caption = Font.system(.caption).weight(.medium)

    private static func display(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(displayFontName, size: size, relativeTo: style)
    }
}

/// 版面常數，數值照 domy-design 的 space／radius／size。
enum RencanLayout {
    /// 頁面左右邊距
    static let screenMargin: CGFloat = 20
    /// 區塊之間
    static let sectionSpacing: CGFloat = 20
    /// 區塊標題與卡片、卡片內元素之間
    static let itemSpacing: CGFloat = 8
    /// 卡片內距
    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 20
    /// 境界碑這種主角卡
    static let heroCornerRadius: CGFloat = 24
    static let buttonCornerRadius: CGFloat = 16
    static let portraitCornerRadius: CGFloat = 16
    /// 圖示按鈕的點擊範圍，照 iOS 的 44pt 下限。
    static let tapTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 52
    static let portraitSize = CGSize(width: 112, height: 140)
    static let pageDot: CGFloat = 7
    static let pageDotActiveWidth: CGFloat = 18
    /// 卡片陰影（domy elevation 1）
    static let shadowRadius: CGFloat = 9
    static let shadowY: CGFloat = 4
    static let shadowOpacity: Double = 0.06
}

/// 立繪的資源名稱；r0 到 r6 對應煉氣到渡劫，跟網頁版 img/ 同名。
enum RencanPortrait {
    static let servant = "r0"
}
