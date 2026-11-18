import RencanCore
import SwiftData
import SwiftUI

/// 三頁哪一頁。順序就是底部分頁列由左到右：設定、境界、分析（境界在中間，2026-11-17 多米定的）。
/// 深連結（通知、小工具、Siri）只准帶這三個值（標準清單 I2）。
enum RencanPage: Int, CaseIterable {
    case settings
    case realm
    case analysis
}

/// 健康 app 這條線現在怎麼樣。境界頁的來源列與空狀態照這個決定顯示什麼（片 E2）。
enum HealthLinkStatus: Equatable {
    /// 正常，或還沒去讀過。裝置沒有健康 app、UI 測試模式也一直停在這裡。
    case idle
    /// 正在讀
    case reading
    /// 讀不到：設定裡把讀取關了，或授權沒給、健康 app 裡沒有體組成。來源列改成引導。
    case needsGuide
    /// 讀的時候出錯
    case failed
}

/// 什麼時候該去健康 app 看一次：回到前景、填完身高與性別、在設定打開讀取。
/// 三個值有一個變了就重看，所以同一次前景只會看一次。
struct HealthSyncTrigger: Equatable {
    let isActive: Bool
    let isProfileComplete: Bool
    let isReadEnabled: Bool
}

/// 最外層：讀資料、算畫面摘要、決定顯示第一次打開那頁還是三頁。
/// 量測、修煉、設定在這裡用 @Query 讀一次，算成一份 Digest 往下傳，三頁拿到的是同一份數字。
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Environment(HealthKitService.self) private var health
    @Environment(NotificationService.self) private var notifications
    @Environment(PurchaseService.self) private var purchases
    @Query(sort: \Measurement.day) private var measurements: [Measurement]
    @Query(sort: \LiftRecord.createdAt) private var lifts: [LiftRecord]
    @Query private var settingsRows: [UserSettings]
    /// 「今天」。app 回到前景時重抓，跨過午夜才不會停在昨天。
    @State private var today = DayStamp.today
    @State private var healthStatus = HealthLinkStatus.idle

    var body: some View {
        Group {
            if let settings = settingsRows.first, settings.isProfileComplete {
                switch digest(settings) {
                case .success(let digest):
                    PagesView(
                        digest: digest, lifts: lifts, latestSource: latestSource,
                        healthStatus: healthStatus,
                        portraitStyle: purchases.effective(settings.portraitStyle)
                    )
                case .failure(let error):
                    DataErrorView(message: RencanError.message(for: error))
                }
            } else {
                FirstLaunchView()
            }
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .foregroundStyle(Color.rencan.textPrimary)
        .tint(Color.rencan.accent)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = DayStamp.today
            }
        }
        // 深連結（小工具）與點通知進來：只換頁，不帶任何資料（安全標準類別 5）。
        .onOpenURL { url in
            guard let page = DeepLink.page(for: url) else { return }
            flow.page = page
        }
        // 冷啟動時 pendingPage 可能在畫面出現前就設好，onChange 會漏掉，所以用 task(id:)。
        .task(id: notifications.pendingPage) {
            guard let page = notifications.pendingPage else { return }
            notifications.pendingPage = nil
            flow.page = page
        }
        .task(id: syncTrigger) {
            await syncHealth()
        }
        // 回到前景就重看一次買過什麼（退款、別台裝置買的），沒買的造型畫面自動回原版。
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            await purchases.refresh()
        }
    }

    /// 日期最新那筆量測的來源（@Query 已照日期排好，最後一筆就是）。
    private var latestSource: RecordSource? {
        measurements.last.flatMap { RecordSource(rawValue: $0.source) }
    }

    private var syncTrigger: HealthSyncTrigger {
        let settings = settingsRows.first
        return HealthSyncTrigger(
            isActive: scenePhase == .active,
            isProfileComplete: settings?.isProfileComplete ?? false,
            isReadEnabled: settings?.healthReadEnabled ?? false
        )
    }

    /// 從健康 app 帶入「最新一筆量測那天以後」的樣本（片 E2）；一筆量測都沒有就從最早的開始拿，
    /// 換手機的人打開就重建好（PRD S21）。今天剛量的那一筆照手動結算放慶祝（settleToday），
    /// 其餘帶進來的不放慶祝，有新增才出一句小提示。
    /// 身高與性別還沒填時由第一次打開那頁自己去問健康 app，這裡不動。
    private func syncHealth() async {
        let trigger = syncTrigger
        guard trigger.isActive, trigger.isProfileComplete, health.isAvailable else { return }
        guard trigger.isReadEnabled else {
            healthStatus = .needsGuide
            return
        }
        // 原本就在引導的人不閃「讀取中」：引導那一行會跟著消失再出現，畫面跳一下。
        if healthStatus != .needsGuide {
            healthStatus = .reading
        }
        do {
            try await health.requestReadAuthorization()
            let samples = try await health.bodySamples(since: measurements.last?.day)
            let existing = measurements.map(\.entry)
            let additions = try HealthImport.merge(samples: samples, existing: existing).additions
            if try !settleToday(additions) {
                let added = try store.importHealthMeasurements(additions)
                if added > 0 {
                    flow.showToast("從健康 app 帶入 \(added) 筆量測")
                }
            }
            let isReadable = try await isHealthReadable(hasSamples: !samples.isEmpty)
            healthStatus = isReadable ? .idle : .needsGuide
        } catch {
            // app 退到背景時這個工作會被取消，讀到一半中斷不算讀不出來。
            guard !Task.isCancelled else {
                healthStatus = .idle
                return
            }
            healthStatus = .failed
            flow.showError(error)
        }
    }

    /// 帶進來的只有一筆、而且是今天量的：照手動結算的規矩走，該放「踏入仙途」「境界突破」就放。
    /// 剛站完體脂秤打開 app 就是這個情況，這一刻是整個 app 的重點（PRD S5、S6）。
    /// 補以前的、一次帶好幾筆的不走這裡，回 false 交給整批帶入，不放慶祝。
    private func settleToday(_ additions: [MeasurementEntry]) throws -> Bool {
        guard additions.count == 1, let entry = additions.first, entry.date == today else {
            return false
        }
        guard let settings = settingsRows.first, let sex = settings.sex else { return false }
        let draft = MeasurementDraft(
            weightKg: entry.weightKg, bodyFatPercent: entry.bodyFatPercent,
            leanMassKg: entry.leanMassKg, day: entry.date, source: .health
        )
        let summary = try digest(settings).get()
        let judgement = try store.saveMeasurement(draft, replacing: false, digest: summary)
        flow.page = .realm
        if let celebration = Celebration.make(
            for: judgement, sex: sex, style: purchases.effective(settings.portraitStyle)
        ) {
            flow.celebration = celebration
        } else {
            flow.showToast(Celebration.toast(for: judgement, sex: sex))
        }
        return true
    }

    /// 健康 app 的體組成讀不讀得到。系統不讓 app 知道讀取授權有沒有被拒絕，只能看結果：
    /// 這次有讀到樣本、以前帶進來過、或健康 app 裡找得到一筆完整的體組成，都算讀得到。
    private func isHealthReadable(hasSamples: Bool) async throws -> Bool {
        if hasSamples { return true }
        let healthSource = RecordSource.health.rawValue
        if measurements.contains(where: { $0.source == healthSource }) { return true }
        return try await health.latestBodyComposition() != nil
    }

    private func digest(_ settings: UserSettings) -> Result<Digest, Error> {
        Result {
            try Digest(
                measurements: measurements.map(\.entry), lifts: lifts.compactMap(\.entry),
                heightCm: settings.heightCm, sex: settings.sex, today: today
            )
        }
    }
}

/// 三頁可以左右滑，也可以點底部的分頁列，預設停在境界。
/// 2026-11-16 多米要原生分頁列，那時左右滑被拿掉；2026-11-18 他又要能滑。系統分頁列跟左右滑不能並存，
/// 所以改回翻頁式的 TabView，分頁列自己畫（RencanTabBar），樣子照原生的浮動膠囊，
/// 代價是沒有 iOS 26 的液態玻璃折射，改用系統的半透明材質。
/// 表單、慶祝掛在這一層，三頁共用；小提示與復原掛在目前那一頁上，才不會蓋住分頁列。
struct PagesView: View {
    @Environment(AppFlow.self) private var flow
    let digest: Digest
    let lifts: [LiftRecord]
    let latestSource: RecordSource?
    let healthStatus: HealthLinkStatus
    /// 設定裡選的立繪造型（組塊 M1），境界頁要用
    let portraitStyle: PortraitStyle

    var body: some View {
        @Bindable var flow = flow
        // 分頁列要沉進底部 Home 條的區域一點才像原生的位置，沉多少得看這支手機底部留多少，
        // 所以在這裡量一次，分頁列的位置跟每頁要讓出的高度都從同一個數字算。
        GeometryReader { proxy in
            pages(safeAreaBottom: proxy.safeAreaInsets.bottom)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $flow.sheet) { sheet in
            sheetContent(sheet)
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if let celebration = flow.celebration {
                CelebrationView(celebration: celebration)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: RencanLayout.fadeSeconds), value: flow.celebration)
    }

    /// 三頁翻頁加浮在上面的分頁列。
    private func pages(safeAreaBottom: CGFloat) -> some View {
        @Bindable var flow = flow
        let clearance = RencanTabBar.clearance(safeAreaBottom: safeAreaBottom)
        return TabView(selection: $flow.page) {
            SettingsView(digest: digest)
                .tabPage(.settings, current: flow.page, clearance: clearance)
                .tag(RencanPage.settings)
            RealmView(
                digest: digest, lifts: lifts, latestSource: latestSource,
                healthStatus: healthStatus, portraitStyle: portraitStyle
            )
            .tabPage(.realm, current: flow.page, clearance: clearance)
            .tag(RencanPage.realm)
            AnalysisView(digest: digest, lifts: lifts)
                .tabPage(.analysis, current: flow.page, clearance: clearance)
                .tag(RencanPage.analysis)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            RencanTabBar(page: $flow.page)
                .offset(y: RencanTabBar.sink(safeAreaBottom: safeAreaBottom))
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AppFlow.Sheet) -> some View {
        switch sheet {
        case .liftForm:
            LiftFormView(digest: digest, lifts: lifts)
        case .measurementForm:
            MeasurementFormView(digest: digest)
        case .editLift(let record):
            EditRecordView(record: record, digest: digest)
        case .moveDetail(let key):
            MoveDetailView(key: key, digest: digest, lifts: lifts)
        case .portraitStyle:
            PortraitStyleView(digest: digest)
        case .shareCard:
            ShareCardSheet(digest: digest)
        }
    }
}

extension View {
    /// 翻頁裡的一頁：自己鋪暖米白底，底部讓出分頁列的高度（內容還是捲得到分頁列後面）。
    /// 小提示與復原列只掛在目前那一頁，同一時間只有一份（兩份會各自倒數）。
    /// 境界頁底下有「記一筆修煉」，要再往上讓出那顆按鈕。
    func tabPage(_ page: RencanPage, current: RencanPage, clearance: CGFloat) -> some View {
        background(Color.rencan.canvas.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if page == current {
                    FlowBanners()
                        .padding(
                            .bottom,
                            page == .realm
                                ? RencanLayout.bannerBottomInset : RencanLayout.itemSpacing
                        )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: clearance)
            }
    }
}

/// 資料算不出來時（例如某一筆日期壞了）顯示的畫面，不讓整頁空白。
struct DataErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: RencanLayout.itemSpacing) {
            Text("資料讀不出來")
                .font(RencanType.title3)
            Text(message)
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(RencanLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
