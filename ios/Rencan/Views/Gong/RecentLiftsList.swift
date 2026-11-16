import SwiftUI

/// 這一塊自己的版面常數（數值照畫布 AnalysisGong 的「最近修煉」）。
private enum Metrics {
    /// 最多列幾筆（跟網頁版一樣）
    static let limit = 20
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
    /// 一列的最小高度與上下內距
    static let rowMinHeight: CGFloat = 60
    static let rowVerticalPadding: CGFloat = 10
}

/// 最近修煉（畫布 AnalysisGong）：最新的 20 筆，同一天的排在一起、新的在上，右邊寫日期。
/// 點一列進編輯（PRD S15）；刪除在編輯表單裡，這裡不做左滑。
struct RecentLiftsList: View {
    @Environment(AppFlow.self) private var flow
    let lifts: [LiftRecord]
    /// 今天的日期字串；日期欄靠它決定寫「今天」還是「11/10」。
    let today: String

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "最近修煉")
                .padding(.horizontal, Metrics.titleInset)
            if lifts.isEmpty {
                emptyState
            } else {
                rows(Array(RecentLiftsList.newestFirst(lifts).prefix(Metrics.limit)))
            }
        }
    }

    /// 一筆都沒有時：一張卡裡只有那句話，靠左。
    private var emptyState: some View {
        Text(emptyText)
            .font(RencanType.subheadline)
            .foregroundStyle(Color.rencan.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("gong-empty")
            .rencanCard()
    }

    /// 一筆都沒有時的那句話。網頁版叫人去「錄入」頁，這裡的入口是境界頁底下那顆按鈕。
    private var emptyText: String {
        let lead = "還沒有修煉紀錄。練完回境界頁按「記一筆修煉」，"
        return lead + "記最重那一組，功法就會開始累積。"
    }

    /// 日期新的在上；同一天的，後記的在上（網頁版 byDate 再反過來的順序）。
    /// 單一功法頁列全部紀錄時也用這個順序。
    static func newestFirst(_ lifts: [LiftRecord]) -> [LiftRecord] {
        lifts.sorted { left, right in
            (left.day, left.createdAt) > (right.day, right.createdAt)
        }
    }

    private func rows(_ recent: [LiftRecord]) -> some View {
        VStack(spacing: 0) {
            ForEach(recent) { record in
                if record.uid != recent.first?.uid {
                    RowDivider()
                }
                row(record)
            }
        }
        .padding(.horizontal, Metrics.cardInset)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private func row(_ record: LiftRecord) -> some View {
        Button {
            flow.sheet = .editLift(record)
        } label: {
            LiftRow(record: record) {
                Text(DayStamp.short(record.day, today: today))
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            .padding(.vertical, Metrics.rowVerticalPadding)
            .frame(minHeight: Metrics.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("編輯這一筆")
    }
}
