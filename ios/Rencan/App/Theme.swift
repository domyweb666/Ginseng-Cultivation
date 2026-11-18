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

    // 境界碑深色卡自己的顏色，深淺色同一個值（同一支工具的 fixed）。
    /// 深色卡上的境界名與期別
    let realmName = Color("RealmName")
    /// 深色卡上根基不穩那一行；在七個底色上的對比都有 4.5 以上
    let realmWarning = Color("RealmWarning")
    /// 紅印章，和印章上的字
    let seal = Color("Seal")
    let onSeal = Color("OnSeal")

    /// 深色卡的底色，一境一個（0 煉氣到 6 渡劫）。
    func realmBase(_ realmIndex: Int) -> Color {
        Color("RealmBase" + String(RencanPalette.realmSlot(realmIndex)))
    }

    /// 深色卡上 FFMI 那一行小字，一境一個。
    func realmSub(_ realmIndex: Int) -> Color {
        Color("RealmSub" + String(RencanPalette.realmSlot(realmIndex)))
    }

    // 修煉卡（分享出去的圖）自己的顏色，深淺色同一個值：存下來的圖不管手機開不開深色都長一樣。
    // 外框用該境界的 realmSub 與 realmBase 漸層，不另外加色。
    /// 卡面的米白底
    let cardBase = Color("CardBase")
    /// 宗門身分那一條的深棕底，也是功法名、數字說明的字色
    let cardBand = Color("CardBand")
    /// 深棕條上的字
    let onCardBand = Color("OnCardBand")
    /// 境界名、期別、app 名的金棕
    let cardTitle = Color("CardTitle")
    /// 道號、數字的深色字
    let cardText = Color("CardText")
    /// 「道號」小字、日期這類灰字
    let cardMuted = Color("CardMuted")
    /// 三格數字的底
    let cardStat = Color("CardStat")
    /// 六門功法格子的底
    let cardMove = Color("CardMove")

    /// 顏色集只有 0 到 6，超出去的序號夾回來，免得取到不存在的顏色變成透明。
    private static func realmSlot(_ realmIndex: Int) -> Int {
        max(0, min(Tables.realms.count - 1, realmIndex))
    }
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
    /// 境界名（金丹），深色卡上立繪下面那一行
    static var realmName: Font { display(32, relativeTo: .title) }
    /// 功法名、宗門身分這類行內修仙名詞
    static var term: Font { display(20, relativeTo: .title3) }

    /// 期別（後期），跟在境界名後面
    static var realmStage: Font { display(20, relativeTo: .title3) }
    /// 紅印章上的字。印章是固定大小的方塊，字不跟著系統文字大小放大。
    static var seal: Font { .custom(displayFontName, fixedSize: 22) }
    /// 清單列裡的功法名
    static var termBody: Font { display(17, relativeTo: .body) }
    /// 功法雷達軸端的功法名：十二根軸都要寫，字小一點圖才放得大。
    /// 雷達圖要用同一個數字算版面（MoveRadar 的 @ScaledMetric），所以字級另外給名字。
    static let radarLabelSize: CGFloat = 13

    /// 修煉卡上的字。卡是要存成 1080×1920 的圖，排版固定，字不跟著系統文字大小變。
    static func cardDisplay(_ size: CGFloat) -> Font { .custom(displayFontName, fixedSize: size) }
    static func cardText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static var radarLabel: Font { display(radarLabelSize, relativeTo: .footnote) }
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
    /// 底部分頁列的圖示
    static let tabIcon = Font.system(.title3)

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
    /// 設定、分析的大標題上面留這麼多，標題才會落在 iOS 原生大標題的位置（上面先讓出一條標題列）。
    /// 2026-11-18 多米說兩頁標題太貼頂，要像系統設定那樣。
    static let pageTitleTopInset: CGFloat = 44
    static let buttonHeight: CGFloat = 52
    /// 立繪是 168×210 格的像素圖。框的寬高只能是它的整數倍，一格才會對到整數個點，
    /// 不然在部分機型上線條會粗細不一。小位置一格一個點，大的一格兩個點。
    static let portraitSize = CGSize(width: 168, height: 210)
    static let largePortraitSize = CGSize(width: 336, height: 420)
    /// 卡片陰影（domy elevation 1）
    static let shadowRadius: CGFloat = 9
    static let shadowY: CGFloat = 4
    static let shadowOpacity: Double = 0.06
    /// 境界頁的小提示與復原列離分頁列多遠（讓出「記一筆修煉」：按鈕 52、上面 8、下面 12）
    static let bannerBottomInset: CGFloat = 72
    /// 浮動膠囊按鈕（境界頁的「記一筆修煉」）：左右內距與陰影
    static let floatingButtonPadding: CGFloat = 28
    static let floatingShadowRadius: CGFloat = 12
    static let floatingShadowY: CGFloat = 6
    static let floatingShadowOpacity: Double = 0.22
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
    /// 換了造型就用 Assets 的 PortraitStyles 裡那張，名字是「r2-ink」這樣後面接造型代碼。
    static func name(realmIndex: Int, sex: Sex, style: PortraitStyle = .original) -> String {
        let prefix = sex == .female ? "gr" : "r"
        let highest = Tables.realms.count - 1
        let base = prefix + String(max(0, min(highest, realmIndex)))
        return style == .original ? base : base + "-" + style.rawValue
    }

    /// 境界碑上會動的立繪：一張 12 欄 × 8 列的格子圖，由左到右、由上到下共 96 格。
    /// 一格播 0.15 秒（一輪 14.4 秒），是多米定版的速度；圖本身不管速度，眨眼已經畫在格子裡。
    static let animationColumns = 12
    static let animationRows = 8
    static let animationFrameSeconds: Double = 0.15

    /// 某個大境界的動畫格子圖：靜態立繪的名字後面加 Anim（原版 r2Anim、造型 r2-inkAnim）。
    /// 十一種付費造型的動畫是組塊 M2 由 make_style_anims.py 從原版動畫逐格換色做的。
    static func animationName(realmIndex: Int, sex: Sex, style: PortraitStyle) -> String {
        name(realmIndex: realmIndex, sex: sex, style: style) + "Anim"
    }
}

/// 立繪造型：原版免費，另外十一種是付費造型（.vibe/付費造型計畫.md）。
/// 代碼（rawValue）同時是 Assets 圖名的後綴、make_styles.py 的風格名、存在 UserSettings 的值，三處要一致。
/// 組塊 M1 先讓每種都能直接選，還沒收錢。
enum PortraitStyle: String, CaseIterable, Identifiable {
    case original
    case ink
    case gold
    case moon
    case puppet
    case handheld
    case sticker
    case chunky
    case celadon
    case sunset
    case neon
    case jade

    var id: String { rawValue }

    /// 選造型頁格子下面的字
    var displayName: String {
        switch self {
        case .original: return "原版"
        case .ink: return "水墨"
        case .gold: return "鎏金"
        case .moon: return "月夜"
        case .puppet: return "皮影燈籠"
        case .handheld: return "掌機四色"
        case .sticker: return "貼紙"
        case .chunky: return "粗像素"
        case .celadon: return "青花瓷"
        case .sunset: return "赤霞夕照"
        case .neon: return "霓虹"
        case .jade: return "翠玉"
        }
    }
}
