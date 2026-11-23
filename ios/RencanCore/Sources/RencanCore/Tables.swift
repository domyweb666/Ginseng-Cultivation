import Foundation

// 跟網頁版 index.html L203–230 一字不改的表：REALMS、STAGES、MOVES、LV、RANKS。
// 例外：渡劫的說明句（2026-11-23 從「自然人極限」改掉，Kouri 1995 的界線是 25）、
// FFMI 身高校正（2026-11-23 兩邊一起從 6.1 改 6.3）、
// RANKS 的境界門檻與後四階的說明句（2026-11-17 多米定的，只改 app、網頁版不動）。
// 網頁版是內門築基、真傳金丹、長老元嬰、太上長老化神；這裡各降一階，內門不看境界。
//
// 網頁版縮寫對照（規矩檔第 3 節：搬過來一律改成完整名）：
//   REALMS：n → name、lo → lowerFFMI、hi → upperFFMI、d → summary
//   MOVES：k → key、n → name、f → artName、th → thresholds、bw → usesBodyweight
//   RANKS：n → name、d → requiredDays、r → requiredRealmIndex、t → note
//   其他：bf → bodyFatPercent、lean → leanMassKg、hcm → heightCm、f → ffmi、bw → bodyweightKg

/// 大境界。FFMI 從 lowerFFMI（含）到 upperFFMI（不含）。
public struct Realm: Equatable {
    public let name: String
    public let lowerFFMI: Double
    public let upperFFMI: Double
    public let summary: String
}

/// 功法的代號，存檔與匯出入的 move 欄位用這個字。前六個跟網頁版同字；
/// 後六個是 2026-11-18 擴成十二門時加的（網頁版已停用，只有 app 認得）。
public enum MoveKey: String, CaseIterable {
    case squat
    case dead
    case bench
    case ohp
    case row
    case pull
    case frontSquat
    case romanianDeadlift
    case hipThrust
    case inclineBench
    case dip
    case curl
}

/// 功法分三排：腿、推、拉（2026-11-18 擴成十二門時多米定的），記一筆表單一排一組。
public enum MoveGroup: String, CaseIterable {
    case legs = "腿"
    case push = "推"
    case pull = "拉"
}

/// 一門功法：動作名、功法名、五階門檻（估計 1RM ÷ 體重）。
public struct Move: Equatable {
    public let key: MoveKey
    public let name: String
    public let artName: String
    public let thresholds: [Double]
    /// 女性的五階門檻（.vibe/女性版規則.md 第三節）。thresholds 是網頁版原本的男性門檻，不動。
    public let femaleThresholds: [Double]
    /// 引體向上、雙槓撐體這種要把自身體重算進負重的動作。
    public let usesBodyweight: Bool
    public let group: MoveGroup
}

/// 宗門身分的一階：要幾天修煉、要到哪個大境界。
public struct Rank: Equatable {
    public let name: String
    public let requiredDays: Int
    /// 要求的大境界序號；-1 代表不看境界。
    public let requiredRealmIndex: Int
    public let note: String
}

public enum Tables {
    /// 體脂率門檻（%）：高於這個值境界顯示「根基不穩」，突破與宗門只採計穩固的（產品定稿）。
    public static let bodyFatStableThresholdPercent: Double = 20

    /// 女性的體脂率門檻（%）。依據 ACE 體脂分級，男性 20% 對過去是 27%（女性版規則第二節）。
    public static let femaleBodyFatStableThresholdPercent: Double = 27
    /// 體脂離門檻不到 2 個百分點算「根基浮動」（網頁版的 18）。
    public static let bodyFatWaveringBandPercent: Double = 2
    /// 女性換算的兩個對齊點（女性版規則第一節）：一般人 FFMI 正常範圍下緣、自然訓練極限。
    public static let maleBaselineFFMI = 16.7
    public static let femaleBaselineFFMI = 14.6
    public static let maleCeilingFFMI: Double = 25
    public static let femaleCeilingFFMI: Double = 22

    /// 每一期的 FFMI 寬度（網頁版 realmOf 裡的 0.5）。
    public static let stageWidthFFMI = 0.5
    /// FFMI 身高校正：每公尺 6.3，以 1.8 公尺為基準（Kouri 1995 原文）。
    /// 2026-11-23 之前是 6.1，來源查不到；送審要附出處，改成論文的數字，網頁版一起改。
    public static let ffmiHeightCorrectionPerMeter = 6.3
    public static let ffmiReferenceHeightMeters = 1.8
    /// Epley 估計 1RM：重量 ×（1 + 次數 ÷ 30）。
    public static let epleyRepsDivisor: Double = 30
    /// 還沒有任何穩固量測時的大境界序號（網頁版 realmMax 回 -1）。
    public static let noRealmIndex = -1

    // 表單、Siri、匯入共用的合理範圍，跟網頁版表單的 min、max 一樣（index.html L462–489）。
    public static let weightRangeKg = 30.0...200.0
    public static let bodyFatRangePercent = 3.0...60.0
    public static let leanMassRangeKg = 20.0...150.0
    public static let heightRangeCm = 120.0...230.0
    public static let repsRange = 1...50
    public static let setsRange = 1...20

    public static let stages = ["初期", "中期", "後期"]
    public static let levelNames = ["未入門", "入門", "小成", "大成", "圓滿", "化境"]

    public static let realms = [realm0, realm1, realm2, realm3, realm4, realm5, realm6]
    /// 照腿、推、拉排，每排四門；記一筆表單、功法卡、雷達圖都照這個順序。
    /// 分三行寫：多行陣列 swift-format 要尾逗號、SwiftLint 不准，單行就兩邊都過。
    public static let moves = legMoves + pushMoves + pullMoves
    private static let legMoves = [squat, frontSquat, romanianDeadlift, hipThrust]
    private static let pushMoves = [bench, inclineBench, ohp, dip]
    private static let pullMoves = [dead, row, pull, curl]
    public static let ranks = [rank0, rank1, rank2, rank3, rank4, rank5]

    private static let realm0 = Realm(
        name: "煉氣", lowerFFMI: 16.5, upperFFMI: 18, summary: "一般未訓練"
    )
    private static let realm1 = Realm(
        name: "築基", lowerFFMI: 18, upperFFMI: 19.5, summary: "有基礎"
    )
    private static let realm2 = Realm(
        name: "金丹", lowerFFMI: 19.5, upperFFMI: 21, summary: "看得出有在練"
    )
    private static let realm3 = Realm(
        name: "元嬰", lowerFFMI: 21, upperFFMI: 22.5, summary: "資深健身者"
    )
    private static let realm4 = Realm(
        name: "化神", lowerFFMI: 22.5, upperFFMI: 24, summary: "菁英"
    )
    private static let realm5 = Realm(
        name: "大乘", lowerFFMI: 24, upperFFMI: 25.5, summary: "天賦上限附近"
    )
    private static let realm6 = Realm(
        name: "渡劫", lowerFFMI: 25.5, upperFFMI: 27, summary: "飛升前的最後一關"
    )

    private static let squat = Move(
        key: .squat, name: "深蹲", artName: "坐馬樁", thresholds: [0.75, 1.0, 1.25, 1.5, 2.0],
        femaleThresholds: [0.525, 0.7, 0.875, 1.05, 1.4], usesBodyweight: false, group: .legs
    )
    private static let dead = Move(
        key: .dead, name: "硬舉", artName: "拔山式", thresholds: [1.0, 1.25, 1.5, 2.0, 2.5],
        femaleThresholds: [0.7, 0.875, 1.05, 1.4, 1.75], usesBodyweight: false, group: .pull
    )
    private static let bench = Move(
        key: .bench, name: "臥推", artName: "推山掌", thresholds: [0.5, 0.75, 1.0, 1.25, 1.5],
        femaleThresholds: [0.3, 0.45, 0.6, 0.75, 0.9], usesBodyweight: false, group: .push
    )
    private static let ohp = Move(
        key: .ohp, name: "肩推", artName: "托天式", thresholds: [0.35, 0.5, 0.65, 0.8, 1.0],
        femaleThresholds: [0.21, 0.3, 0.39, 0.48, 0.6], usesBodyweight: false, group: .push
    )
    private static let row = Move(
        key: .row, name: "划船", artName: "挽弓式", thresholds: [0.5, 0.75, 1.0, 1.25, 1.5],
        femaleThresholds: [0.3, 0.45, 0.6, 0.75, 0.9], usesBodyweight: false, group: .pull
    )
    private static let pull = Move(
        key: .pull, name: "引體向上", artName: "攀雲梯", thresholds: [1.03, 1.17, 1.33, 1.5, 1.67],
        femaleThresholds: [1.0, 1.1, 1.2, 1.33, 1.5], usesBodyweight: true, group: .pull
    )

    // 2026-11-18 擴成十二門加的六門。門檻怎麼來的寫在 .vibe/功法擴充草案.md：
    // 拿相近的舊功法乘 Strength Level 兩個動作在中級的比例，四捨五入到 0.05。
    // 女性照女性版規則，腿 ×0.7、推拉 ×0.6；臀推女性不打折（多米定的）；
    // 雙槓撐體跟引體向上一樣另訂，照次數換：男 3、8、12、18、25 下，女 1、3、6、10、15 下。
    private static let frontSquat = Move(
        key: .frontSquat, name: "前蹲", artName: "抱鼎樁",
        thresholds: [0.55, 0.7, 0.9, 1.05, 1.45],
        femaleThresholds: [0.385, 0.49, 0.63, 0.735, 1.015], usesBodyweight: false, group: .legs
    )
    private static let romanianDeadlift = Move(
        key: .romanianDeadlift, name: "羅馬尼亞硬舉", artName: "探海式",
        thresholds: [0.75, 0.95, 1.1, 1.5, 1.9],
        femaleThresholds: [0.525, 0.665, 0.77, 1.05, 1.33], usesBodyweight: false, group: .legs
    )
    private static let hipThrust = Move(
        key: .hipThrust, name: "臀推", artName: "架橋式",
        thresholds: [0.75, 1.0, 1.25, 1.5, 2.0],
        femaleThresholds: [0.75, 1.0, 1.25, 1.5, 2.0], usesBodyweight: false, group: .legs
    )
    private static let inclineBench = Move(
        key: .inclineBench, name: "上斜臥推", artName: "推月掌",
        thresholds: [0.4, 0.6, 0.8, 1.0, 1.2],
        femaleThresholds: [0.24, 0.36, 0.48, 0.6, 0.72], usesBodyweight: false, group: .push
    )
    private static let dip = Move(
        key: .dip, name: "雙槓撐體", artName: "撐柱式",
        thresholds: [1.1, 1.27, 1.4, 1.6, 1.83],
        femaleThresholds: [1.0, 1.1, 1.2, 1.33, 1.5], usesBodyweight: true, group: .push
    )
    private static let curl = Move(
        key: .curl, name: "槓鈴彎舉", artName: "捧丹手",
        thresholds: [0.25, 0.35, 0.5, 0.6, 0.7],
        femaleThresholds: [0.15, 0.21, 0.3, 0.36, 0.42], usesBodyweight: false, group: .pull
    )

    private static let rank0 = Rank(
        name: "雜役弟子", requiredDays: 0, requiredRealmIndex: -1,
        note: "挑水劈柴，先把宗門的路走熟"
    )
    private static let rank1 = Rank(
        name: "外門弟子", requiredDays: 8, requiredRealmIndex: -1,
        note: "名字已寫進宗門名冊"
    )
    private static let rank2 = Rank(
        name: "內門弟子", requiredDays: 24, requiredRealmIndex: -1,
        note: "修煉成了習慣，正式入了內門"
    )
    private static let rank3 = Rank(
        name: "真傳弟子", requiredDays: 50, requiredRealmIndex: 1,
        note: "築基有成，宗門重點栽培"
    )
    private static let rank4 = Rank(
        name: "長老", requiredDays: 150, requiredRealmIndex: 2,
        note: "結成金丹，坐鎮一方"
    )
    private static let rank5 = Rank(
        name: "太上長老", requiredDays: 300, requiredRealmIndex: 3,
        note: "元嬰已成，宗門底蘊"
    )
}
