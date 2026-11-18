import SwiftData
import SwiftUI

/// 這一區自己的版面常數（數值跟 SettingsView 的一樣，照畫布 Settings）。
private enum Metrics {
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
}

/// 設定頁的「立繪造型」區（組塊 M1，2026-11-18 多米定入口放設定頁）：
/// 一列寫著現在用哪個造型，點了打開選造型頁（PortraitStyleView）。
/// 自己不包 ScrollView、不加左右邊距，由 SettingsView 排進去。
struct SettingsStyleSection: View {
    @Environment(AppFlow.self) private var flow
    @Environment(PurchaseService.self) private var purchases
    @Query private var settingsRows: [UserSettings]

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "立繪造型")
                .padding(.horizontal, Metrics.titleInset)
            Button {
                flow.sheet = .portraitStyle
            } label: {
                row
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
            .accessibilityHint("打開選造型的頁面")
            .accessibilityIdentifier("settings-portrait-style")
        }
    }

    /// 存的造型沒買（或退款了）就寫原版，跟境界碑上看到的一樣。
    private var style: PortraitStyle {
        purchases.effective(settingsRows.first?.portraitStyle ?? .original)
    }

    /// 左邊「目前的造型」、右邊造型名加小箭頭。箭頭只是裝飾，VoiceOver 不讀。
    /// 掛 `.buttonStyle(.plain)` 的理由同 SettingsAboutSection 的 linkRow（按鈕形狀會墊米色膠囊）。
    private var row: some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Text("目前的造型")
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.textPrimary)
            Spacer()
            Text(style.displayName)
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.textSecondary)
            Image(systemName: "chevron.right")
                .font(RencanType.footnote.weight(.semibold))
                .foregroundStyle(Color.rencan.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: RencanLayout.rowHeight)
        .contentShape(Rectangle())
    }
}
