import SwiftUI

/// 設定頁（左頁）。這片只有標題與回境界箭頭；身高、健康 app 開關、提醒、匯出匯入、刪除全部在組塊 E、F、I 長肉。
struct SettingsView: View {
    @Binding var page: RencanPage

    var body: some View {
        ZStack {
            Color.rencan.background.ignoresSafeArea()
            VStack(spacing: RencanLayout.pageSpacing) {
                HStack {
                    Spacer()
                        .frame(width: RencanLayout.tapTarget)
                    Spacer()
                    Text("設定")
                        .font(RencanType.pageTitle)
                        .foregroundStyle(Color.rencan.gold)
                    Spacer()
                    BackToRealmButton(page: $page, edge: .trailing)
                }
                Spacer()
            }
            .padding()
        }
    }
}
