import RencanCore
import SwiftUI

private enum Metrics {
    /// 箭頭按鈕的點擊範圍比圖示寬，往左推這麼多，圖示才會對齊底下卡片的左緣（畫布 -10）。
    static let backButtonOutdent: CGFloat = 10
    /// 箭頭與標題之間
    static let titleGap: CGFloat = 4
}

/// 分析頁（右頁，照畫布 AnalysisRealm、AnalysisGong）：回境界箭頭加文楷大標題、分段切換境界／功法。
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

    /// 換頁狀態在 AppFlow，箭頭按鈕自己會讀，這裡不用傳。
    private var header: some View {
        HStack(spacing: Metrics.titleGap) {
            BackToRealmButton(edge: .leading)
            Text("分析")
                .font(RencanType.pageTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.leading, -Metrics.backButtonOutdent)
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
