import SwiftUI

/// 三個分頁，預設停在境界（標準清單 A2）。深連結在小工具那塊才接。
struct RootTabView: View {
    var body: some View {
        TabView {
            RealmView()
                .tabItem { Label("境界", systemImage: "mountain.2") }
            GongView()
                .tabItem { Label("功法", systemImage: "figure.strengthtraining.traditional") }
            LogView()
                .tabItem { Label("錄入", systemImage: "square.and.pencil") }
        }
        .tint(Color.rencan.jade)
    }
}
