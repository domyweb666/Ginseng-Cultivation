import Foundation
import SwiftUI

/// 這一頁自己的版面常數
private enum Metrics {
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
}

/// 「計算依據與出處」：最上面一塊醫療提醒，下面一個主題一段，說明加可點的連結。
/// 標題列與「關閉」由外面那層 NavigationStack 給（設定頁用 AboutPageSheet，其他地方用 HealthSourcesRow）。
struct HealthSourcesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                Text(HealthSourcesText.disclaimer)
                    .font(RencanType.subheadline)
                    .modifier(HintPanel())
                    .accessibilityIdentifier("health-sources-disclaimer")
                ForEach(HealthSourceTopic.all) { topic in
                    section(topic)
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.vertical, RencanLayout.sectionSpacing)
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .navigationTitle(HealthSourcesText.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ topic: HealthSourceTopic) -> some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: topic.title)
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                Text(topic.note)
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, RencanLayout.groupSpacing)
                ForEach(topic.sources) { source in
                    RowDivider()
                    HealthSourceLink(source: source)
                }
            }
            .padding(.horizontal, Metrics.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }
}

/// 一筆出處：論文標題、出處，右邊一個往外的箭頭。點了用瀏覽器打開。
private struct HealthSourceLink: View {
    let source: HealthSource

    var body: some View {
        if let url = URL(string: source.address) {
            Link(destination: url) {
                label
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("health-source-link")
        }
    }

    private var label: some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
                Text(source.title)
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.strong)
                Text(source.detail)
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(RencanType.footnote.weight(.semibold))
                .foregroundStyle(Color.rencan.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, RencanLayout.groupSpacing)
        .frame(minHeight: RencanLayout.tapTarget)
        .contentShape(Rectangle())
    }
}

/// 打開出處頁的那一列：輸入體組成、境界怎麼算、功法等級怎麼算三處共用。
/// 底與左右內距由外面給。自己帶一張表單，輸入體組成那張表單開著時也疊得上去，關掉還在原地。
struct HealthSourcesRow: View {
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            HStack(spacing: RencanLayout.groupSpacing) {
                Text(HealthSourcesText.title)
                    .font(RencanType.body)
                    .foregroundStyle(Color.rencan.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(RencanType.footnote.weight(.semibold))
                    .foregroundStyle(Color.rencan.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: RencanLayout.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("health-sources")
        .sheet(isPresented: $isShowing) {
            HealthSourcesSheet()
        }
    }
}

/// 出處頁包一層導覽，左上角「關閉」。
private struct HealthSourcesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HealthSourcesView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("關閉") {
                            dismiss()
                        }
                        .foregroundStyle(Color.rencan.strong)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}
