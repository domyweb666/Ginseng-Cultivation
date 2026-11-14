import SwiftUI

/// 境界頁（中頁）。外框照 domy 金棕畫布：頂端齒輪／境界／分析圖示、境界碑、底部「記一筆修煉」。
/// 還沒有資料層，境界碑先顯示「還沒量過」的樣子；體組成來源列、三格天數、今天的修煉、
/// 記一筆表單在組塊 C、D 長肉（照畫布 Main 與 RealmEmpty 兩張）。
struct RealmView: View {
    @Binding var page: RencanPage

    var body: some View {
        ScrollView {
            VStack(spacing: RencanLayout.sectionSpacing) {
                header
                realmStele
            }
            .padding(.horizontal, RencanLayout.screenMargin)
        }
        .safeAreaInset(edge: .bottom) { logButton }
    }

    /// 左齒輪、右分析圖示：左右滑的看得見替身（標準清單 A2）。
    private var header: some View {
        HStack {
            PageIconButton(page: $page, target: .settings, systemImage: "gearshape", label: "設定")
            Spacer()
            Text("境界")
                .font(RencanType.realmHeader)
                .foregroundStyle(Color.rencan.strong)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            PageIconButton(
                page: $page, target: .analysis, systemImage: "chart.xyaxis.line", label: "分析")
        }
    }

    /// 境界碑的空狀態：雜役服立繪＋一句說明。
    private var realmStele: some View {
        VStack(spacing: RencanLayout.itemSpacing) {
            Image(RencanPortrait.servant)
                .resizable()
                .scaledToFill()
                .frame(
                    width: RencanLayout.portraitSize.width,
                    height: RencanLayout.portraitSize.height
                )
                .background(Color.rencan.tint)
                .clipShape(RoundedRectangle(cornerRadius: RencanLayout.portraitCornerRadius))
                .accessibilityLabel("雜役服人蔘立繪")
            Text("還沒量過體組成")
                .font(RencanType.title3)
            Text("量完體重和體脂率，境界會算在這裡。")
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .rencanCard(cornerRadius: RencanLayout.heroCornerRadius)
    }

    /// 核心動作的入口，固定在底部、頁點上方。表單在組塊 D 接上，這片先只有按鈕。
    private var logButton: some View {
        Button {
            // 記一筆表單在組塊 D 接上
        } label: {
            Label("記一筆修煉", systemImage: "plus")
        }
        .buttonStyle(RencanPrimaryButtonStyle())
        .padding(.horizontal, RencanLayout.screenMargin)
        .padding(.top, RencanLayout.itemSpacing)
        .background(Color.rencan.canvas)
    }
}
