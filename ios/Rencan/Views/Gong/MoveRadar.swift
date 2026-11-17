import RencanCore
import SwiftUI

/// 這張圖自己的版面常數。
private enum Metrics {
    /// 最外圈（化境）的半徑
    static let radius: CGFloat = 90
    /// 功法名字的中心離圓心多遠
    static let labelRadius: CGFloat = 122
    /// 功法名字那一塊的寬；十二門功法時最左最右的名字也要塞得進卡片
    static let labelWidth: CGFloat = 72
    /// 整張圖的高：上下各留出名字的高度
    static let chartHeight: CGFloat = 300
    static let gridLineWidth: CGFloat = 1
    static let shapeLineWidth: CGFloat = 2
    static let fillOpacity = 0.22
    static let dotSize: CGFloat = 6
}

/// 功法雷達圖（2026-11-18 多米要的，參考足球球員的能力雷達圖）：每門功法一根軸，
/// 由內到外五圈是入門、小成、大成、圓滿、化境，點的位置是 MoveCard.score（等級加往下一階走了幾成）。
/// 軸的數量跟著 Tables.moves 走，之後加功法不用改這裡。數字全部來自 Digest，這裡只畫圖。
struct MoveRadar: View {
    let cards: [MoveCard]

    /// 一圈一個等級：入門到化境，未入門是圓心。
    private var ringCount: Int { Tables.levelNames.count - 1 }

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let dataRadii = cards.map(dataRadius)
            ZStack {
                ForEach(1...ringCount, id: \.self) { ring in
                    polygon(center: center, radii: ringRadii(ring))
                        .stroke(Color.rencan.separator, lineWidth: Metrics.gridLineWidth)
                }
                spokes(center: center)
                    .stroke(Color.rencan.separator, lineWidth: Metrics.gridLineWidth)
                polygon(center: center, radii: dataRadii)
                    .fill(Color.rencan.accent.opacity(Metrics.fillOpacity))
                polygon(center: center, radii: dataRadii)
                    .stroke(Color.rencan.accent, lineWidth: Metrics.shapeLineWidth)
                ForEach(cards.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.rencan.accent)
                        .frame(width: Metrics.dotSize, height: Metrics.dotSize)
                        .position(point(index, radius: dataRadii[index], center: center))
                    label(cards[index])
                        .position(point(index, radius: Metrics.labelRadius, center: center))
                }
            }
        }
        .frame(height: Metrics.chartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("gong-radar")
    }

    /// 軸端的字：功法名（文楷）加現在的等級。
    private func label(_ card: MoveCard) -> some View {
        VStack(spacing: 0) {
            Text(card.move.artName)
                .font(RencanType.termBody)
            Text(card.levelName)
                .font(RencanType.caption)
                .foregroundStyle(
                    card.level > 0 ? Color.rencan.strong : Color.rencan.textSecondary
                )
        }
        .lineLimit(1)
        .minimumScaleFactor(RencanLayout.minimumTextScale)
        .frame(width: Metrics.labelWidth)
    }

    private func dataRadius(_ card: MoveCard) -> CGFloat {
        let maxScore = Double(ringCount)
        return Metrics.radius * CGFloat(max(0, min(card.score, maxScore)) / maxScore)
    }

    private func ringRadii(_ ring: Int) -> [CGFloat] {
        let radius = Metrics.radius * CGFloat(ring) / CGFloat(ringCount)
        return Array(repeating: radius, count: cards.count)
    }

    /// 第幾根軸上、離圓心多遠的點。第一根朝正上方，順時針排。
    private func point(_ index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(cards.count, 1))
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }

    private func polygon(center: CGPoint, radii: [CGFloat]) -> Path {
        Path { path in
            for (index, radius) in radii.enumerated() {
                let corner = point(index, radius: radius, center: center)
                if index == 0 {
                    path.move(to: corner)
                } else {
                    path.addLine(to: corner)
                }
            }
            path.closeSubpath()
        }
    }

    private func spokes(center: CGPoint) -> Path {
        Path { path in
            for index in cards.indices {
                path.move(to: center)
                path.addLine(to: point(index, radius: Metrics.radius, center: center))
            }
        }
    }

    private var accessibilityText: String {
        let parts = cards.map { "\($0.move.artName)\($0.levelName)" }
        return "功法雷達：" + parts.joined(separator: "、")
    }
}
