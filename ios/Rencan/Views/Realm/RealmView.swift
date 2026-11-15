import RencanCore
import SwiftUI

/// 境界頁（中頁，照畫布 Main 與 RealmEmpty）：境界碑、體組成來源列、三格天數、今天的修煉，
/// 底部固定一顆「記一筆修煉」。記一筆與手動輸入都是彈出表單，掛在 PagesView。
struct RealmView: View {
    @Environment(AppFlow.self) private var flow
    let digest: Digest
    let lifts: [LiftRecord]
    /// 最新那筆量測是手打的還是健康 app 帶進來的。
    let latestSource: RecordSource?

    var body: some View {
        ScrollView {
            VStack(spacing: RencanLayout.groupSpacing) {
                header
                if let stele = digest.stele, let sex = digest.sex {
                    SteleView(stele: stele, sex: sex)
                    sourceRow(stele.measurement)
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

    /// 還沒量過：雜役服立繪、一句說明、手動輸入的入口。
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
            Text("還沒量過體組成")
                .font(RencanType.title3)
            Text("輸入一次體重和體脂率，境界馬上算給你看。")
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .multilineTextAlignment(.center)
            Button("手動輸入體組成") {
                flow.sheet = .measurementForm
            }
            .buttonStyle(RencanSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .rencanCard(cornerRadius: RencanLayout.heroCornerRadius)
    }

    /// 體組成來源列：這筆數字哪來的、哪天量的，右邊是手動輸入。
    private func sourceRow(_ measurement: MeasurementEntry) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Image(systemName: "heart")
                .foregroundStyle(Color.rencan.accent)
                .frame(width: RencanLayout.sourceIconSize, height: RencanLayout.sourceIconSize)
                .background(Color.rencan.soft, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(sourceName + "・" + DayStamp.monthDay(measurement.date) + "量測")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
                Text(reading(measurement))
                    .font(RencanType.callout)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button("手動輸入") {
                flow.sheet = .measurementForm
            }
            .font(RencanType.callout)
            .foregroundStyle(Color.rencan.strong)
            .frame(minHeight: RencanLayout.tapTarget)
        }
        .padding(.leading, RencanLayout.sectionSpacing)
        .padding(.trailing, RencanLayout.groupSpacing)
        .padding(.vertical, RencanLayout.itemSpacing)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private var sourceName: String {
        latestSource == .health ? "健康 app" : "手動輸入"
    }

    private func reading(_ measurement: MeasurementEntry) -> String {
        let weight = Formulas.fmt(measurement.weightKg, digits: 1)
        let bodyFat = Formulas.fmt(measurement.bodyFatPercent, digits: 1)
        return "\(weight) 公斤・體脂 \(bodyFat)%"
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
