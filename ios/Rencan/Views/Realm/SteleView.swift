import RencanCore
import SwiftUI

/// 版面數值照設計畫布「七個境界的深色卡」（390 寬）。
private enum Metrics {
    /// 立繪四周露出底色的寬度、立繪的圓角（卡片圓角 24 減掉這一圈 7）、立繪與字之間
    static let framePadding: CGFloat = 7
    static let portraitCornerRadius: CGFloat = 17
    static let captionSpacing: CGFloat = 6
    /// 字那一列：左邊的內距、其餘三邊的內距（也是字與印章之間）
    static let captionLeading: CGFloat = 14
    static let captionPadding: CGFloat = 10
    /// 境界名與小字之間、境界名與期別之間、三角符號與小字之間
    static let nameSpacing: CGFloat = 2
    static let stageSpacing: CGFloat = 6
    static let warningSpacing: CGFloat = 4
    /// 紅印章
    static let sealSize: CGFloat = 34
    static let sealCornerRadius: CGFloat = 6
    /// 印章上的字，七個境界都刻「境」（境界的境）。
    /// 2026-11-19 多米改的：原本一境一個代表字（氣、基、丹……），他要每張卡統一。
    /// 更早刻壹到柒（第幾境），他看真機覺得看不懂。
    static let sealGlyph = "境"
    /// 深色卡最窄多寬：立繪加左右各一圈邊。立繪不能縮，縮了像素的格子就不齊。
    static let minimumWidth = RencanLayout.largePortraitSize.width + framePadding * 2
    /// 立繪左下角造型名那顆標籤：離立繪邊多遠、底色多不透明（要透一點看得到後面的地面）
    static let styleTagInset: CGFloat = 8
    static let styleTagOpacity: Double = 0.75
}

/// 境界碑：上面一張深色卡（立繪當主角，下面一列境界與期別、FFMI 與根基、紅印章），
/// 下面一張白卡（距下一期還差多少肌肉、三期進度）。
/// 深色卡的底色跟著境界換，深淺色模式長一樣。
/// 體脂超過門檻時照樣顯示境界，但標「根基不穩」、進度條灰掉（PRD S7）。
/// 境界不會降（2026-11-25）：突破過的人體脂超標，講的是「才能再突破」，原本的境界還在。
struct SteleView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let stele: SteleDigest
    let sex: Sex
    /// 設定裡選的立繪造型（組塊 M1）
    let style: PortraitStyle
    /// 手機有沒有開低耗電模式。app 回到前景時重看一次。
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// 動畫從哪一刻起算
    @State private var animationStart = Date()
    /// 深色卡排完版有多寬。立繪上面露出的底色要跟左右一樣寬，左右多寬要量了才知道。
    @State private var heroWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: RencanLayout.groupSpacing) {
            hero
            progress
                .rencanCard()
        }
    }

    private var standing: RealmStanding { stele.standing }

    private var hero: some View {
        VStack(spacing: Metrics.captionSpacing) {
            portrait
            caption
        }
        .padding([.horizontal, .bottom], Metrics.framePadding)
        .padding(.top, topInset)
        .frame(minWidth: Metrics.minimumWidth, maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { heroWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in heroWidth = width }
            }
        }
        .background(
            Color.rencan.realmBase(standing.realmIndex),
            in: RoundedRectangle(cornerRadius: RencanLayout.heroCornerRadius)
        )
        .shadow(
            color: Color.rencan.shadow.opacity(RencanLayout.shadowOpacity),
            radius: RencanLayout.shadowRadius,
            y: RencanLayout.shadowY
        )
        // 螢幕寬 375 的手機放不下最窄寬度：對外只佔拿到的寬，多出來的左右平均凸出去，
        // 不把整頁撐寬。
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("stele")
    }

    /// 立繪上面露出多少底色：跟左右一樣寬（2026-11-17 多米要的，原本上面固定 7、左右隨手機變寬）。
    /// 立繪寬度固定，卡片越寬左右露得越多。還沒量到寬度時先用最窄的那一圈。
    private var topInset: CGFloat {
        max(Metrics.framePadding, (heroWidth - RencanLayout.largePortraitSize.width) / 2)
    }

    /// 立繪要不要動。減少動態效果、低耗電、app 不在前景、跑自動測試時都放靜態圖。
    private var isAnimating: Bool {
        scenePhase == .active && !reduceMotion && !isLowPower && !UITestSupport.holdsPortraitStill
    }

    /// 點立繪打開選造型頁（2026-11-18 多米選的 B 版），左下角寫現在是哪個造型。
    /// 動畫那張圖關掉了觸控，所以用 contentShape 講明整個立繪框都點得到。
    private var portrait: some View {
        Button {
            flow.sheet = .portraitStyle
        } label: {
            Group {
                if isAnimating {
                    animatedPortrait
                } else {
                    stillPortrait
                }
            }
            .overlay(alignment: .bottomLeading) { styleTag }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.portraitCornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.portraitCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(standing.realm.name)期人蔘立繪，造型：\(style.displayName)")
        .accessibilityHint("打開選造型的頁面")
        .accessibilityIdentifier("portrait-style")
        .onChange(of: scenePhase) { _, _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// 寫造型名不只寫「換造型」：沒買過的人看到「原版」，才會想到還有別的版本。「›」讓人知道點得下去。
    private var styleTag: some View {
        Text(style.displayName + " ›")
            .font(RencanType.footnote)
            .foregroundStyle(Color.rencan.realmName)
            .padding(.horizontal, RencanLayout.chipHorizontalPadding)
            .padding(.vertical, RencanLayout.chipVerticalPadding)
            .background(
                Color.rencan.realmBase(standing.realmIndex).opacity(Metrics.styleTagOpacity),
                in: Capsule()
            )
            .padding(Metrics.styleTagInset)
    }

    private var stillPortrait: some View {
        Image(RencanPortrait.name(realmIndex: standing.realmIndex, sex: sex, style: style))
            .interpolation(.none)
            .resizable()
            .scaledToFill()
            .frame(
                width: RencanLayout.largePortraitSize.width,
                height: RencanLayout.largePortraitSize.height
            )
    }

    /// 動畫是一張格子圖。把整張圖放大到「一格剛好是立繪框那麼大」，移到現在要看的那一格，
    /// 框外面的切掉。圖比框大很多，所以關掉它的觸控，免得蓋住旁邊的按鈕。
    private var animatedPortrait: some View {
        let size = RencanLayout.largePortraitSize
        let columns = RencanPortrait.animationColumns
        let rows = RencanPortrait.animationRows
        let seconds = RencanPortrait.animationFrameSeconds
        return TimelineView(.periodic(from: animationStart, by: seconds)) { context in
            let elapsed = context.date.timeIntervalSince(animationStart) / seconds
            let frame = Int(max(0, elapsed.rounded())) % (columns * rows)
            let name = RencanPortrait.animationName(
                realmIndex: standing.realmIndex, sex: sex, style: style
            )
            Image(name)
                .interpolation(.none)
                .resizable()
                .frame(width: size.width * CGFloat(columns), height: size.height * CGFloat(rows))
                .offset(
                    x: -size.width * CGFloat(frame % columns),
                    y: -size.height * CGFloat(frame / columns)
                )
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    private var caption: some View {
        HStack(alignment: .center, spacing: Metrics.captionPadding) {
            VStack(alignment: .leading, spacing: Metrics.nameSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.stageSpacing) {
                    Text(standing.realm.name)
                        .font(RencanType.realmName)
                    Text(Tables.stages[standing.stageIndex])
                        .font(RencanType.realmStage)
                }
                .foregroundStyle(Color.rencan.realmName)
                .accessibilityElement(children: .combine)
                statusLine
            }
            Spacer(minLength: 0)
            seal
        }
        .padding(.leading, Metrics.captionLeading)
        .padding([.trailing, .vertical], Metrics.captionPadding)
    }

    /// FFMI 加根基那一句。根基不穩時換成淺紅，前面加三角符號：
    /// app 原本的紅在深色底上看不清楚，符號是給分不出紅色的人看的。
    private var statusLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.warningSpacing) {
            if !stele.isStable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }
            Text("FFMI \(Formulas.fmt(stele.ffmi, digits: 2))・\(gateText)")
        }
        .font(RencanType.footnote)
        .foregroundStyle(
            stele.isStable
                ? Color.rencan.realmSub(standing.realmIndex) : Color.rencan.realmWarning
        )
    }

    /// 純裝飾，旁白不唸。
    private var seal: some View {
        Text(Metrics.sealGlyph)
            .font(RencanType.seal)
            .foregroundStyle(Color.rencan.onSeal)
            .frame(width: Metrics.sealSize, height: Metrics.sealSize)
            .background(
                Color.rencan.seal, in: RoundedRectangle(cornerRadius: Metrics.sealCornerRadius)
            )
            .accessibilityHidden(true)
    }

    private var bodyFat: String {
        Formulas.fmt(stele.measurement.bodyFatPercent, digits: 1)
    }

    private var limit: String {
        Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
    }

    private var gateEffect: String {
        stele.hasBreakthrough ? "才能再突破" : "境界才生效"
    }

    /// 根基那一句（照網頁版 index.html L357–361，「偏低」那種 2026-11-23 拿掉）。
    private var gateText: String {
        switch stele.gate {
        case .stable:
            return "根基穩固・體脂 \(bodyFat)%"
        case .wavering:
            return "根基浮動・體脂 \(bodyFat)%"
        case .unstable:
            return "根基不穩・體脂 \(bodyFat)%"
        }
    }

    @ViewBuilder
    private var progress: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            if case .unstable(let overBy) = stele.gate {
                Text("降到 \(limit)% 以下\(gateEffect)，還差 \(Formulas.fmt(overBy, digits: 1))%")
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.destructive)
            } else if let gap = stele.gap {
                HStack(alignment: .firstTextBaseline) {
                    Text("下一期 \(gap.nextLabel)")
                        .font(RencanType.subheadline)
                        .foregroundStyle(Color.rencan.textSecondary)
                    Spacer()
                    Text("還差 \(Formulas.fmt(gap.leanNeededKg, digits: 1)) 公斤肌肉")
                        .font(RencanType.headline)
                }
            } else {
                Text("已達渡劫後期")
                    .font(RencanType.headline)
            }
            stageBars
        }
    }

    /// 初期、中期、後期三格：過了的填滿，現在這一期照比例，還沒到的空著。
    private var stageBars: some View {
        HStack(spacing: RencanLayout.barGap) {
            ForEach(Tables.stages.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
                    ProgressBar(percent: percent(ofStage: index), isMuted: !stele.isStable)
                    Text(Tables.stages[index])
                        .font(RencanType.caption)
                        .foregroundStyle(
                            index == standing.stageIndex
                                ? Color.rencan.textPrimary : Color.rencan.textSecondary
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressLabel)
    }

    private func percent(ofStage index: Int) -> Double {
        if index < standing.stageIndex { return 100 }
        return index == standing.stageIndex ? stele.stagePercent : 0
    }

    private var progressLabel: String {
        let stage = Tables.stages[standing.stageIndex]
        let walked = Formulas.fmt(stele.stagePercent, digits: 0)
        return "\(standing.realm.name)\(stage)走了百分之 \(walked)"
    }
}
