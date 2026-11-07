import SwiftUI

/// 境界頁（中頁）。這片只有標題、兩個換頁入口與雜役服立繪；
/// 境界碑、體組成來源列、三格天數、今天的修煉、記一筆在組塊 C、D 長肉。
struct RealmView: View {
    @Binding var page: RencanPage

    var body: some View {
        ZStack {
            Color.rencan.background.ignoresSafeArea()
            VStack(spacing: RencanLayout.pageSpacing) {
                header
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

    /// 左齒輪、右分析圖示：左右滑的看得見替身（標準清單 A2）。
    private var header: some View {
        HStack {
            pageButton(to: .settings, systemImage: "gearshape", label: "設定")
            Spacer()
            Text("境界")
                .font(RencanType.pageTitle)
                .foregroundStyle(Color.rencan.gold)
            Spacer()
            pageButton(to: .analysis, systemImage: "chart.xyaxis.line", label: "分析")
        }
    }

    private func pageButton(to target: RencanPage, systemImage: String, label: String) -> some View {
        Button {
            withAnimation { page = target }
        } label: {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: RencanLayout.tapTarget, height: RencanLayout.tapTarget)
        }
        .accessibilityLabel(label)
    }
}
