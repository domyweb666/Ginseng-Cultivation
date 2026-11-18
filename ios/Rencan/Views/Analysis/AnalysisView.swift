import RencanCore
import SwiftUI

private enum Metrics {
    /// 標題比卡片邊再縮進一點，跟設定頁一樣
    static let titleInset: CGFloat = 4
}

/// 分析頁（分頁列中間那格，照畫布 AnalysisRealm、AnalysisGong）：文楷大標題、分段切換境界／功法。
/// 境界段在 AnalysisRealmSection，功法段在 GongView，兩段拿的是同一份 Digest。
struct AnalysisView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case realm = "境界"
        case gong = "功法"

        var id: String { rawValue }
    }

    let digest: Digest
    let lifts: [LiftRecord]
    @State private var segment: Segment = .realm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                VStack(alignment: .leading, spacing: RencanLayout.groupSpacing) {
                    header
                    segmentPicker
                }
                switch segment {
                case .realm:
                    AnalysisRealmSection(digest: digest)
                case .gong:
                    GongView(digest: digest, lifts: lifts)
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.bottom, RencanLayout.sectionSpacing)
        }
    }

    /// 換頁改由底部分頁列負責，頁首是標題，右上角分享修煉卡（跟境界頁同一個位置；沒量過時不放）。
    private var header: some View {
        HStack {
            Text("分析")
                .font(RencanType.pageTitle)
                .padding(.horizontal, Metrics.titleInset)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if digest.stele != nil {
                ShareCardButton()
            }
        }
        .frame(minHeight: RencanLayout.tapTarget)
        .padding(.top, RencanLayout.pageTitleTopInset)
    }

    private var segmentPicker: some View {
        Picker("分析類別", selection: $segment) {
            ForEach(Segment.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }
}
