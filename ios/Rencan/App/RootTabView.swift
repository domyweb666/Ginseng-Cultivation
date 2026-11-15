import RencanCore
import SwiftData
import SwiftUI

/// 三頁哪一頁。順序就是左右滑的順序：設定在左、境界在中、分析在右。
/// 深連結（通知、小工具、Siri）只准帶這三個值（標準清單 I2）。
enum RencanPage: Int, CaseIterable {
    case settings
    case realm
    case analysis
}

/// 最外層：讀資料、算畫面摘要、決定顯示第一次打開那頁還是三頁。
/// 量測、修煉、設定在這裡用 @Query 讀一次，算成一份 Digest 往下傳，三頁拿到的是同一份數字。
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Measurement.day) private var measurements: [Measurement]
    @Query(sort: \LiftRecord.createdAt) private var lifts: [LiftRecord]
    @Query private var settingsRows: [UserSettings]
    /// 「今天」。app 回到前景時重抓，跨過午夜才不會停在昨天。
    @State private var today = DayStamp.today

    var body: some View {
        Group {
            if let settings = settingsRows.first, settings.isProfileComplete {
                switch digest(settings) {
                case .success(let digest):
                    PagesView(digest: digest, lifts: lifts, latestSource: latestSource)
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
    }

    /// 日期最新那筆量測的來源（@Query 已照日期排好，最後一筆就是）。
    private var latestSource: RecordSource? {
        measurements.last.flatMap { RecordSource(rawValue: $0.source) }
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

/// 三頁左右滑，預設停在境界（.uiux/02-流程.md）。用 TabView 的 page 樣式，滑動手感跟系統一樣。
/// 系統頁點在暖米白底上看不見，所以關掉，改用自己畫的 PageDots。
/// 表單、小提示、復原、慶祝都掛在這一層，三頁共用。
struct PagesView: View {
    @Environment(AppFlow.self) private var flow
    let digest: Digest
    let lifts: [LiftRecord]
    let latestSource: RecordSource?

    var body: some View {
        @Bindable var flow = flow
        VStack(spacing: 0) {
            TabView(selection: $flow.page) {
                SettingsView(digest: digest)
                    .tag(RencanPage.settings)
                RealmView(digest: digest, lifts: lifts, latestSource: latestSource)
                    .tag(RencanPage.realm)
                AnalysisView(digest: digest, lifts: lifts)
                    .tag(RencanPage.analysis)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageDots(current: flow.page)
                .padding(.vertical, RencanLayout.itemSpacing)
        }
        .overlay(alignment: .bottom) {
            FlowBanners()
                .padding(.bottom, RencanLayout.bannerBottomInset)
        }
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
