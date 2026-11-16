import RencanCore
import SwiftUI

/// 來源列自己的版面常數與門檻。
private enum Metrics {
    /// 上次量測超過幾天算太久沒量（片 K3）
    static let staleAfterDays = 30
}

/// 境界頁上跟健康 app 有關的字。畫布有的照畫布（RealmEmpty），沒有的是組塊 E 自己寫的。
enum HealthLinkText {
    static let guideButton = "去設定打開讀取"
    static let unreadable = "健康 app 讀不到體重和體脂。"
    static let failed = "健康 app 讀不出來，這是上次的數字。"
    private static let manualHint = "輸入一次體重和體脂率，境界馬上算給你看。"

    /// 還沒量過時那句說明。讀不到那句照畫布 RealmEmpty。
    static func emptyHint(for status: HealthLinkStatus) -> String {
        switch status {
        case .needsGuide:
            return "健康 app 還沒開放讀取。去設定打開，或手動" + manualHint
        case .failed:
            return "健康 app 讀不出來。先手動" + manualHint
        case .idle, .reading:
            return manualHint
        }
    }

    /// 太久沒量的提醒。天數不是身體數據，可以寫出來。
    static func stale(days: Int) -> String {
        "\(days) 天沒量了，量一次看看境界有沒有動。"
    }
}

/// 體組成來源列（照畫布 Main）：這筆數字哪來的、哪天量的，右邊是手動輸入。
/// 左邊是愛心圖示；健康 app 讀不出來、或超過 30 天沒量時，
/// 要講的話接在數字下面那一行，不多加一列（片 K3、K4）。
/// 健康 app 讀不到時下面多一行「去設定打開讀取」（片 E2）。
struct SourceRow: View {
    @Environment(AppFlow.self) private var flow
    let measurement: MeasurementEntry
    /// 這筆量測是手打的還是健康 app 帶進來的。
    let source: RecordSource?
    let today: String
    let status: HealthLinkStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: RencanLayout.groupSpacing) {
                leading
                info
                Spacer(minLength: 0)
                Button("手動輸入") {
                    flow.sheet = .measurementForm
                }
                .font(RencanType.callout)
                .foregroundStyle(Color.rencan.strong)
                .frame(minHeight: RencanLayout.tapTarget)
            }
            if status == .needsGuide {
                guideLine
            }
        }
        .padding(.leading, RencanLayout.sectionSpacing)
        .padding(.trailing, RencanLayout.groupSpacing)
        .padding(.vertical, RencanLayout.itemSpacing)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private var leading: some View {
        Image(systemName: "heart")
            .foregroundStyle(Color.rencan.accent)
            .frame(width: RencanLayout.sourceIconSize, height: RencanLayout.sourceIconSize)
            .background(Color.rencan.soft, in: Circle())
            .accessibilityHidden(true)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sourceName + "・" + DayStamp.monthDay(measurement.date, today: today) + "量測")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            Text(reading)
                .font(RencanType.callout)
            if let note {
                Text(note)
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("source-info")
    }

    /// 健康 app 讀不到時多出來的那一行：一句話加「去設定打開讀取」，手動輸入照舊在右上。
    private var guideLine: some View {
        HStack(spacing: RencanLayout.itemSpacing) {
            Text(HealthLinkText.unreadable)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HealthGuideButton()
        }
    }

    private var sourceName: String {
        source == .health ? "健康 app" : "手動輸入"
    }

    private var reading: String {
        let weight = Formulas.fmt(measurement.weightKg, digits: 1)
        let bodyFat = Formulas.fmt(measurement.bodyFatPercent, digits: 1)
        return "\(weight) 公斤・體脂 \(bodyFat)%"
    }

    /// 上次量測到今天過了幾天。日期在算 Digest 時已經檢查過，壞掉的話整頁會先顯示錯誤，
    /// 走不到這裡；真的算不出來就當作沒過幾天，不亂出提醒。
    private var elapsedDays: Int {
        do {
            return try Formulas.daysBetween(measurement.date, today)
        } catch {
            return 0
        }
    }

    private var isStale: Bool {
        elapsedDays > Metrics.staleAfterDays
    }

    /// 健康 app 讀不出來那句比「太久沒量」優先。
    private var note: String? {
        if status == .failed { return HealthLinkText.failed }
        return isStale ? HealthLinkText.stale(days: elapsedDays) : nil
    }
}

/// 「去設定打開讀取」（畫布 RealmEmpty）：翻到這個 app 的設定頁，健康 app 那一區在那裡。
struct HealthGuideButton: View {
    @Environment(AppFlow.self) private var flow

    var body: some View {
        Button(HealthLinkText.guideButton) {
            withAnimation { flow.page = .settings }
        }
        .font(RencanType.callout)
        .foregroundStyle(Color.rencan.strong)
        .frame(minHeight: RencanLayout.tapTarget)
        .accessibilityIdentifier("health-guide")
    }
}
