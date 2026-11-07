import SwiftUI

/// 設計代號的唯一取用處（.vibe/架構藍圖.md 第六節）。
/// 顏色住在 Resources/Assets.xcassets/Colors 的顏色集，深淺色由系統切換；
/// 畫面檔只准寫 Color.rencan.xxx，不准出現色碼（pre-commit hook 與 SwiftLint 會擋）。
struct RencanPalette {
    let background = Color("Background")
    let paper = Color("Paper")
    let ink = Color("Ink")
    let inkSecondary = Color("InkSecondary")
    let line = Color("Line")
    let jade = Color("Jade")
    let jadeSoft = Color("JadeSoft")
    let gold = Color("Gold")
    let goldSoft = Color("GoldSoft")
    let warn = Color("Warn")
    let scroll = Color("Scroll")
}

extension Color {
    static let rencan = RencanPalette()
}

/// 字體只從這裡取。顯示字體是 LXGW 文楷 TC（OFL 授權），
/// 檔案在 Resources/Fonts，Info.plist 的 UIAppFonts 已登記。
enum RencanType {
    /// PostScript 名稱要跟 ttf 內的 name table 一字不差；寫錯會靜默退回系統字，所以只放這一處。
    private static let displayFontName = "LXGWWenKaiTC-Regular"
    private static let pageTitleSize: CGFloat = 34

    /// 頁標題跟著系統文字大小縮放（relativeTo），放到最大也不能截斷。
    static var pageTitle: Font {
        .custom(displayFontName, size: pageTitleSize, relativeTo: .largeTitle)
    }
}

/// 版面常數：圓角與間距照網頁版 CSS。
enum RencanLayout {
    static let cardCornerRadius: CGFloat = 14
    static let pageSpacing: CGFloat = 24
    static let portraitMaxWidth: CGFloat = 240
}

/// 立繪的資源名稱；r0 到 r6 對應煉氣到渡劫，跟網頁版 img/ 同名。
enum RencanPortrait {
    static let servant = "r0"
}
