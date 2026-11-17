import RencanCore
import SwiftUI

/// 這張卡自己的版面常數（數值照畫布 AnalysisGong 最下面那張）。
private enum Metrics {
    /// 卡片的左右內距，卡片下面那行說明也縮這麼多
    static let cardInset: CGFloat = 16
    /// 展開時箭頭轉向下
    static let expandedChevronDegrees: Double = 90
}

/// 「功法等級怎麼算」（畫布 AnalysisGong 最下面）：一列可以點開的說明，下面常駐一句摘要。
/// 長相與點開的方式跟境界段的「境界怎麼算」（RealmRulesCard）一樣。
/// 點開後的兩段話照網頁版 index.html 的「功法等級怎麼算」；女性的門檻另外訂，換成女性那一句
/// （.vibe/女性版規則.md 第三節）。
struct GongRulesCard: View {
    let sex: Sex?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                toggleRow
                if isExpanded {
                    details
                }
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
            Text(summaryText)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .padding(.horizontal, Metrics.cardInset)
        }
    }

    private var toggleRow: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack(spacing: RencanLayout.groupSpacing) {
                Text("功法等級怎麼算")
                    .font(RencanType.body)
                    .foregroundStyle(Color.rencan.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(RencanType.footnote.weight(.semibold))
                    .foregroundStyle(Color.rencan.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? Metrics.expandedChevronDegrees : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: RencanLayout.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "已展開" : "已收合")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            Text(formulaText)
            Text(levelsText)
        }
        .font(RencanType.subheadline)
        .foregroundStyle(Color.rencan.textSecondary)
        .padding(.bottom, Metrics.cardInset)
    }

    /// 卡片底下常駐的那一句（畫布原文）。
    private var summaryText: String {
        let method = "每一筆都換算成 1RM，再除以當時體重。"
        return method + "未入門、入門、小成、大成、圓滿、化境，共六級。"
    }

    /// 1RM 怎麼估。除數跟規則引擎用同一個數字，改只改 Tables 一處。
    private var formulaText: String {
        let divisor = Formulas.fmt(Tables.epleyRepsDivisor, digits: 0)
        let method = "用你那組的重量和次數估算單次最大重量"
        let formula = "（1RM = 重量 ×（1 + 次數 ÷ \(divisor)）），"
        return method + formula + "再除以當天體重。引體向上、雙槓撐體把自身體重算進去。"
    }

    /// 六個等級與門檻的來歷。男性那句照網頁版；女性的係數照女性版規則第三節。
    private var levelsText: String {
        let ladder = "等級：" + Tables.levelNames.joined(separator: " → ")
        guard sex == .female else { return ladder + "，門檻參考一般成年男性的力量標準。" }
        let lower = "。女性的門檻另外訂：深蹲、前蹲、硬舉、羅馬尼亞硬舉是男性的七成，"
        let upper = "臥推、上斜臥推、肩推、划船、彎舉是六成，臀推跟男性一樣，"
        return ladder + lower + upper + "引體向上、雙槓撐體自重做得到一下就算入門。"
    }
}
