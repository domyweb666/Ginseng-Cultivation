import SwiftUI

/// 分析頁（右頁）：分段切換境界／功法。這片只有標題、回境界箭頭與分段控制；
/// 境界段（宗門、走勢、突破、天梯）在組塊 D 長肉，功法段交給 GongView 在組塊 C 長肉。
struct AnalysisView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case realm = "境界"
        case gong = "功法"

        var id: String { rawValue }
    }

    @Binding var page: RencanPage
    @State private var segment: Segment = .realm

    var body: some View {
        ZStack {
            Color.rencan.background.ignoresSafeArea()
            VStack(spacing: RencanLayout.pageSpacing) {
                HStack {
                    BackToRealmButton(page: $page, edge: .leading)
                    Spacer()
                    Text("分析")
                        .font(RencanType.pageTitle)
                        .foregroundStyle(Color.rencan.gold)
                    Spacer()
                    Spacer()
                        .frame(width: RencanLayout.tapTarget)
                }
                Picker("分析類別", selection: $segment) {
                    ForEach(Segment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                switch segment {
                case .realm:
                    Spacer()
                case .gong:
                    GongView()
                }
            }
            .padding()
        }
    }
}
