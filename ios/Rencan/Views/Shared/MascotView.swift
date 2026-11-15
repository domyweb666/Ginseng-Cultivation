import RencanCore
import SwiftUI

/// 小人蔘（片 K2，PRD S29）：戴人蔘頭套的火柴人，用動作告訴使用者現在是什麼狀況。
/// 姿勢由 RencanCore 的 Mascot 算，圖由 MascotCanvas 畫；這裡只管時間：動作從第幾秒演起、
/// 換動作時花 Mascot.transitionSeconds 從畫面上當下的姿勢補過去（跟預覽頁同一套做法）。
/// 系統開「減少動態效果」時不跑時間軸，停在 Mascot.restPose。
/// VoiceOver 不朗讀它；要讓人知道的事寫在旁邊那句話裡。
struct MascotView: View {
    let action: MascotAction
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 現在這個動作是什麼時候開始演的。
    @State private var actionStart = Date()
    /// 換動作那一刻畫面上的姿勢，補間從它出發；還沒換過動作就沒有。
    @State private var poseBeforeSwitch: MascotPose?

    var body: some View {
        figure
            .frame(width: MascotCanvas.width(forHeight: height), height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: action) { previous, _ in
                let now = Date()
                poseBeforeSwitch = reduceMotion ? nil : pose(of: previous, at: now)
                actionStart = now
            }
    }

    @ViewBuilder private var figure: some View {
        if reduceMotion {
            MascotCanvas(pose: Mascot.restPose(action: action))
        } else {
            TimelineView(.animation) { timeline in
                MascotCanvas(pose: pose(of: action, at: timeline.date))
            }
        }
    }

    /// 某個動作在某一刻該畫的姿勢；剛換動作的那一小段時間，從換之前的姿勢補過來。
    private func pose(of action: MascotAction, at date: Date) -> MascotPose {
        let elapsed = max(0, date.timeIntervalSince(actionStart))
        let target = Mascot.pose(action: action, time: elapsed)
        guard let poseBeforeSwitch, elapsed < Mascot.transitionSeconds else { return target }
        let progress = Mascot.transitionProgress(elapsedSeconds: elapsed)
        return Mascot.blend(from: poseBeforeSwitch, to: target, progress: progress)
    }
}

#if DEBUG
    /// 展示畫面的版面常數。
    private enum Metrics {
        /// 三種高度（pt）：來源列與表單紅字旁用最小的，問身高那頁與空狀態用最大的。
        static let heights: [CGFloat] = [56, 96, 160]
        /// 一列兩格，六個動作三列，一個螢幕截得完。
        static let columnCount = 2
        /// 同一格裡三個小人蔘之間的縫。
        static let figureSpacing: CGFloat = 4
    }

    /// 小人蔘展示畫面：六個動作各一格，每格三種高度，淺色頁底。只給 UI 測試截圖檢查用，
    /// 例如看高 56 pt 時白臉的框有沒有糊。Debug 版帶啟動參數 -rencanMascotGallery 才會出現。
    struct MascotGalleryView: View {
        static let launchArgument = "-rencanMascotGallery"

        /// 啟動參數有沒有要求顯示這個畫面。
        static var isRequested: Bool {
            ProcessInfo.processInfo.arguments.contains(launchArgument)
        }

        private let columns = Array(repeating: GridItem(.flexible()), count: Metrics.columnCount)

        var body: some View {
            ScrollView {
                LazyVGrid(columns: columns, spacing: RencanLayout.sectionSpacing) {
                    ForEach(MascotAction.allCases, id: \.self) { action in
                        cell(action)
                    }
                }
                .padding(RencanLayout.groupSpacing)
            }
            .background(Color.rencan.canvas.ignoresSafeArea())
            .environment(\.colorScheme, .light)
        }

        private func cell(_ action: MascotAction) -> some View {
            VStack(spacing: RencanLayout.itemSpacing) {
                HStack(alignment: .bottom, spacing: Metrics.figureSpacing) {
                    ForEach(Metrics.heights, id: \.self) { height in
                        MascotView(action: action, height: height)
                    }
                }
                Text(name(of: action))
                    .font(RencanType.caption)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
        }

        /// 動作的中文名，跟預覽頁按鈕上的字一樣。
        private func name(of action: MascotAction) -> String {
            switch action {
            case .wave:
                return "揮手"
            case .sleep:
                return "打瞌睡"
            case .think:
                return "思考"
            case .oops:
                return "抓頭"
            case .shrug:
                return "聳肩"
            case .please:
                return "拜託"
            }
        }
    }
#endif
