import RencanCore
import SwiftUI

private enum Metrics {
    /// 底下那排身分只寫前兩個字（雜役、外門、內門、真傳、長老、太上）。
    static let shortNameLength = 2
}

/// 宗門卡：身分、說明、升下一階的進度、下一步，底下六個身分排一排、標出現在的。
/// 文字與百分比都是 Formulas.sectOf 算好的（digest.sect），這裡只排版。
struct SectCard: View {
    let sect: SectStatus

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.groupSpacing) {
            identity
            ProgressBar(percent: sect.progressPercent)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progressLabel)
            Text(sect.next)
                .font(RencanType.subheadline)
            RowDivider()
            rankRow
        }
        .rencanCard(cornerRadius: RencanLayout.heroCornerRadius)
        .accessibilityIdentifier("sectCard")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("宗門身分")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            Text(sect.title)
                .font(RencanType.sectTitle)
                .foregroundStyle(Color.rencan.strong)
            Text(sect.note)
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressLabel: String {
        "宗門晉升進度 \(Formulas.fmt(sect.progressPercent, digits: 0))%"
    }

    private var rankRow: some View {
        HStack(spacing: RencanLayout.barGap) {
            ForEach(Tables.ranks.indices, id: \.self) { index in
                rankLabel(index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rankRowLabel)
    }

    /// 現在那一個用產品色膠囊包起來，字也加粗，不只靠顏色分。
    private func rankLabel(_ index: Int) -> some View {
        let isCurrent = index == sect.rankIndex
        return Text(shortName(index))
            .font(isCurrent ? RencanType.caption.weight(.semibold) : RencanType.caption)
            .foregroundStyle(isCurrent ? Color.rencan.onAccent : Color.rencan.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(RencanLayout.minimumTextScale)
            .frame(maxWidth: .infinity)
            .padding(.vertical, RencanLayout.chipVerticalPadding)
            .background {
                if isCurrent {
                    Capsule()
                        .fill(Color.rencan.accent)
                }
            }
    }

    private func shortName(_ index: Int) -> String {
        String(Tables.ranks[index].name.prefix(Metrics.shortNameLength))
    }

    private var rankRowLabel: String {
        let names = Tables.ranks.indices.map { shortName($0) }.joined(separator: "、")
        guard Tables.ranks.indices.contains(sect.rankIndex) else { return names }
        return "宗門六階：\(names)。現在是\(shortName(sect.rankIndex))"
    }
}
