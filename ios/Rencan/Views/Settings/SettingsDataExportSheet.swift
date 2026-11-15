import SwiftUI

/// 匯出好、等著分享的暫存檔，加上要顯示的筆數。
struct SettingsDataExportFile: Identifiable, Equatable {
    let url: URL
    let measurementCount: Int
    let liftCount: Int

    var id: URL { url }

    /// 「量測 3 筆、修煉 13 筆」
    var countsText: String {
        SettingsDataText.counts(measurements: measurementCount, lifts: liftCount)
    }
}

/// 匯出的最後一步（PRD S23）：先講這個檔案含身體數據，再交給系統的分享表單，
/// 由使用者選存到「檔案」或 AirDrop。這張表單自己不傳檔案、不連網。
struct SettingsDataExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let file: SettingsDataExportFile

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                summary
                    .padding(.horizontal, RencanLayout.screenMargin)
                    .padding(.bottom, RencanLayout.sectionSpacing)
            }
            ShareLink(item: file.url) {
                Text("分享檔案")
            }
            .buttonStyle(RencanPrimaryButtonStyle())
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.vertical, RencanLayout.itemSpacing)
            .accessibilityIdentifier("export-share")
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// 跟其他彈出表單同一個長相的標題列（SheetHeader）。那一個關的是 AppFlow 的表單，
    /// 這張表單是設定頁自己開的，所以另外寫，用系統的 dismiss 關。
    private var header: some View {
        ZStack {
            Text("匯出紀錄")
                .font(RencanType.headline)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("關閉") {
                    dismiss()
                }
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.strong)
                .frame(minHeight: RencanLayout.tapTarget)
                Spacer()
            }
        }
        .padding(.horizontal, RencanLayout.screenMargin)
        .padding(.top, RencanLayout.sectionSpacing)
        .padding(.bottom, RencanLayout.itemSpacing)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: RencanLayout.groupSpacing) {
            Text(file.countsText)
                .font(RencanType.title3)
                .accessibilityIdentifier("export-summary")
            Text(file.url.lastPathComponent)
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
            Text(SettingsDataText.exportReminder)
                .font(RencanType.subheadline)
                .modifier(HintPanel())
                .accessibilityIdentifier("export-reminder")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
