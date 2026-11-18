import RencanCore
import SwiftUI

private enum Metrics {
    /// 宗門小卡排成一行時，進度條最少要有這麼寬；放不下就把進度條換到第二行。
    static let sectBarMinimumWidth: CGFloat = 48
    /// 「境界」兩個字離頂端再往下多少（2026-11-18 多米看真機說太貼頂，沒有安全距離）
    static let headerTopInset: CGFloat = 16
}

/// 境界頁（中頁，照畫布 Main 與 RealmEmpty）：宗門小卡、境界碑、體組成來源列、三格天數、今天的修煉，
/// 底部浮著一顆「記一筆修煉」。記一筆與手動輸入都是彈出表單，掛在 PagesView。
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
                sectLine
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

    /// 頁首只剩置中的「境界」。換頁改由底部分頁列負責，原本左右兩顆圖示拿掉了。
    private var header: some View {
        Text("境界")
            .font(RencanType.realmHeader)
            .foregroundStyle(Color.rencan.strong)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, minHeight: RencanLayout.tapTarget)
            .padding(.top, Metrics.headerTopInset)
    }

    /// 宗門身分的小卡，放在境界碑上面（2026-11-17 多米選的）：身分、晉升進度、下一步。
    /// 下一步用短句（digest.sect.shortNext），由寬到窄試三種排法，句子永遠不會在右邊被拆成兩行
    /// （2026-11-18 多米看真機說被拆了）：一行排完 → 進度條換到第二行 → 句子也換到標題下面。
    /// 文字與百分比都是 Formulas.sectOf 算好的（digest.sect），這裡只排版。
    private var sectLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: RencanLayout.groupSpacing) {
                sectTitle
                    .fixedSize()
                ProgressBar(percent: digest.sect.progressPercent)
                    .frame(minWidth: Metrics.sectBarMinimumWidth)
                sectNext
                    .fixedSize()
            }
            VStack(spacing: RencanLayout.itemSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: RencanLayout.groupSpacing) {
                    sectTitle
                        .fixedSize()
                    Spacer(minLength: 0)
                    sectNext
                        .fixedSize()
                }
                ProgressBar(percent: digest.sect.progressPercent)
            }
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                sectTitle
                sectNext
                    .fixedSize(horizontal: false, vertical: true)
                ProgressBar(percent: digest.sect.progressPercent)
            }
        }
        .rencanCard(verticalPadding: RencanLayout.panelPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("宗門身分：\(digest.sect.title)。\(digest.sect.next)")
        .accessibilityIdentifier("realm-sect")
    }

    private var sectTitle: some View {
        Text(digest.sect.title)
            .font(RencanType.term)
            .foregroundStyle(Color.rencan.strong)
            .lineLimit(1)
    }

    private var sectNext: some View {
        Text(digest.sect.shortNext)
            .font(RencanType.footnote)
            .foregroundStyle(Color.rencan.textSecondary)
    }

    /// 還沒量過：雜役服立繪、一句說明、手動輸入的入口。健康 app 讀不到時照畫布 RealmEmpty
    /// 多一顆「去設定打開讀取」。
    private var emptyStele: some View {
        VStack(spacing: RencanLayout.groupSpacing) {
            Image(RencanPortrait.name(realmIndex: 0, sex: digest.sex ?? .male))
                .interpolation(.none)
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

    /// 核心動作的入口：一顆膠囊浮在分頁列上方，跟分頁列隔開，兩邊看得到後面的內容。
    /// 2026-11-17 多米選的；原本是整條寬的按鈕墊一塊底色，看起來黏在分頁列上。
    private var logButton: some View {
        Button {
            flow.sheet = .liftForm
        } label: {
            Label("記一筆修煉", systemImage: "plus")
        }
        .buttonStyle(RencanFloatingButtonStyle())
        .padding(.top, RencanLayout.itemSpacing)
        .padding(.bottom, RencanLayout.groupSpacing)
    }
}
