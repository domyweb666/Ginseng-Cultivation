import Foundation

// Siri 回的那一句話（組塊 H，PRD S17、S18）。句子在這裡組、在這裡測；
// App Intent 只負責取資料、存檔，再把這句交給 Siri，不自己拼字。
// 數字的寫法跟畫面同一套（Formulas.fmt）：1RM 寫整數、倍數與 FFMI 寫兩位、還差幾公斤肌肉寫一位。
// 重量的寫法跟清單那一列一樣：整數不寫小數點，引體向上寫「自重」或「自重加幾公斤」。
// 錯誤只回 RencanError 那一句，不夾數值（規矩檔第 4 節）。

public enum SiriReply {
    /// 還沒填身高、還沒選性別：境界與等級都算不出來，也不替他猜，請他先打開 app。
    public static let profileMissing = "還沒填身高和性別，先打開人蔘修煉填一下。"
    /// 還沒量過（PRD S18 的原句）。
    public static let notMeasured = "尚未入道，先量一次體組成。"

    // MARK: 記修煉

    /// 記下一筆之後回的話：記了什麼、這次是哪一種、估計 1RM、等級有沒有升。
    /// 沒升的時候說「這一組算某某」，不說「目前某某」：今天這組比較輕時，他的等級其實更高。
    public static func logged(
        _ judgement: LiftJudgement, move: Move, kg: Double, reps: Int, sets: Int
    ) -> String {
        let record = recordText(move: move, kg: kg, reps: reps, sets: sets)
        let head = "已記下\(record)，\(outcomeText(judgement))。"
        guard let calc = judgement.calc, let level = judgement.level else {
            return head + "量過體重才算得出等級。"
        }
        let levelName = Tables.levelNames[level]
        let levelText = judgement.isLevelUp ? "升到\(levelName)" : "這一組算\(levelName)"
        return head + "\(strengthText(calc, move: move))，\(levelText)。"
    }

    /// 沒記成時回的話。用 RencanError 那一句，絕不說已記下（PRD S24）。
    public static func logFailure(_ error: Error) -> String {
        if let known = error as? RencanError, known == .profileMissing { return profileMissing }
        return "這筆沒記下：\(RencanError.message(for: error))。"
    }

    // MARK: 問境界

    /// 問境界回的話。數字全部從 Digest 拿，跟境界碑是同一份。
    public static func realmStatus(_ digest: Digest) -> String {
        guard let sex = digest.sex, digest.heightCm != nil else { return profileMissing }
        guard let stele = digest.stele else { return notMeasured }
        let head = "\(stele.standing.label)，FFMI \(Formulas.fmt(stele.ffmi, digits: 2))"
        if case .unstable = stele.gate {
            let limit = Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
            let effect = stele.hasBreakthrough ? "才能再突破" : "境界才生效"
            return head + "。根基不穩，體脂降到 \(limit)% 以下\(effect)。"
        }
        guard let gap = stele.gap else { return head + "，已是最高的一期。" }
        let needed = Formulas.fmt(gap.leanNeededKg, digits: 1)
        return head + "，距\(gap.nextLabel)還差 \(needed) 公斤肌肉。"
    }

    /// 境界算不出來時回的話（例如某一筆的日期壞了）。
    public static func realmFailure(_ error: Error) -> String {
        guard let known = error as? RencanError else {
            return "資料讀不出來，先打開人蔘修煉看一下。"
        }
        return "資料讀不出來：\(known.message)。"
    }

    // MARK: 組句子

    /// 「坐馬樁 100 公斤 5 下」；超過一組才講組數；引體向上寫「攀雲梯自重 8 下」。
    private static func recordText(move: Move, kg: Double, reps: Int, sets: Int) -> String {
        var load = " \(kgText(kg)) 公斤"
        if move.usesBodyweight {
            load = kg == 0 ? "自重" : "自重加 \(kgText(kg)) 公斤"
        }
        let setsText = sets > 1 ? " \(sets) 組" : ""
        return "\(move.artName)\(load) \(reps) 下\(setsText)"
    }

    /// 公斤數：整數不寫小數點，62.5 這種寫一位（跟 app 清單的寫法一樣）。
    private static func kgText(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return Formulas.fmt(value, digits: isWhole ? 0 : 1)
    }

    /// 這次是哪一種，照判定規則白話表的五種結果。
    private static func outcomeText(_ judgement: LiftJudgement) -> String {
        switch judgement.outcome {
        case .sectPromotion:
            return "宗門晉升為\(judgement.sectAfter.title)"
        case .firstRecord:
            return "這門功法開練了"
        case .levelUp:
            return "功法突破"
        case .personalBest:
            return "功法精進"
        case .logged:
            return "修煉 +1"
        }
    }

    /// 引體向上講幾倍體重（1RM 含自己的體重，唸出來等於報體重），其他講估計 1RM。
    private static func strengthText(_ calc: LiftCalc, move: Move) -> String {
        if move.usesBodyweight {
            return "相當於 \(Formulas.fmt(calc.ratio, digits: 2)) 倍體重的拉力"
        }
        return "估計 1RM \(Formulas.fmt(calc.estimatedOneRepMaxKg, digits: 0)) 公斤"
    }
}
