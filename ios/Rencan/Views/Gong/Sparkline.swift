import SwiftUI

/// 這個檔自己的版面常數（數值照畫布 AnalysisGong 功法卡上的走勢線）。
private enum Metrics {
    /// 線的粗細
    static let lineWidth: CGFloat = 2
    /// 只有一筆、或每一筆都一樣時，線畫在多高（0 是底、1 是頂）
    static let flatLevel: Double = 0.5
}

/// 小走勢線：把一串數字由左到右連成一條線，最低的貼底、最高的貼頂。
/// 沒有座標軸，只看趨勢；數字由旁邊的文字與 label 交代。
struct Sparkline: View {
    let values: [Double]
    /// VoiceOver 念的那句話（例如「1RM 走勢，共 6 筆，從 80 公斤到 105 公斤」）。
    let label: String

    var body: some View {
        Line(values: values)
            .stroke(
                Color.rencan.accent,
                style: StrokeStyle(lineWidth: Metrics.lineWidth, lineCap: .round, lineJoin: .round)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }

    /// 走勢線的形狀。
    private struct Line: Shape {
        let values: [Double]

        func path(in rect: CGRect) -> Path {
            var path = Path()
            guard let lowest = values.min(), let highest = values.max() else { return path }
            // 線有粗細，往內縮半條線寬，頭尾與最高最低點才不會畫出框外。
            let box = rect.insetBy(dx: Metrics.lineWidth / 2, dy: Metrics.lineWidth / 2)
            let span = highest - lowest
            let stepX = values.count > 1 ? box.width / CGFloat(values.count - 1) : box.width
            for (index, value) in values.enumerated() {
                let level = span > 0 ? (value - lowest) / span : Metrics.flatLevel
                let spot = CGPoint(
                    x: box.minX + stepX * CGFloat(index), y: box.maxY - box.height * CGFloat(level)
                )
                if index == 0 {
                    path.move(to: spot)
                } else {
                    path.addLine(to: spot)
                }
            }
            // 只有一筆連不成線，畫一條平的，代表「還沒有變化」。
            if values.count == 1 {
                path.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            }
            return path
        }
    }
}
