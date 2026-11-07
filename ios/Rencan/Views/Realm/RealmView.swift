import SwiftUI

/// 境界頁。這片只有標題與雜役服立繪；宗門卡、境界碑、天梯在組塊 D 長肉。
struct RealmView: View {
    var body: some View {
        ZStack {
            Color.rencan.background.ignoresSafeArea()
            VStack(spacing: RencanLayout.pageSpacing) {
                Text("境界")
                    .font(RencanType.pageTitle)
                    .foregroundStyle(Color.rencan.gold)
                Image(RencanPortrait.servant)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: RencanLayout.portraitMaxWidth)
                    .background(Color.rencan.scroll)
                    .clipShape(RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius))
                    .accessibilityLabel("雜役服人蔘立繪")
            }
            .padding()
        }
    }
}
