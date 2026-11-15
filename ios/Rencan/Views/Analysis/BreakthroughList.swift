import RencanCore
import SwiftUI

private enum Metrics {
    /// 區塊標題比卡片往內縮一點（畫布 margin 0 4）
    static let titleInset: CGFloat = 4
    /// 沒有陰影的白卡左右內距（畫布 16）
    static let cardPadding: CGFloat = 16
    /// 一列的最小高度與上下內距（畫布 60、10）
    static let rowHeight: CGFloat = 60
    static let rowVerticalPadding: CGFloat = 10
}

/// 突破紀錄：每個第一次到達的期別一列，新的在上。哪幾筆算突破由 Formulas.breakthroughs 決定。
/// 還沒有任何一筆（量過但體脂都超過門檻）時整塊不顯示，跟網頁版一樣。
struct BreakthroughList: View {
    let breakthroughs: [Breakthrough]
    let today: String

    var body: some View {
        if !breakthroughs.isEmpty {
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                SectionTitle(text: "突破紀錄")
                    .padding(.horizontal, Metrics.titleInset)
                rows
            }
        }
    }

    private var rows: some View {
        let newestFirst = Array(breakthroughs.reversed())
        return VStack(spacing: 0) {
            ForEach(newestFirst.indices, id: \.self) { index in
                if index > 0 {
                    RowDivider()
                }
                row(newestFirst[index], isNewest: index == 0)
            }
        }
        .padding(.horizontal, Metrics.cardPadding)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private func row(_ record: Breakthrough, isNewest: Bool) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                Text(record.label)
                    .font(RencanType.termBody)
                    .foregroundStyle(isNewest ? Color.rencan.strong : Color.rencan.textPrimary)
                Text(detail(record))
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            Spacer(minLength: 0)
            Text("FFMI \(Formulas.fmt(record.ffmi, digits: 1))")
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
        }
        .padding(.vertical, Metrics.rowVerticalPadding)
        .frame(minHeight: Metrics.rowHeight)
        .accessibilityElement(children: .combine)
    }

    /// 「11 月 3 日・距上次 62 天」；第一筆寫「第一次量測」。天數照畫布直接寫幾天。
    private func detail(_ record: Breakthrough) -> String {
        let day = DayStamp.monthDay(record.date, today: today)
        guard !record.isFirst else { return "\(day)・第一次量測" }
        return "\(day)・距上次 \(record.daysSincePrevious) 天"
    }
}
