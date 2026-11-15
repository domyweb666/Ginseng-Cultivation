import RencanCore
import SwiftData
import SwiftUI

/// app 起來要用到的東西：資料庫與改資料的服務。
@MainActor
struct AppServices {
    let container: ModelContainer
    let store: StoreService

    /// 建本機資料庫（不開 iCloud，審核規範 5.1.3）。inMemory 給 UI 測試用，每次從乾淨狀態開始。
    static func make(inMemory: Bool) throws -> AppServices {
        let schema = Schema([Measurement.self, LiftRecord.self, UserSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = StoreService(context: container.mainContext)
        return AppServices(container: container, store: store)
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
            made = try AppServices.make(inMemory: UITestSupport.isUITest)
            if let made {
                try UITestSupport.seedIfAsked(made)
            }
        } catch {
            made = nil
        }
        services = made
    }

    var body: some Scene {
        WindowGroup {
            if let services {
                RootTabView()
                    .modelContainer(services.container)
                    .environment(services.store)
                    .environment(flow)
            } else {
                StartupErrorView()
            }
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
