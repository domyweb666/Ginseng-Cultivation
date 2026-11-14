import SwiftUI

/// 分析頁（右頁）：分段切換境界／功法。外框照 domy 金棕畫布：回境界箭頭＋文楷大標題、分段控制。
/// 境界段（宗門、走勢、突破、天梯）在組塊 D 長肉，功法段交給 GongView 在組塊 C 長肉
/// （照畫布 AnalysisRealm、AnalysisGong 兩張）。
struct AnalysisView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case realm = "境界"
        case gong = "功法"

        var id: String { rawValue }
    }

    @Binding var page: RencanPage
    @State private var segment: Segment = .realm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                HStack(spacing: 0) {
                    BackToRealmButton(page: $page, edge: .leading)
                    Text("分析")
                        .font(RencanType.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                Picker("分析類別", selection: $segment) {
                    ForEach(Segment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                switch segment {
                case .realm:
                    EmptyView()
                case .gong:
                    GongView()
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
        }
    }
}
