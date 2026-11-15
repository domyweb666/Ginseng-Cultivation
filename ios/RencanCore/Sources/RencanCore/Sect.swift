import Foundation

// 網頁版 index.html L234–249 的 sectOf，一行對一行搬過來（名稱對照見 Formulas.swift 檔頭）。
// 從 Formulas.swift 拆出來只因為 SwiftLint 一個檔最多 400 行；它仍是 Formulas 的一部分。

/// 宗門身分。
public struct SectStatus: Equatable {
    public let rankIndex: Int
    public let title: String
    public let note: String
    public let next: String
    public let progressPercent: Double
}

extension Formulas {
    /// RANKS 表裡的位置：內門弟子、真傳弟子、長老。
    private static let innerDiscipleRankIndex = 2
    private static let trueDiscipleRankIndex = 3
    private static let elderRankIndex = 4
    /// 修煉滿這麼多天、境界沒跟上，升執事。
    private static let stewardMinimumDays = 100
    /// 進度條最少畫這麼多，才看得到一點點。
    private static let minimumPercent: Double = 3
    private static let fullPercent: Double = 100

    /// 宗門身分：同時看修煉天數與曾到達的最高大境界。實力夠但天數不夠先當客卿，
    /// 天數超過 100 天但境界沒跟上是執事。
    public static func sectOf(trainDays: Int, realmIndex rawRealmIndex: Int) -> SectStatus {
        // 序號夾在表的範圍裡，離譜的輸入才不會查表查出界。
        let highestRealmIndex = Tables.realms.count - 1
        let realmIndex = max(Tables.noRealmIndex, min(highestRealmIndex, rawRealmIndex))
        let reached = Tables.ranks.lastIndex { rank in
            trainDays >= rank.requiredDays && realmIndex >= rank.requiredRealmIndex
        }
        let rankIndex = reached ?? 0
        if isGuest(of: elderRankIndex, rankIndex: rankIndex, realmIndex: realmIndex) {
            return guestStatus(
                title: "客卿長老", targetRankIndex: elderRankIndex, rankIndex: rankIndex,
                trainDays: trainDays, realmIndex: realmIndex
            )
        }
        if isGuest(of: trueDiscipleRankIndex, rankIndex: rankIndex, realmIndex: realmIndex) {
            return guestStatus(
                title: "客卿", targetRankIndex: trueDiscipleRankIndex, rankIndex: rankIndex,
                trainDays: trainDays, realmIndex: realmIndex
            )
        }
        return regularStatus(rankIndex: rankIndex, trainDays: trainDays, realmIndex: realmIndex)
    }

    /// 境界已經夠格當某一階（長老、真傳），但天數還沒到。
    private static func isGuest(of targetRankIndex: Int, rankIndex: Int, realmIndex: Int) -> Bool {
        let requiredRealmIndex = Tables.ranks[targetRankIndex].requiredRealmIndex
        return realmIndex >= requiredRealmIndex && rankIndex < targetRankIndex
    }

    private static func guestStatus(
        title: String, targetRankIndex: Int, rankIndex: Int, trainDays: Int, realmIndex: Int
    ) -> SectStatus {
        let target = Tables.ranks[targetRankIndex]
        let realmName = Tables.realms[realmIndex].name
        let percent = Double(trainDays) / Double(target.requiredDays) * fullPercent
        return SectStatus(
            rankIndex: rankIndex, title: title,
            note: "實力已達\(realmName)，以客卿身分入宗",
            next: "再修煉 \(target.requiredDays - trainDays) 天，轉為正式\(target.name)",
            progressPercent: max(minimumPercent, min(fullPercent, percent))
        )
    }

    private static func regularStatus(
        rankIndex: Int, trainDays: Int, realmIndex: Int
    ) -> SectStatus {
        let rank = Tables.ranks[rankIndex]
        guard rankIndex + 1 < Tables.ranks.count else {
            return SectStatus(
                rankIndex: rankIndex, title: rank.name, note: rank.note, next: "已是宗門最高位",
                progressPercent: fullPercent
            )
        }
        let nextRank = Tables.ranks[rankIndex + 1]
        var needs: [String] = []
        var percent = fullPercent
        if trainDays < nextRank.requiredDays {
            needs.append("再修煉 \(nextRank.requiredDays - trainDays) 天")
            let span = Double(nextRank.requiredDays - rank.requiredDays)
            let raw = Double(trainDays - rank.requiredDays) / span * fullPercent
            percent = max(minimumPercent, min(fullPercent, raw))
        }
        if realmIndex < nextRank.requiredRealmIndex {
            needs.append("突破至\(Tables.realms[nextRank.requiredRealmIndex].name)")
        }
        var title = rank.name
        var note = rank.note
        let isSenior = trainDays >= stewardMinimumDays && trainDays >= nextRank.requiredDays
        let isRealmBehind = realmIndex < nextRank.requiredRealmIndex
        if rankIndex <= innerDiscipleRankIndex && isSenior && isRealmBehind {
            title = (rankIndex == innerDiscipleRankIndex ? "內門" : "外門") + "執事"
            note = "修煉 \(trainDays) 天，資歷深厚，掌管宗門事務"
        }
        return SectStatus(
            rankIndex: rankIndex, title: title, note: note,
            next: needs.joined(separator: "、") + "，升\(nextRank.name)", progressPercent: percent
        )
    }
}
