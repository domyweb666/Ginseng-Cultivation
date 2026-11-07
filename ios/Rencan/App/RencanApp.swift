import SwiftUI

/// 進入點。資料容器與服務注入在組塊 C 才接，這片只開三個左右滑的空頁。
@main
struct RencanApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
