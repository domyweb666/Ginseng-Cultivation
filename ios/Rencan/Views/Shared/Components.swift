import RencanCore
import SwiftUI

// 幾個畫面都會用到的小元件（畫布 https://claude.ai/artifact/R99HXs3rb9xRRaKEZNUZg2）。

/// 小標籤：等級（大成）、根基（根基穩固・體脂 15.0%）。
struct RencanChip: View {
    let text: String
    var isWarning = false

    var body: some View {
        Text(text)
            .font(RencanType.caption)
            .foregroundStyle(isWarning ? Color.rencan.destructive : Color.rencan.strong)
            .padding(.horizontal, RencanLayout.chipHorizontalPadding)
            .padding(.vertical, RencanLayout.chipVerticalPadding)
            .background(
                isWarning ? Color.rencan.destructiveSoft : Color.rencan.soft, in: Capsule()
            )
    }
}

/// 區塊標題（今天的修煉、十二門功法）。
struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RencanType.title3)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 統計格裡的一格：大數字加單位，下面一行說明。
struct StatCell: View {
    let value: String
    let unit: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(RencanType.statNumber)
                Text(unit)
                    .font(RencanType.footnote.weight(.semibold))
            }
            Text(caption)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 淡金底的統計格外框，裡面放三個 StatCell。
struct StatPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: RencanLayout.itemSpacing) {
            content
        }
        .padding(RencanLayout.panelPadding)
        .background(
            Color.rencan.tint, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
                .stroke(Color.rencan.soft)
        )
    }
}

/// 一條進度條：走了百分之幾。
struct ProgressBar: View {
    /// 0 到 100
    let percent: Double
    var isMuted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.rencan.soft)
                Capsule()
                    .fill(isMuted ? Color.rencan.textTertiary : Color.rencan.accent)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, percent)) / 100))
            }
        }
        .frame(height: RencanLayout.barHeight)
    }
}

/// 幾格亮幾格的分段條（功法卡的五階）。
struct SegmentBar: View {
    let total: Int
    let filled: Int

    var body: some View {
        HStack(spacing: RencanLayout.barGap) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? Color.rencan.accent : Color.rencan.soft)
                    .frame(height: RencanLayout.barHeight)
            }
        }
    }
}

/// 表單上的圓形加減鈕。
struct RoundStepperButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(RencanType.headline)
                .foregroundStyle(Color.rencan.textPrimary)
                .frame(width: RencanLayout.stepperSize, height: RencanLayout.stepperSize)
                .background(Color.rencan.surfaceMuted, in: Circle())
        }
        // 自己畫了圓底：不設 plain 的話，手機開「按鈕形狀」時系統會在外面再墊一圈米色。
        .buttonStyle(.plain)
        // 按一下走一格，按住一直走：第一次記硬舉 100 公斤要從 20 走 32 格。
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}

/// 分段控制：長相照系統那顆，高度 44、字大一號（2026-11-23 多米選甲版：系統那顆只有 32 高，
/// 太扁不好按，而且改不了高度）。整格都按得到，選中的白底滑過去；開了減少動態效果就直接換。
/// 記一筆的腿推拉、分析頁的境界功法共用。
struct RencanSegmentedControl<Option>: View
where Option: Hashable & RawRepresentable, Option.RawValue == String {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace
    let title: String
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .background(Color.rencan.separator, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: RencanLayout.fadeSeconds)) {
                selection = option
            }
        } label: {
            Text(option.rawValue)
                .font(RencanType.callout)
                .foregroundStyle(Color.rencan.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(RencanLayout.minimumTextScale)
                .frame(maxWidth: .infinity, minHeight: RencanLayout.segmentHeight)
                .background {
                    if isSelected {
                        thumb
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("segment-" + option.rawValue)
    }

    /// 選中那格的白底。
    private var thumb: some View {
        Capsule()
            .fill(Color.rencan.surface)
            .shadow(
                color: Color.rencan.shadow.opacity(RencanLayout.shadowOpacity),
                radius: RencanLayout.segmentShadowRadius,
                y: RencanLayout.segmentShadowY
            )
            .padding(RencanLayout.segmentInset)
            .matchedGeometryEffect(id: "thumb", in: namespace)
    }
}

/// 列與列之間的細線。
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.rencan.separator)
            .frame(height: 1)
    }
}

/// 底部的小提示與「復原」列。小提示 2.6 秒自己消失，復原 5 秒。
struct FlowBanners: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store

    var body: some View {
        VStack(spacing: RencanLayout.itemSpacing) {
            if let undo = flow.undo {
                undoBar(undo)
            }
            if let toast = flow.toast {
                banner(Text(toast.text))
                    .accessibilityIdentifier("toast")
            }
        }
        .padding(.horizontal, RencanLayout.screenMargin)
        .animation(.easeOut(duration: RencanLayout.fadeSeconds), value: flow.toast)
        .animation(.easeOut(duration: RencanLayout.fadeSeconds), value: flow.undo)
        .task(id: flow.toast) {
            guard flow.toast != nil, await Task.pause(seconds: AppFlow.toastSeconds) else { return }
            flow.toast = nil
        }
        .task(id: flow.undo) {
            guard flow.undo != nil, await Task.pause(seconds: AppFlow.undoSeconds) else { return }
            flow.undo = nil
        }
    }

    private func undoBar(_ snapshot: LiftSnapshot) -> some View {
        HStack {
            Text("已刪除一筆修煉")
            Spacer()
            Button("復原") {
                do {
                    try store.restore(snapshot)
                    flow.undo = nil
                } catch {
                    flow.showError(error)
                }
            }
            .font(RencanType.callout)
            .foregroundStyle(Color.rencan.bright)
        }
        .modifier(BannerStyle())
    }

    private func banner(_ text: Text) -> some View {
        text
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(BannerStyle())
    }
}

/// 小提示的深色底。
private struct BannerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RencanType.subheadline)
            .foregroundStyle(Color.rencan.canvas)
            .padding(.horizontal, RencanLayout.cardPadding)
            .padding(.vertical, RencanLayout.groupSpacing)
            .background(
                Color.rencan.textPrimary,
                in: RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
            )
    }
}
