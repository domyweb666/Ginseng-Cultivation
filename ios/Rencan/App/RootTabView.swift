import SwiftUI

/// 三頁哪一頁。順序就是左右滑的順序：設定在左、境界在中、分析在右。
/// 深連結（通知、小工具、Siri）只准帶這三個值（標準清單 I2）。
enum RencanPage: Int, CaseIterable {
    case settings
    case realm
    case analysis
}

/// 三頁左右滑，預設停在境界（.uiux/02-流程.md，2026-11-07 定案；原本是分頁列三分頁）。
/// 用 TabView 的 page 樣式而不是自己寫手勢，滑動手感跟系統一樣。
/// 系統頁點在暖米白底上是白色看不見，所以關掉，改用底下自己畫的 PageDots（domy 金棕，2026-11-15）。
/// 左右滑是隱藏手勢，所以每頁都留看得見的入口：境界頁的齒輪與分析圖示、側頁的回境界箭頭。
struct RootTabView: View {
    @State private var page: RencanPage = .realm

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                SettingsView(page: $page)
                    .tag(RencanPage.settings)
                RealmView(page: $page)
                    .tag(RencanPage.realm)
                AnalysisView(page: $page)
                    .tag(RencanPage.analysis)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageDots(current: page)
                .padding(.vertical, RencanLayout.itemSpacing)
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .foregroundStyle(Color.rencan.textPrimary)
        .tint(Color.rencan.accent)
    }
}
