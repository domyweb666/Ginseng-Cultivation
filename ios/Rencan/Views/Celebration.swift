import Foundation
import RencanCore

/// 全螢幕慶祝要顯示的內容。判定（哪一種）由 RencanCore 的 Judgement 決定，
/// 這裡只把判定結果寫成畫面上的字，文案照網頁版 index.html 的 celebrate 呼叫與設計畫布 Celebrate。
struct Celebration: Identifiable, Equatable {
    let id = UUID()
    /// 最上面那行小字：踏入仙途、境界突破、大境界突破、宗門晉升、第一筆修煉、功法突破、
    /// 功法精進、回來修煉。
    let heading: String
    /// 立繪的資源名；記修煉的慶祝只有宗門晉升有圖。
    let portrait: String?
    /// 大字：境界名、宗門身分、等級名、引氣入體、精進、出關。
    let title: String
    /// 大字旁邊的小一號字：期別。
    let stage: String?
    /// 大字下面的說明，一行一句。
    let lines: [String]
    /// 粒子數，照網頁版各種慶祝的數量。
    let particleCount: Int

    static func == (lhs: Celebration, rhs: Celebration) -> Bool {
        lhs.id == rhs.id
    }
}

extension Celebration {
    /// 記一筆修煉之後要不要放煙火。開練與修煉 +1 回 nil，改用小提示。
    static func make(for judgement: LiftJudgement, move: Move) -> Celebration? {
        let moveText = "\(move.artName)・\(move.name)"
        let daysText = "累計修煉 \(judgement.trainDaysAfter) 天"
        // 不是出關時是空字串，畫面不佔位置。
        let returnText = judgement.isReturn ? "出關後的第一筆" : ""
        switch judgement.outcome {
        case .sectPromotion:
            let extra = promotionText(judgement, move: move)
            return Celebration(
                heading: "宗門晉升", portrait: RencanPortrait.elder,
                title: judgement.sectAfter.title, stage: nil,
                lines: [daysText, extra, returnText], particleCount: 150
            )
        case .firstLift:
            return Celebration(
                heading: "第一筆修煉", portrait: nil, title: "引氣入體", stage: nil,
                lines: [moveText, daysText, firstLevelText(judgement.level)], particleCount: 120
            )
        case .levelUp:
            let strength = strengthText(judgement.calc, move: move)
            return Celebration(
                heading: "功法突破", portrait: nil,
                title: Tables.levelNames[judgement.level ?? 0], stage: nil,
                lines: [moveText, strength, returnText], particleCount: 130
            )
        case .personalBest:
            let record = recordText(judgement, move: move)
            return Celebration(
                heading: "功法精進", portrait: nil, title: "精進", stage: nil,
                lines: [moveText, record, returnText], particleCount: 90
            )
        case .returned:
            return Celebration(
                heading: "回來修煉", portrait: nil, title: "出關", stage: nil,
                lines: [daysText, moveText], particleCount: 120
            )
        case .firstRecord, .logged:
            return nil
        }
    }

    /// 記一筆修煉之後的小提示（開練、修煉 +1）。
    static func toast(for judgement: LiftJudgement, move: Move) -> String {
        if judgement.outcome == .firstRecord, let level = judgement.level {
            return "\(move.artName)開練，目前\(Tables.levelNames[level])"
        }
        if judgement.calc == nil {
            return "已記下\(move.artName)，修煉 +1。量過體重才算得出等級"
        }
        return "已記下\(move.artName)，修煉 +1"
    }

    /// 量一次體組成之後要不要放煙火。根基不穩與結算回 nil，改用小提示。
    static func make(
        for judgement: MeasurementJudgement, sex: Sex, style: PortraitStyle
    ) -> Celebration? {
        let standing = judgement.standing
        // 境界照最近三次的平均算，慶祝寫那個數字，跟突破紀錄同一個。
        let ffmi = "FFMI \(Formulas.fmt(judgement.averageFFMI, digits: 2))"
        var lines: [String] = []
        let heading: String
        let particleCount: Int
        switch judgement.outcome {
        case .enteredPath:
            heading = "踏入仙途"
            particleCount = 120
            lines.append(ffmi + "，修煉從今天開始")
        case .breakthrough, .majorBreakthrough:
            let isMajor = judgement.outcome == .majorBreakthrough
            heading = isMajor ? "大境界突破" : "境界突破"
            particleCount = isMajor ? 240 : 140
            let days = Formulas.durTxt(days: judgement.daysSincePrevious ?? 0)
            lines.append(ffmi + "・距上一階 " + days)
        case .unstable, .settled:
            return nil
        }
        lines.append(standing.realm.summary)
        if let title = judgement.promotedSectTitle {
            lines.append("宗門身分晉升為\(title)")
        }
        return Celebration(
            heading: heading,
            portrait: RencanPortrait.name(
                realmIndex: standing.realmIndex, sex: sex, style: style
            ),
            title: standing.realm.name, stage: Tables.stages[standing.stageIndex], lines: lines,
            particleCount: particleCount
        )
    }

    /// 量一次體組成之後的小提示（根基不穩、結算）。
    static func toast(for judgement: MeasurementJudgement, sex: Sex) -> String {
        let label = judgement.standing.label
        guard judgement.outcome == .unstable else { return "境界結算：" + label }
        let limit = Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
        return "境界結算：\(label)（體脂超過 \(limit)%，暫不認證）"
    }

    /// 宗門晉升的第二行：同一筆也突破或破紀錄就講那個，沒有就是新身分的說明。
    private static func promotionText(_ judgement: LiftJudgement, move: Move) -> String {
        if judgement.isLevelUp, let level = judgement.level {
            return "\(move.artName)也同時突破至\(Tables.levelNames[level])"
        }
        guard judgement.gainKg == nil else { return "\(move.artName)也破了紀錄" }
        return judgement.sectAfter.note
    }

    /// 引氣入體的最後一行。
    private static func firstLevelText(_ level: Int?) -> String {
        guard let level else { return "量過體重才算得出等級" }
        return "目前\(Tables.levelNames[level])"
    }

    /// 功法精進破了多少。從沒量過體重的人沒有比值可寫，只寫多幾公斤。
    private static func recordText(_ judgement: LiftJudgement, move: Move) -> String {
        var gainText = ""
        if !move.usesBodyweight, let gainKg = judgement.gainKg {
            gainText = "比歷來最高多 \(Formulas.fmt(gainKg, digits: 1)) 公斤"
        }
        guard let calc = judgement.calc else { return "估計 1RM " + gainText }
        let record = "新紀錄：" + strengthText(calc, move: move)
        return gainText.isEmpty ? record : record + "，" + gainText
    }

    private static func strengthText(_ calc: LiftCalc?, move: Move) -> String {
        guard let calc else { return "" }
        let ratio = Formulas.fmt(calc.ratio, digits: 2)
        if move.usesBodyweight {
            return "相當於 \(ratio) 倍體重的拉力"
        }
        let oneRepMax = Formulas.fmt(calc.estimatedOneRepMaxKg, digits: 0)
        return "估計 1RM \(oneRepMax) 公斤，\(ratio) 倍體重"
    }
}
