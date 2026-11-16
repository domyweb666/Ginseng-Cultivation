import RencanCore
import SwiftData
import SwiftUI

/// app 起來要用到的東西：資料庫、改資料的服務、健康 app、通知。
@MainActor
struct AppServices {
    let container: ModelContainer
    let store: StoreService
    let health: HealthKitService
    let notifications: NotificationService

    /// 建本機資料庫（不開 iCloud，審核規範 5.1.3）。inMemory 給 UI 測試用，每次從乾淨狀態開始。
    /// app 與 Siri 要拿同一份，所以外面一律呼叫 shared()（Intents/IntentSupport.swift），不直接叫這個。
    static func make(inMemory: Bool) throws -> AppServices {
        let schema = Schema([Measurement.self, LiftRecord.self, UserSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = StoreService(context: container.mainContext)
        // 每次存檔成功就照最新的資料重寫小工具的快照（片 G1）。
        let bridge = WidgetBridge()
        let context = container.mainContext
        store.afterSave = {
            bridge.publish { try AppServices.digest(in: context) }
        }
        return AppServices(
            container: container, store: store, health: HealthKitService(),
            notifications: NotificationService()
        )
    }
}

/// 進入點。資料庫建不起來就顯示錯誤，不硬開一個空殼假裝正常。
@main
struct RencanApp: App {
    private let services: AppServices?
    @State private var flow = AppFlow()

    init() {
        var made: AppServices?
        do {
            made = try AppServices.shared()
            if let made {
                try UITestSupport.seedIfAsked(made)
                // 打開 app 就寫一次快照：剛裝好、剛更新、跨了一天，小工具都拿得到最新的。
                made.store.afterSave?()
                // 在這裡就開始聽：點通知把 app 叫起來那一下，畫面還沒出現也收得到。
                made.notifications.startListening()
            }
        } catch {
            made = nil
        }
        services = made
    }

    var body: some Scene {
        WindowGroup {
            mainContent
        }
    }

    @ViewBuilder private var mainContent: some View {
        if let services {
            RootTabView()
                .modelContainer(services.container)
                .environment(services.store)
                .environment(services.health)
                .environment(services.notifications)
                .environment(flow)
        } else {
            StartupErrorView()
        }
    }
}

/// 資料庫打不開時的畫面。
struct StartupErrorView: View {
    var body: some View {
        VStack(spacing: RencanLayout.itemSpacing) {
            Text("資料打不開")
                .font(RencanType.title3)
            Text("請把 app 關掉再開一次。還是不行的話，手機的儲存空間可能滿了。")
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(RencanLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rencan.canvas.ignoresSafeArea())
    }
}
