import SwiftUI

/// 分析頁的功法段。這片只有一行說明；總覽、六張功法卡、最近修煉在組塊 C 長肉。
struct GongView: View {
    var body: some View {
        VStack(spacing: RencanLayout.pageSpacing) {
            Text("功法")
                .font(RencanType.pageTitle)
                .foregroundStyle(Color.rencan.gold)
            Spacer()
        }
    }
}
