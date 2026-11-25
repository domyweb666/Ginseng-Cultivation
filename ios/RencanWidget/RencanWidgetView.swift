import RencanCore
import SwiftUI
import WidgetKit

/// 小工具用到的顏色。色碼住在小工具自己的 Assets.xcassets，值抄主 app 同名的顏色集，
/// 深淺色由系統切換；這裡不寫色碼。
struct WidgetPalette {
    let canvas = Color("Canvas")
    let strong = Color("Strong")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let destructive = Color("Destructive")
}

private enum Metrics {
    static let palette = WidgetPalette()
    /// 境界名放不下時最多縮到幾成。
    static let realmMinimumScale: CGFloat = 0.6
    static let lineSpacing: CGFloat = 4
    static let columnSpacing: CGFloat = 16
    /// 右邊那幾行放不下時最多縮到幾成（一行一句，不折行）。
    static let detailMinimumScale: CGFloat = 0.8
    /// 讀不到快照時右邊寫的字。
    static let openAppText = "打開 app 更新"
    /// 讀不到天數時畫的那一槓。
    static let unknownCount = "–"
}

/// 天數寫成字，三個尺寸共用。
extension RencanEntry {
    /// 「本週」或「累計」；讀不到天數時照舊寫本週。
    fileprivate var countCaption: String {
        dayCount?.caption ?? WidgetDayCount.weekCaption
    }

    fileprivate var countText: String {
        dayCount.map { String($0.days) } ?? Metrics.unknownCount
    }

    /// 讀螢幕的功能唸的整句。
    fileprivate var countSpoken: String {
        "\(countCaption)修煉 \(countText) 天"
    }
}

/// 三個尺寸共用的入口，點下去一律開到境界頁（DeepLink 只認固定頁名）。
struct RencanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RencanEntry

    private var realmURL: URL? {
        URL(string: DeepLinkPage.scheme + "://" + DeepLinkPage.realm.rawValue)
    }

    var body: some View {
        content
            .widgetURL(realmURL)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            WeekCircleView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        case .systemMedium:
            HStack(alignment: .top, spacing: Metrics.columnSpacing) {
                RealmColumnView(entry: entry)
                DetailColumnView(entry: entry)
            }
            .containerBackground(for: .widget) {
                Metrics.palette.canvas
            }
        default:
            RealmColumnView(entry: entry)
                .containerBackground(for: .widget) {
                    Metrics.palette.canvas
                }
        }
    }
}

/// 小的那一塊，也是中的左半邊：境界在上，天數在下。
private struct RealmColumnView: View {
    let entry: RencanEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.lineSpacing) {
            Text("境界")
                .font(.caption)
                .foregroundStyle(Metrics.palette.textSecondary)
            Text(entry.snapshot?.realmText ?? "人蔘修煉")
                .font(.title2.weight(.bold))
                .foregroundStyle(Metrics.palette.strong)
                .lineLimit(1)
                .minimumScaleFactor(Metrics.realmMinimumScale)
            if entry.snapshot?.isUnstable == true {
                Text("根基不穩")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Metrics.palette.destructive)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: Metrics.lineSpacing) {
                Text(entry.countCaption)
                    .font(.caption)
                    .foregroundStyle(Metrics.palette.textSecondary)
                Text(entry.countText)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Metrics.palette.textPrimary)
                Text("天")
                    .font(.caption)
                    .foregroundStyle(Metrics.palette.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.countSpoken)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 中的右半邊：還差幾公斤肌肉那一句；讀不到快照時請他打開 app。
private struct DetailColumnView: View {
    let entry: RencanEntry

    private var lines: [String] {
        entry.snapshot?.detailLines ?? [Metrics.openAppText]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.lineSpacing) {
            Text("下一步")
                .font(.caption)
                .foregroundStyle(Metrics.palette.textSecondary)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Metrics.palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(Metrics.detailMinimumScale)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.snapshot?.detailText ?? Metrics.openAppText)
    }
}

/// 鎖定畫面的圓形：只有天數，不放境界與身體數字。
private struct WeekCircleView: View {
    let entry: RencanEntry

    var body: some View {
        VStack(spacing: 0) {
            Text(entry.countText)
                .font(.title2.weight(.bold))
            Text(entry.countCaption)
                .font(.caption2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.countSpoken)
    }
}
