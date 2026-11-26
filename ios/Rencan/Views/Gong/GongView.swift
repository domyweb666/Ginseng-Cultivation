import RencanCore
import SwiftUI

/// 這一段自己的版面常數（數值照畫布 AnalysisGong）。
private enum Metrics {
    /// 功法卡排幾欄
    static let columnCount = 2
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 刻度條離上面的雷達圖多遠
    static let scaleRadarGap: CGFloat = 40
    /// 雷達圖下面的刻度條：最裡圈的點多大、往外一圈大多少、點的框線、點與字之間、兩端的「內」「外」離刻度多遠
    static let scaleDotBase: CGFloat = 5
    static let scaleDotStep: CGFloat = 1.6
    static let scaleDotStroke: CGFloat = 1.5
    static let scaleLabelGap: CGFloat = 3
    static let scaleEndGap: CGFloat = 6
    /// 串起五個點的細線：從第一格中心畫到最後一格中心，五格平分，所以兩端各縮半格（十分之一）
    static let scaleLineInset: CGFloat = 0.1
}

/// 分析頁的功法段（照畫布 AnalysisGong）：三格統計、功法雷達、十二張功法卡排兩欄、最近修煉、等級怎麼算。
/// 放在 AnalysisView 的 ScrollView 裡，所以自己不捲動。數字全部來自 Digest，這裡只排版。
/// 一筆修煉都沒有時，三格是 0、每張卡寫「還沒有紀錄」，「最近修煉」那格換成一句說明。
struct GongView: View {
    let digest: Digest

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
            GongStats(digest: digest)
            radar
            moveCards
            RecentLiftsList(today: digest.today)
            GongRulesCard(sex: digest.sex)
        }
    }

    /// 雷達圖放在統計下面、功法卡上面：先看全貌，再往下看每一門（2026-11-18 多米要的）。
    private var radar: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "功法雷達")
                .padding(.horizontal, Metrics.titleInset)
            // 刻度條離雷達圖 40（2026-11-23 多米看過整頁的五種排法選一）：原本 8、後來 20，
            // 最下面那個功法名都還懸在刻度上方，像刻度的標題。
            VStack(spacing: Metrics.scaleRadarGap) {
                MoveRadar(cards: digest.moveCards)
                levelScale
            }
            .rencanCard()
        }
    }

    /// 雷達圖下面講一次五圈是哪五階（軸端不寫等級，2026-11-18 丙版）。
    /// 原本是一句「由內到外：入門・小成・大成・圓滿・化境」，字一大就折行、「化境」掉到第二行；
    /// 改成一排刻度：點由小到大，左寫「內」右寫「外」（2026-11-19 多米選 1 號）。
    private var levelScale: some View {
        let levels = Array(Tables.levelNames.dropFirst())
        let largestDot = Metrics.scaleDotBase + Metrics.scaleDotStep * CGFloat(levels.count - 1)
        return HStack(alignment: .top, spacing: Metrics.scaleEndGap) {
            scaleEnd("內")
            HStack(spacing: 0) {
                ForEach(levels.indices, id: \.self) { index in
                    VStack(spacing: Metrics.scaleLabelGap) {
                        let size = Metrics.scaleDotBase + Metrics.scaleDotStep * CGFloat(index)
                        Circle()
                            .strokeBorder(Color.rencan.accent, lineWidth: Metrics.scaleDotStroke)
                            .background(Circle().fill(Color.rencan.surface))
                            .frame(width: size, height: size)
                            .frame(height: largestDot)
                        Text(levels[index])
                            .font(RencanType.caption)
                            .foregroundStyle(Color.rencan.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(RencanLayout.minimumTextScale)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(alignment: .top) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.rencan.separator)
                        .frame(
                            width: proxy.size.width * (1 - Metrics.scaleLineInset * 2),
                            height: Metrics.scaleDotStroke
                        )
                        .position(x: proxy.size.width / 2, y: largestDot / 2)
                }
            }
            scaleEnd("外")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("五圈由內到外：" + levels.joined(separator: "、"))
    }

    /// 刻度條兩端的「內」「外」：比階名淡一點，跟點那一列靠上對齊
    private func scaleEnd(_ text: String) -> some View {
        Text(text)
            .font(RencanType.caption)
            .foregroundStyle(Color.rencan.textTertiary)
    }

    private var moveCards: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "十二門功法")
                .padding(.horizontal, Metrics.titleInset)
            VStack(spacing: RencanLayout.groupSpacing) {
                ForEach(rowStarts, id: \.self) { start in
                    cardRow(from: start)
                }
            }
        }
    }

    /// 每一排第一張卡在 digest.moveCards 裡的位置（0、2、4）。
    private var rowStarts: [Int] {
        Array(stride(from: 0, to: digest.moveCards.count, by: Metrics.columnCount))
    }

    /// 一排兩張。fixedSize 讓這一排先量出最高那張的高度，再叫兩張都撐到那麼高。
    private func cardRow(from start: Int) -> some View {
        let end = min(start + Metrics.columnCount, digest.moveCards.count)
        return HStack(alignment: .top, spacing: RencanLayout.groupSpacing) {
            ForEach(digest.moveCards[start..<end], id: \.move.key) { card in
                MoveCardView(card: card)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
