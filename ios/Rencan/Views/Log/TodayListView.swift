import RencanCore
import SwiftUI

/// 今天的修煉（住在境界頁）。左滑刪除，底部出現「復原」5 秒；點一筆進編輯（PRD S15）。
/// 左滑是隱藏手勢，所以編輯表單裡也有刪除鈕，不會只有一條路。
struct TodayListView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    /// 一列的高度，跟著系統文字大小放大。
    @ScaledMetric private var rowHeight: CGFloat = 64
    let digest: Digest
    /// 今天記的修煉，照記的先後排。
    let lifts: [LiftRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "今天的修煉")
                .padding(.horizontal, RencanLayout.chipVerticalPadding)
            if lifts.isEmpty {
                Text("今天還沒記。練完記最重那一組就好，三十秒。")
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.textSecondary)
                    .rencanCard()
            } else {
                rows
            }
        }
    }

    /// 用 List 才有系統的左滑刪除。外面已經是 ScrollView，所以關掉它自己的捲動、高度寫死。
    private var rows: some View {
        List {
            ForEach(lifts) { record in
                LiftRow(record: record) {
                    if let entry = record.entry, let level = digest.level(of: entry) {
                        RencanChip(text: Tables.levelNames[level])
                    }
                }
                .frame(height: rowHeight)
                .listRowInsets(
                    EdgeInsets(
                        top: 0, leading: RencanLayout.cardPadding, bottom: 0,
                        trailing: RencanLayout.cardPadding
                    )
                )
                .listRowBackground(Color.rencan.surface)
                .listRowSeparatorTint(Color.rencan.separator)
                .onTapGesture {
                    flow.sheet = .editLift(record)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(record)
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .environment(\.defaultMinListRowHeight, 0)
        .frame(height: rowHeight * CGFloat(lifts.count))
        .clipShape(RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius))
    }

    private func delete(_ record: LiftRecord) {
        do {
            flow.undo = try store.delete(record)
        } catch {
            flow.showError(error)
        }
    }
}
