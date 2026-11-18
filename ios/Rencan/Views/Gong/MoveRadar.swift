import RencanCore
import SwiftUI

/// 這張圖自己的版面常數。
private enum Metrics {
    /// 最窄的手機上卡片的內寬（iPhone SE：螢幕 375 減掉兩邊頁邊與卡片內距）。
    /// 圖照這個寬來排，大手機上兩邊多出來的空白不用。
    static let budgetWidth: CGFloat = 313
    /// 功法名字離最外圈多遠
    static let labelGap: CGFloat = 6
    /// 直寫的一個字佔多寬、上下兩個字的中心距，都是字級的倍數（文楷的字身比字級略寬）
    static let charWidthRatio: CGFloat = 1.15
    static let charPitchRatio: CGFloat = 1.02
    /// 字很大時最外圈至少留這麼大，再小就看不出形狀
    static let minimumRadius: CGFloat = 60
    static let gridLineWidth: CGFloat = 1
    static let shapeLineWidth: CGFloat = 2
    static let fillOpacity = 0.22
    static let dotSize: CGFloat = 6
}

/// 功法雷達圖（2026-11-18 多米要的，參考足球球員的能力雷達圖）：每門功法一根軸，
/// 由內到外五圈是入門、小成、大成、圓滿、化境，點的位置是 MoveCard.score（等級加往下一階走了幾成）。
/// 軸的數量跟著 Tables.moves 走，之後加功法不用改這裡。數字全部來自 Digest，這裡只畫圖。
///
/// 功法名一律直寫（2026-11-19 多米選丙版，像碑文）。原本橫寫、名字中心放在同一個圓上，
/// 左右兩側的字比較寬，會壓到外圈。現在每個名字照自己的方向往外推，推到字框剛好不碰外圈：
/// 字框在那個方向上有多長就推多遠，所以永遠不碰線。最外圈多大、整張圖多高，都由字級算出來，
/// 系統字調大時圖自己縮。
struct MoveRadar: View {
    let cards: [MoveCard]

    /// 跟 RencanType.radarLabel 同一個字級、同一個縮放基準，排版才算得準。
    @ScaledMetric(relativeTo: .footnote) private var labelSize = RencanType.radarLabelSize

    /// 一圈一個等級：入門到化境，未入門是圓心。
    private var ringCount: Int { Tables.levelNames.count - 1 }

    var body: some View {
        let layout = RadarLayout(
            axisCount: cards.count,
            labelSize: labelSize,
            longestName: cards.map { $0.move.artName.count }.max() ?? 0
        )
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let dataRadii = cards.map { dataRadius($0, outer: layout.radius) }
            ZStack {
                ForEach(1...ringCount, id: \.self) { ring in
                    polygon(center: center, radii: ringRadii(ring, outer: layout.radius))
                        .stroke(Color.rencan.separator, lineWidth: Metrics.gridLineWidth)
                }
                spokes(center: center, outer: layout.radius)
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
                    let nameLength = cards[index].move.artName.count
                    let distance = layout.labelDistance(index, nameLength: nameLength)
                    label(cards[index], layout: layout)
                        .position(point(index, radius: distance, center: center))
                }
            }
        }
        .frame(height: layout.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("gong-radar")
    }

    /// 軸端只寫功法名（文楷、直寫）：練過的深金色、還沒入門的灰色。等級看點落在第幾圈。
    private func label(_ card: MoveCard, layout: RadarLayout) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(card.move.artName.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(RencanType.radarLabel)
                    .fixedSize()
                    .frame(width: layout.charWidth, height: layout.charPitch)
            }
        }
        .foregroundStyle(card.level > 0 ? Color.rencan.strong : Color.rencan.textTertiary)
    }

    private func dataRadius(_ card: MoveCard, outer: CGFloat) -> CGFloat {
        let maxScore = Double(ringCount)
        return outer * CGFloat(max(0, min(card.score, maxScore)) / maxScore)
    }

    private func ringRadii(_ ring: Int, outer: CGFloat) -> [CGFloat] {
        let radius = outer * CGFloat(ring) / CGFloat(ringCount)
        return Array(repeating: radius, count: cards.count)
    }

    private func point(_ index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let direction = RadarLayout.direction(index, count: cards.count)
        return CGPoint(x: center.x + radius * direction.dx, y: center.y + radius * direction.dy)
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

    private func spokes(center: CGPoint, outer: CGFloat) -> Path {
        Path { path in
            for index in cards.indices {
                path.move(to: center)
                path.addLine(to: point(index, radius: outer, center: center))
            }
        }
    }

    private var accessibilityText: String {
        let parts = cards.map { "\($0.move.artName)\($0.levelName)" }
        return "功法雷達：" + parts.joined(separator: "、")
    }
}

/// 雷達圖的尺寸：由字級與軸數算出最外圈半徑、整張圖的高、每個名字推多遠。
/// 名字是直寫的字框（寬一個字、高 n 個字），沿著軸往外推到字框剛好不碰外圈：
/// 推的距離 = 外圈半徑 + 間隔 + 字框在這個方向上的半長（|橫向| × 半寬 + |縱向| × 半高）。
private struct RadarLayout {
    let axisCount: Int
    let charWidth: CGFloat
    let charPitch: CGFloat
    let nameHeight: CGFloat
    let radius: CGFloat
    let height: CGFloat

    init(axisCount: Int, labelSize: CGFloat, longestName: Int) {
        self.axisCount = axisCount
        charWidth = labelSize * Metrics.charWidthRatio
        charPitch = labelSize * Metrics.charPitchRatio
        nameHeight = charPitch * CGFloat(longestName)
        let half = Metrics.budgetWidth / 2
        // 每根有左右分量的軸都要塞得進卡片寬：推出去的距離 × |橫向| + 半個字寬 ≤ 半寬，取最緊的那根
        var fitted = CGFloat.greatestFiniteMagnitude
        for index in 0..<axisCount {
            let direction = Self.direction(index, count: axisCount)
            let across = abs(direction.dx)
            guard across > 0.001 else { continue }
            let reach = (half - charWidth / 2) / across
            let room = reach - Metrics.labelGap - Self.extent(direction, charWidth, nameHeight)
            fitted = min(fitted, room)
        }
        radius = max(Metrics.minimumRadius, fitted == .greatestFiniteMagnitude ? half : fitted)
        var tallest: CGFloat = 0
        for index in 0..<axisCount {
            let direction = Self.direction(index, count: axisCount)
            let distance = radius + Metrics.labelGap + Self.extent(direction, charWidth, nameHeight)
            tallest = max(tallest, abs(direction.dy) * distance + nameHeight / 2)
        }
        height = (tallest * 2).rounded(.up)
    }

    /// 第 index 根軸上，名字的中心離圓心多遠。名字比最長的短時字框比較矮，推得少一點。
    func labelDistance(_ index: Int, nameLength: Int) -> CGFloat {
        let direction = Self.direction(index, count: axisCount)
        let height = charPitch * CGFloat(nameLength)
        return radius + Metrics.labelGap + Self.extent(direction, charWidth, height)
    }

    /// 第一根朝正上方，順時針排。
    static func direction(_ index: Int, count: Int) -> CGVector {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(count, 1))
        return CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
    }

    /// 字框在這個方向上的半長
    private static func extent(
        _ direction: CGVector, _ width: CGFloat, _ height: CGFloat
    ) -> CGFloat {
        abs(direction.dx) * width / 2 + abs(direction.dy) * height / 2
    }
}
