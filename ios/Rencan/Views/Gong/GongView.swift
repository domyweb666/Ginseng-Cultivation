import RencanCore
import SwiftUI

/// 這一段自己的版面常數（數值照畫布 AnalysisGong）。
private enum Metrics {
    /// 功法卡排幾欄
    static let columnCount = 2
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
}

/// 分析頁的功法段（照畫布 AnalysisGong）：三格統計、六張功法卡排兩欄、最近修煉、等級怎麼算。
/// 放在 AnalysisView 的 ScrollView 裡，所以自己不捲動。數字全部來自 Digest，這裡只排版。
/// 一筆修煉都沒有時，三格是 0、六張卡寫「還沒有紀錄」，「最近修煉」那格換成一句說明。
struct GongView: View {
    let digest: Digest
    /// 全部的修煉紀錄；最近修煉自己挑最新的幾筆。
    let lifts: [LiftRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
            GongStats(digest: digest)
            moveCards
            RecentLiftsList(lifts: lifts, today: digest.today)
            GongRulesCard(sex: digest.sex)
        }
    }

    private var moveCards: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "六門功法")
                .padding(.horizontal, Metrics.titleInset)
            VStack(spacing: RencanLayout.groupSpacing) {
                ForEach(rowStarts, id: \.self) { start in
                    cardRow(from: start)
                }
            }
        }
    }

    /// 每一排第一張卡在 digest.moveCards 裡的位置（0、2、4）。
    private var rowStarts: [Int] {
        Array(stride(from: 0, to: digest.moveCards.count, by: Metrics.columnCount))
    }

    /// 一排兩張。fixedSize 讓這一排先量出最高那張的高度，再叫兩張都撐到那麼高。
    private func cardRow(from start: Int) -> some View {
        let end = min(start + Metrics.columnCount, digest.moveCards.count)
        return HStack(alignment: .top, spacing: RencanLayout.groupSpacing) {
            ForEach(digest.moveCards[start..<end], id: \.move.key) { card in
                MoveCardView(card: card)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
