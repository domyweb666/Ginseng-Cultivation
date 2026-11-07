import SwiftUI

/// 三頁哪一頁。順序就是左右滑的順序：設定在左、境界在中、分析在右。
/// 深連結（通知、小工具、Siri）只准帶這三個值（標準清單 I2）。
enum RencanPage: Int, CaseIterable {
    case settings
    case realm
    case analysis
}

/// 三頁左右滑，預設停在境界（.uiux/02-流程.md，2026-11-07 定案；原本是分頁列三分頁）。
/// 用 TabView 的 page 樣式而不是自己寫手勢：系統頁點、VoiceOver 的頁數播報都免費拿到。
/// 左右滑是隱藏手勢，所以每頁都留看得見的入口：境界頁的齒輪與分析圖示、側頁的回境界箭頭。
struct RootTabView: View {
    @State private var page: RencanPage = .realm

    var body: some View {
        TabView(selection: $page) {
            SettingsView(page: $page)
                .tag(RencanPage.settings)
            RealmView(page: $page)
                .tag(RencanPage.realm)
            AnalysisView(page: $page)
                .tag(RencanPage.analysis)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .background(Color.rencan.background.ignoresSafeArea())
        .tint(Color.rencan.jade)
    }
}

/// 側頁共用的「回境界」按鈕。標籤固定「回境界」，Limrun 自驗腳本靠它找元件。
struct BackToRealmButton: View {
    @Binding var page: RencanPage
    let edge: HorizontalEdge

    var body: some View {
        Button {
            withAnimation { page = .realm }
        } label: {
            Image(systemName: edge == .leading ? "chevron.left" : "chevron.right")
                .font(.title3)
                .frame(width: RencanLayout.tapTarget, height: RencanLayout.tapTarget)
        }
        .accessibilityLabel("回境界")
    }
}
