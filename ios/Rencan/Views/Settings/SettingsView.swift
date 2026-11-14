import SwiftUI

/// 設定頁（左頁）。外框照 domy 金棕畫布：左邊文楷大標題、右邊回境界箭頭。
/// 身高、健康 app 開關、提醒、匯出匯入、刪除全部在組塊 E、F、I 長肉（照畫布 Settings 那張）。
struct SettingsView: View {
    @Binding var page: RencanPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                HStack {
                    Text("設定")
                        .font(RencanType.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    BackToRealmButton(page: $page, edge: .trailing)
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
        }
    }
}
