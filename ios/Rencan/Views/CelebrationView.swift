import SwiftUI

/// 版面數值照設計畫布 Celebrate（390×844，從螢幕邊緣量）。
private enum Metrics {
    /// 內容離螢幕上緣、左右、下緣多遠
    static let topPadding: CGFloat = 96
    static let sidePadding: CGFloat = 32
    static let bottomPadding: CGFloat = 40
    /// 小標題、立繪、大字這幾塊之間
    static let blockSpacing: CGFloat = 28
    /// 小標題的字距（畫布 0.4em）
    static let headingTracking: CGFloat = 6
    /// 立繪：圖的大小與圓角、圖與金框的縫、金框粗細與外圓角
    static let portraitSize = CGSize(width: 200, height: 250)
    static let portraitCornerRadius: CGFloat = 24
    static let frameGap: CGFloat = 6
    static let frameWidth: CGFloat = 3
    static let frameCornerRadius: CGFloat = 30
    /// 大字與期別之間、大字與說明之間、說明行與行之間
    static let titleSpacing: CGFloat = 6
    static let noteSpacing: CGFloat = 8
    static let lineSpacing: CGFloat = 4
    /// 倒數的進度條、進度條與提示字之間
    static let barWidth: CGFloat = 120
    static let barHeight: CGFloat = 3
    static let footerSpacing: CGFloat = 10
}

/// 全螢幕慶祝：突破、晉升、功法破紀錄時蓋在三頁上面。4.5 秒自己關，點任何地方也關。
/// 不管系統深淺色一律深色底（畫布定的），所以對整個畫面指定 dark，顏色代號照舊取。
struct CelebrationView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let celebration: Celebration
    /// 進度條走到幾成（0 到 1）
    @State private var progress: CGFloat = 0
    /// 系統開「減少動態效果」時不噴粒子，留 nil
    @State private var burst: CelebrationBurst?

    var body: some View {
        ZStack {
            Color.rencan.canvas
            if let burst {
                CelebrationParticlesView(burst: burst)
            }
            content
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { close() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
        .accessibilityHint("點兩下關閉")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.default) { close() }
        .accessibilityAction(named: Text("關閉")) { close() }
        .accessibilityIdentifier("celebration")
        .environment(\.colorScheme, .dark)
        .task(id: celebration.id) {
            HapticsService.success()
            let count = celebration.particleCount
            burst = reduceMotion ? nil : CelebrationBurst(count: count, start: .now)
            withAnimation(.linear(duration: AppFlow.celebrationSeconds)) {
                progress = 1
            }
            guard await Task.pause(seconds: AppFlow.celebrationSeconds) else { return }
            close()
        }
    }

    /// 有立繪時照畫布從上往下排；沒有立繪（功法突破、精進）時畫布沒畫，文字放在中間。
    private var content: some View {
        VStack(spacing: 0) {
            if celebration.portrait == nil {
                Spacer(minLength: 0)
            }
            Text(celebration.heading)
                .font(RencanType.subheadline.weight(.semibold))
                .tracking(Metrics.headingTracking)
                .foregroundStyle(Color.rencan.bright)
            if let portrait = celebration.portrait {
                portraitFrame(portrait)
                    .padding(.top, Metrics.blockSpacing)
            }
            titleRow
                .padding(.top, Metrics.blockSpacing)
            notes
                .padding(.top, Metrics.noteSpacing)
            Spacer(minLength: Metrics.blockSpacing)
            footer
        }
        .padding(.top, Metrics.topPadding)
        .padding(.horizontal, Metrics.sidePadding)
        .padding(.bottom, Metrics.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func portraitFrame(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: Metrics.portraitSize.width, height: Metrics.portraitSize.height)
            .background(Color.rencan.tint)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.portraitCornerRadius))
            .padding(Metrics.frameGap + Metrics.frameWidth)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.frameCornerRadius)
                    .strokeBorder(Color.rencan.accent, lineWidth: Metrics.frameWidth)
            )
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.titleSpacing) {
            Text(celebration.title)
                .font(RencanType.celebrationTitle)
            if let stage = celebration.stage {
                Text(stage)
                    .font(RencanType.celebrationStage)
            }
        }
        .foregroundStyle(Color.rencan.bright)
        .lineLimit(1)
        .minimumScaleFactor(RencanLayout.minimumTextScale)
    }

    /// 說明：第一行亮、其餘暗一階（畫布的兩行）。
    private var notes: some View {
        VStack(spacing: Metrics.lineSpacing) {
            ForEach(shownLines.indices, id: \.self) { index in
                Text(shownLines[index])
                    .font(index == 0 ? RencanType.body : RencanType.subheadline)
                    .foregroundStyle(
                        index == 0 ? Color.rencan.textPrimary : Color.rencan.textSecondary
                    )
            }
        }
        .multilineTextAlignment(.center)
    }

    private var footer: some View {
        VStack(spacing: Metrics.footerSpacing) {
            Capsule()
                .fill(Color.rencan.soft)
                .frame(width: Metrics.barWidth, height: Metrics.barHeight)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.rencan.accent)
                        .frame(width: Metrics.barWidth * progress)
                }
                .clipShape(Capsule())
            Text("點任何地方繼續")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
        }
    }

    /// 功法還算不出強度時那一行是空字串，不佔位置。
    private var shownLines: [String] {
        celebration.lines.filter { !$0.isEmpty }
    }

    /// VoiceOver 一次讀完：小標題、大字加期別、每一行說明。
    private var spokenText: String {
        let title = celebration.title + (celebration.stage ?? "")
        return ([celebration.heading, title] + shownLines).joined(separator: "，")
    }

    private func close() {
        flow.celebration = nil
    }
}
