import RencanCore
import SwiftUI

/// 這一頁自己的版面常數。
private enum Metrics {
    /// 空狀態立繪旁邊的小人蔘：健康 app 正在讀、讀不出來時才出現，用最小的那一級
    static let mascotHeight: CGFloat = 56
}

/// 境界頁（中頁，照畫布 Main 與 RealmEmpty）：境界碑、體組成來源列、三格天數、今天的修煉，
/// 底部固定一顆「記一筆修煉」。記一筆與手動輸入都是彈出表單，掛在 PagesView。
struct RealmView: View {
    @Environment(AppFlow.self) private var flow
    let digest: Digest
    let lifts: [LiftRecord]
    /// 最新那筆量測是手打的還是健康 app 帶進來的。
    let latestSource: RecordSource?
    /// 健康 app 這條線現在怎麼樣（RootTabView 回到前景時去讀一次）。
    let healthStatus: HealthLinkStatus

    var body: some View {
        ScrollView {
            VStack(spacing: RencanLayout.groupSpacing) {
                header
                if let stele = digest.stele, let sex = digest.sex {
                    SteleView(stele: stele, sex: sex)
                    SourceRow(
                        measurement: stele.measurement, source: latestSource,
                        today: digest.today, status: healthStatus
                    )
                } else {
                    emptyStele
                }
                stats
                TodayListView(digest: digest, lifts: lifts.filter { $0.day == digest.today })
                    .padding(.top, RencanLayout.itemSpacing)
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.bottom, RencanLayout.sectionSpacing)
        }
        .safeAreaInset(edge: .bottom) { logButton }
    }

    /// 左齒輪、右分析圖示：左右滑的看得見替身（標準清單 A2）。
    private var header: some View {
        HStack {
            PageIconButton(target: .settings, systemImage: "gearshape", label: "設定")
            Spacer()
            Text("境界")
                .font(RencanType.realmHeader)
                .foregroundStyle(Color.rencan.strong)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            PageIconButton(target: .analysis, systemImage: "chart.xyaxis.line", label: "分析")
        }
    }

    /// 還沒量過：雜役服立繪、一句說明、手動輸入的入口。健康 app 讀不到時照畫布 RealmEmpty
    /// 多一顆「去設定打開讀取」；正在讀、讀不出來時小人蔘站在立繪旁邊（片 K4），版面不變。
    private var emptyStele: some View {
        VStack(spacing: RencanLayout.groupSpacing) {
            Image(RencanPortrait.name(realmIndex: 0, sex: digest.sex ?? .male))
                .resizable()
                .scaledToFill()
                .frame(
                    width: RencanLayout.portraitSize.width,
                    height: RencanLayout.portraitSize.height
                )
                .background(Color.rencan.tint)
                .clipShape(RoundedRectangle(cornerRadius: RencanLayout.portraitCornerRadius))
                .accessibilityLabel("雜役服人蔘立繪")
                .overlay(alignment: .bottomTrailing) {
                    if let action = HealthLinkText.mascot(for: healthStatus) {
                        PortraitSideMascot(action: action, height: Metrics.mascotHeight)
                    }
                }
            Text("還沒量過體組成")
                .font(RencanType.title3)
            Text(HealthLinkText.emptyHint(for: healthStatus))
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("realm-empty-hint")
            Button("手動輸入體組成") {
                flow.sheet = .measurementForm
            }
            .buttonStyle(RencanSecondaryButtonStyle())
            if healthStatus == .needsGuide {
                HealthGuideButton()
            }
        }
        .frame(maxWidth: .infinity)
        .rencanCard(cornerRadius: RencanLayout.heroCornerRadius)
    }

    private var stats: some View {
        StatPanel {
            StatCell(value: String(digest.weekCount), unit: "天", caption: "本週")
            StatCell(value: String(digest.trainDays), unit: "天", caption: "累計修煉")
            VStack(alignment: .leading, spacing: 0) {
                Text(digest.sect.title)
                    .font(RencanType.term)
                    .foregroundStyle(Color.rencan.strong)
                    .lineLimit(1)
                    .minimumScaleFactor(RencanLayout.minimumTextScale)
                Text("宗門身分")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    /// 核心動作的入口，固定在底部、頁點上方。
    private var logButton: some View {
        Button {
            flow.sheet = .liftForm
        } label: {
            Label("記一筆修煉", systemImage: "plus")
        }
        .buttonStyle(RencanPrimaryButtonStyle())
        .padding(.horizontal, RencanLayout.screenMargin)
        .padding(.top, RencanLayout.itemSpacing)
        .background(Color.rencan.canvas)
    }
}
