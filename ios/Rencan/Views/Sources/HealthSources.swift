import RencanCore

// 健康計算的說明與出處（2026-11-23 App Store 審查 1.4.1 要求）。
// 寫進來的數字都對過論文摘要或原文；沒有出處的就明說是 app 自己訂的，不掛不相干的論文。
// 論文標題照原文，審查員與使用者才對得上；連結寫死，不帶任何使用者的資料。

enum HealthSourcesText {
    static let title = "計算依據與出處"
    static let disclaimer =
        "這個 app 的數字和境界只供記錄與遊戲，不能用來診斷或治療，也不能取代醫師的建議。"
        + "要做健康相關的決定之前，或有慢性病、懷孕、身體不舒服，請先問醫師。"
}

/// 一筆出處：標題、期刊與年份、連結。
struct HealthSource: Identifiable {
    let title: String
    let detail: String
    let address: String

    var id: String { address }
}

/// 一個主題：講什麼、依據哪幾筆。
struct HealthSourceTopic: Identifiable {
    let title: String
    let note: String
    let sources: [HealthSource]

    var id: String { title }
}

extension HealthSourceTopic {
    static let all = [ffmi, realm, bodyFat, scale, oneRepMax, gong]

    private static let heightSlope = Formulas.fmt(Tables.ffmiHeightCorrectionPerMeter, digits: 1)
    private static let heightBase = Formulas.fmt(Tables.ffmiReferenceHeightMeters, digits: 1)
    private static let repsDivisor = Formulas.fmt(Tables.epleyRepsDivisor, digits: 0)

    private static let ffmi = HealthSourceTopic(
        title: "FFMI（去脂體重指數）",
        note: "FFMI = 去脂體重（公斤）÷ 身高（公尺）²，再加 \(heightSlope) ×（\(heightBase) − 身高）。"
            + "去脂體重是體重扣掉脂肪，包含肌肉、骨頭和水分；沒填的話用體重 ×（1 − 體脂率）算。"
            + "身高校正的 \(heightSlope) 來自男性運動員的研究，女性沿用同一個數字。",
        sources: [.kouri]
    )

    private static let realm = HealthSourceTopic(
        title: "境界門檻",
        note: "七個境界怎麼切是這個 app 自己訂的遊戲設定，沒有醫學意義。"
            + "用 \(Tables.realmAverageWindowDays) 天內最近 \(Tables.realmAverageCount) 次量測的"
            + "去脂體重平均、升上去不會掉，也是 app 訂的規則。"
            + "訂的時候參考了三個研究：沒用類固醇的男運動員 FFMI 最高約 25；"
            + "正常體重成人的 FFMI 下緣是男 16.7、女 14.6；女大學運動員的上緣是 23.9。"
            + "女性先換算成男性等值再查表，上限取比較保守的 22，這個數字也是 app 訂的。",
        sources: [.kouri, .kyle, .harty]
    )

    private static let bodyFat = HealthSourceTopic(
        title: "體脂率與根基",
        note: "體脂超過男 \(limit(.male))%、女 \(limit(.female))% 顯示根基不穩，這條線是 app 訂的遊戲規則。"
            + "參考的範圍有兩組：瑞士健康成人是男 13.4–21.7%、女 24.6–33.2%；"
            + "美國運動委員會（ACE）的一般人範圍是男 18–24%、女 25–31%。",
        sources: [.kyle, .ace]
    )

    private static let scale = HealthSourceTopic(
        title: "體脂秤的誤差與量法",
        note: "體脂秤用微弱電流推估，喝水、吃東西、運動和機型不同都會讓數字變動。"
            + "所以建議每次都在早上、如廁後、空腹時量，看一段時間的走勢，不看單次。",
        sources: [.tinsley, .kasper, .espen]
    )

    private static let oneRepMax = HealthSourceTopic(
        title: "估計 1RM",
        note: "1RM = 重量 ×（1 + 次數 ÷ \(repsDivisor)），叫 Epley 公式。這是估計值，"
            + "不要直接拿來當下一次要挑戰的重量。研究建議用 10 下以內的組來估，次數越多誤差越大。",
        sources: [.backSquat, .reynolds]
    )

    private static let gong = HealthSourceTopic(
        title: "功法等級門檻",
        note: "入門到化境的門檻是 app 訂的遊戲設定。深蹲、硬舉、臥推、肩推、划船、引體向上"
            + "是這個 app 一開始就有的數字，沒有對應的研究；另外六門參考 Strength Level 的"
            + "使用者紀錄換算。女性的門檻另外訂，多數是男性的六到七成。",
        sources: [.strengthLevel]
    )

    private static func limit(_ sex: Sex) -> String {
        Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
    }
}

extension HealthSource {
    fileprivate static let kouri = HealthSource(
        title: "Fat-free mass index in users and nonusers of anabolic-androgenic steroids",
        detail: "Kouri 等，Clin J Sport Med，1995",
        address: "https://pubmed.ncbi.nlm.nih.gov/7496846/"
    )
    fileprivate static let kyle = HealthSource(
        title: "Body composition interpretation: contributions of the fat-free mass index",
        detail: "Kyle 等，Nutrition，2003",
        address: "https://pubmed.ncbi.nlm.nih.gov/12831945/"
    )
    fileprivate static let harty = HealthSource(
        title: "Upper and lower thresholds of fat-free mass index in female collegiate athletes",
        detail: "Harty 等，J Sports Sci，2019",
        address: "https://pubmed.ncbi.nlm.nih.gov/31238804/"
    )
    fileprivate static let ace = HealthSource(
        title: "Body Fat Percentage: Charting Averages in Men and Women",
        detail: "American Council on Exercise 網站，2024",
        address: "https://www.acefitness.org/about-ace/press-room/in-the-news/8602/"
            + "body-fat-percentage-charting-averages-in-men-and-women-very-well-health/"
    )
    fileprivate static let tinsley = HealthSource(
        title: "Influence of Acute Water Ingestion and Prolonged Standing on Raw Bioimpedance",
        detail: "Tinsley 等，J Electr Bioimpedance，2022",
        address: "https://pmc.ncbi.nlm.nih.gov/articles/PMC9124033/"
    )
    fileprivate static let kasper = HealthSource(
        title: "Come Back Skinfolds, All Is Forgiven: A Narrative Review",
        detail: "Kasper 等，Nutrients，2021",
        address: "https://pmc.ncbi.nlm.nih.gov/articles/PMC8065383/"
    )
    fileprivate static let espen = HealthSource(
        title: "Bioelectrical impedance analysis, part II: utilization in clinical practice",
        detail: "Kyle 等，Clin Nutr（ESPEN 指引），2004",
        address: "https://pubmed.ncbi.nlm.nih.gov/15556267/"
    )
    /// 這篇講的是用動作速度估 1RM，引言列出 Epley 公式與它的準確度。
    fileprivate static let backSquat = HealthSource(
        title: "Accuracy of Predicting One-Repetition Maximum from Submaximal Velocity",
        detail: "Macarilla 等，J Hum Kinet，2022（引言列出 Epley 公式）",
        address: "https://pmc.ncbi.nlm.nih.gov/articles/PMC9465738/"
    )
    fileprivate static let reynolds = HealthSource(
        title: "Prediction of one repetition maximum strength from multiple repetition testing",
        detail: "Reynolds 等，J Strength Cond Res，2006",
        address: "https://pubmed.ncbi.nlm.nih.gov/16937972/"
    )
    fileprivate static let strengthLevel = HealthSource(
        title: "Strength Standards",
        detail: "Strength Level 網站，使用者自行回報的紀錄",
        address: "https://strengthlevel.com/strength-standards"
    )
}
