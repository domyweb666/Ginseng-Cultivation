import Foundation

// 跟網頁版 index.html L203–230 一字不改的表：REALMS、STAGES、MOVES、LV、RANKS。
// 例外：RANKS 的境界門檻與後四階的說明句（2026-11-17 多米定的，只改 app、網頁版不動）。
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

/// 六門功法的代號，跟網頁版 JSON 的 move 欄位同字。
public enum MoveKey: String, CaseIterable {
    case squat
    case dead
    case bench
    case ohp
    case row
    case pull
}

/// 一門功法：動作名、功法名、五階門檻（估計 1RM ÷ 體重）。
public struct Move: Equatable {
    public let key: MoveKey
    public let name: String
    public let artName: String
    public let thresholds: [Double]
    /// 女性的五階門檻（.vibe/女性版規則.md 第三節）。thresholds 是網頁版原本的男性門檻，不動。
    public let femaleThresholds: [Double]
    /// 引體向上這種要把自身體重算進負重的動作。
    public let usesBodyweight: Bool
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
    /// 體脂離門檻不到 2 個百分點算「根基浮動」；比門檻低 10 個百分點以上算偏低（網頁版 18 與 10）。
    public static let bodyFatWaveringBandPercent: Double = 2
    public static let bodyFatLowBelowLimitPercent: Double = 10
    /// 女性換算的兩個對齊點（女性版規則第一節）：一般人 FFMI 正常範圍下緣、自然訓練極限。
    public static let maleBaselineFFMI = 16.7
    public static let femaleBaselineFFMI = 14.6
    public static let maleCeilingFFMI: Double = 25
    public static let femaleCeilingFFMI: Double = 22

    /// 每一期的 FFMI 寬度（網頁版 realmOf 裡的 0.5）。
    public static let stageWidthFFMI = 0.5
    /// FFMI 身高校正：每公尺 6.1，以 1.8 公尺為基準（網頁版 ffmi、leanFor）。
    public static let ffmiHeightCorrectionPerMeter = 6.1
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
    public static let moves = [squat, dead, bench, ohp, row, pull]
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
        name: "渡劫", lowerFFMI: 25.5, upperFFMI: 27, summary: "自然人極限"
    )

    private static let squat = Move(
        key: .squat, name: "深蹲", artName: "坐馬樁", thresholds: [0.75, 1.0, 1.25, 1.5, 2.0],
        femaleThresholds: [0.525, 0.7, 0.875, 1.05, 1.4], usesBodyweight: false
    )
    private static let dead = Move(
        key: .dead, name: "硬舉", artName: "拔山式", thresholds: [1.0, 1.25, 1.5, 2.0, 2.5],
        femaleThresholds: [0.7, 0.875, 1.05, 1.4, 1.75], usesBodyweight: false
    )
    private static let bench = Move(
        key: .bench, name: "臥推", artName: "推山掌", thresholds: [0.5, 0.75, 1.0, 1.25, 1.5],
        femaleThresholds: [0.3, 0.45, 0.6, 0.75, 0.9], usesBodyweight: false
    )
    private static let ohp = Move(
        key: .ohp, name: "肩推", artName: "托天式", thresholds: [0.35, 0.5, 0.65, 0.8, 1.0],
        femaleThresholds: [0.21, 0.3, 0.39, 0.48, 0.6], usesBodyweight: false
    )
    private static let row = Move(
        key: .row, name: "划船", artName: "挽弓式", thresholds: [0.5, 0.75, 1.0, 1.25, 1.5],
        femaleThresholds: [0.3, 0.45, 0.6, 0.75, 0.9], usesBodyweight: false
    )
    private static let pull = Move(
        key: .pull, name: "引體向上", artName: "攀雲梯", thresholds: [1.03, 1.17, 1.33, 1.5, 1.67],
        femaleThresholds: [1.0, 1.1, 1.2, 1.33, 1.5], usesBodyweight: true
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
