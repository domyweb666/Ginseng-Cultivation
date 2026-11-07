import SwiftUI

/// 功法頁。這片只有標題；六張功法卡在組塊 C 長肉。
struct GongView: View {
    var body: some View {
        ZStack {
            Color.rencan.background.ignoresSafeArea()
            VStack(spacing: RencanLayout.pageSpacing) {
                Text("功法")
                    .font(RencanType.pageTitle)
                    .foregroundStyle(Color.rencan.gold)
            }
            .padding()
        }
    }
}
