import RencanCore
import SwiftUI

private enum Metrics {
    /// 沒有陰影的白卡左右內距（畫布 16）
    static let cardPadding: CGFloat = 16
    /// 展開時箭頭轉向下
    static let expandedChevronDegrees: Double = 90
}

/// 「境界怎麼算」：一列可以點開的說明，底下一句摘要（畫布 AnalysisRealm）。
/// 點開後的段落照網頁版 index.html L395–400；門檻數字從 Tables 與 Sex 拿，男女寫法不同。
struct RealmRulesCard: View {
    let sex: Sex
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                toggleRow
                if isExpanded {
                    details
                }
            }
            .padding(.horizontal, Metrics.cardPadding)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
            Text(summary)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .padding(.horizontal, Metrics.cardPadding)
        }
    }

    private var toggleRow: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack(spacing: RencanLayout.groupSpacing) {
                Text("境界怎麼算")
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
            Text(formulaNote)
            Text(scaleNote)
            Text(sectNote)
            Text(guestNote)
        }
        .font(RencanType.subheadline)
        .foregroundStyle(Color.rencan.textSecondary)
        .padding(.bottom, Metrics.cardPadding)
    }

    private var stageWidth: String {
        Formulas.fmt(Tables.stageWidthFFMI, digits: 1)
    }

    private var bodyFatLimit: String {
        Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
    }

    /// 卡片底下那一句。男性照畫布；女性的每期寬度換算後不是整數，改請她看天梯上的數字。
    private var summary: String {
        let gate = "體脂超過 \(bodyFatLimit)% 算根基不穩，那次量測不算突破。"
        switch sex {
        case .male:
            return "境界看 FFMI，每 \(stageWidth) 分一期。標準只有一張男性表；" + gate
        case .female:
            return "境界看 FFMI。標準只有一張男性表，女性的 FFMI 會先換算再查，門檻看天梯；" + gate
        }
    }

    private var formulaNote: String {
        let base = "境界看 FFMI（去脂體重 ÷ 身高²，再依身高校正），只算肌肉，不被脂肪灌水。"
        switch sex {
        case .male:
            return base + "每個大境界分初、中、後期，每期 \(stageWidth)，約等於 1.5 公斤肌肉。"
        case .female:
            return base + "每個大境界分初、中、後期。"
        }
    }

    private var scaleNote: String {
        "體脂秤誤差大，建議每月固定一天，早上起床如廁後、空腹量，看趨勢不看單次。"
    }

    private var sectNote: String {
        "宗門身分同時看修煉天數（有記錄訓練的日子）和曾達到的最高境界："
            + "內門要築基、真傳要金丹、長老要元嬰、太上長老要化神。"
    }

    private var guestNote: String {
        "實力夠但天數不夠，先當客卿；天數超過 100 天但境界還沒跟上，會成為執事。"
            + "量測偶爾失準掉下來，身分也不會降。"
    }
}
