import SwiftUI

/// 錄入頁。這片只有標題；今天的修煉清單與表單在組塊 C 長肉。
struct LogView: View {
    var body: some View {
        ZStack {
            Color.rencan.background.ignoresSafeArea()
            VStack(spacing: RencanLayout.pageSpacing) {
                Text("錄入")
                    .font(RencanType.pageTitle)
                    .foregroundStyle(Color.rencan.gold)
            }
            .padding()
        }
    }
}
