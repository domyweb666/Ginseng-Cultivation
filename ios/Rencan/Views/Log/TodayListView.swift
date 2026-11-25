import RencanCore
import SwiftUI

/// 今天的修煉（住在境界頁）。點一筆進編輯；按住一筆跳出選單可以刪除，底部出現「復原」5 秒（PRD S15）。
/// 原本寫的是左滑刪除，但這一頁往左滑是換到分析頁，同方向的手勢會被換頁攔掉（2026-11-16 檢查線實測），
/// 所以改成按住。編輯表單裡也有刪除鈕，不會只有一條路。
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
                Text(emptyText)
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.textSecondary)
                    .rencanCard()
            } else {
                rows
            }
        }
    }

    /// 今天還沒記時的那句話。離上次滿 21 天的人回來，先看到累計的天數還在（2026-11-25 多米定），
    /// 不寫停了幾天。
    private var emptyText: String {
        guard digest.isReturnDue else { return "今天還沒記。練完記最重那一組就好，三十秒。" }
        return "你的 \(digest.trainDays) 天修煉都還在，練一門就出關。"
    }

    /// 一張卡，裡面一列一筆。
    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(lifts) { record in
                if record.uid != lifts.first?.uid {
                    RowDivider()
                }
                row(record)
            }
        }
        .padding(.horizontal, RencanLayout.cardPadding)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    /// 點一下進編輯，按住跳出選單（編輯、刪除）。
    private func row(_ record: LiftRecord) -> some View {
        Button {
            flow.sheet = .editLift(record)
        } label: {
            LiftRow(record: record) {
                if let entry = record.entry, let level = digest.level(of: entry) {
                    RencanChip(text: Tables.levelNames[level])
                }
            }
            .frame(minHeight: rowHeight)
        }
        .buttonStyle(.plain)
        .accessibilityHint("點一下編輯，按住可以刪除")
        .contextMenu {
            Button {
                flow.sheet = .editLift(record)
            } label: {
                Label("編輯", systemImage: "pencil")
            }
            Button(role: .destructive) {
                delete(record)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    private func delete(_ record: LiftRecord) {
        do {
            flow.undo = try store.delete(record)
        } catch {
            flow.showError(error)
        }
    }
}
