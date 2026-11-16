import RencanCore
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

    // 粒子自己的顏色，深淺色同一個值，不跟主題換（.vibe/tools/domy_colors.mjs 的 fixed）。
    /// 慶祝粒子的翠綠（網頁版粒子是金 2/3、翠 1/3）
    let sparkJade = Color("SparkJade")
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

    /// 期別（後期），跟在境界名後面
    static var realmStage: Font { display(24, relativeTo: .title2) }
    /// 清單列裡的功法名
    static var termBody: Font { display(17, relativeTo: .body) }
    /// 宗門卡上的大身分
    static var sectTitle: Font { display(30, relativeTo: .title) }
    /// 慶祝畫面的大字與旁邊的期別
    static var celebrationTitle: Font { display(64, relativeTo: .largeTitle) }
    static var celebrationStage: Font { display(32, relativeTo: .title) }

    /// 表單上的大數字（重量、身高）
    static let bigNumber = Font.system(.largeTitle).weight(.bold).monospacedDigit()
    /// 表單上中等的數字（次數、組數）
    static let mediumNumber = Font.system(.title).weight(.bold).monospacedDigit()
    /// 統計格的數字
    static let statNumber = Font.system(.title2).weight(.bold)
    static let title2 = Font.system(.title2).weight(.semibold)
    static let title3 = Font.system(.title3).weight(.semibold)
    static let headline = Font.system(.headline)
    static let callout = Font.system(.callout).weight(.semibold)
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
    /// 卡片陰影（domy elevation 1）
    static let shadowRadius: CGFloat = 9
    static let shadowY: CGFloat = 4
    static let shadowOpacity: Double = 0.06
    /// 境界頁的小提示與復原列離分頁列多遠（讓出「記一筆修煉」：按鈕 52、上下各 8）
    static let bannerBottomInset: CGFloat = 68
    /// 慶祝畫面淡入淡出的秒數
    static let fadeSeconds: Double = 0.25
    /// 列的最小高度（設定列、清單列）
    static let rowHeight: CGFloat = 52
    /// 小標籤（等級、根基）的左右內距與上下內距
    static let chipHorizontalPadding: CGFloat = 10
    static let chipVerticalPadding: CGFloat = 4
    /// 進度條的粗細與分段之間的縫
    static let barHeight: CGFloat = 8
    static let barGap: CGFloat = 4
    /// 圓形加減鈕
    static let stepperSize: CGFloat = 44
    /// 表單裡小一號的圓角（輸入框、分段按鈕）
    static let fieldCornerRadius: CGFloat = 12
    /// 統計格與提示框的內距
    static let panelPadding: CGFloat = 14
    /// 元素之間中等的間距
    static let groupSpacing: CGFloat = 12
    /// 來源列左邊的小圓圖示
    static let sourceIconSize: CGFloat = 36
    /// 字太長時最多縮到幾成
    static let minimumTextScale: CGFloat = 0.7
    /// 次要按鈕的高度
    static let secondaryButtonHeight: CGFloat = 48
    /// 記一筆表單上功法格子的高度
    static let moveButtonHeight: CGFloat = 56
    /// 量體組成表單：數字欄的寬與高、單位的寬、一列的高
    static let numberFieldWidth: CGFloat = 88
    static let numberFieldHeight: CGFloat = 40
    static let unitWidth: CGFloat = 36
    static let formRowHeight: CGFloat = 56
}

/// 立繪的資源名稱；r0 到 r6 對應煉氣到渡劫，跟網頁版 img/ 同名。
enum RencanPortrait {
    /// 還沒量過時的雜役服立繪
    static let servant = "r0"
    /// 宗門晉升時的長老圖
    static let elder = "elder"

    /// 某個大境界的立繪：男 r0–r6、女 gr0–gr6（.vibe/女性版規則.md 第五節）。
    static func name(realmIndex: Int, sex: Sex) -> String {
        let prefix = sex == .female ? "gr" : "r"
        let highest = Tables.realms.count - 1
        return prefix + String(max(0, min(highest, realmIndex)))
    }
}
