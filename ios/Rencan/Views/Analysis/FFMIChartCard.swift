import Charts
import RencanCore
import SwiftUI

private enum Metrics {
    /// 沒有陰影的白卡內距（畫布 16）
    static let cardPadding: CGFloat = 16
    static let chartHeight: CGFloat = 190
    /// 第一個點與最後一個點離圖的左右邊多遠，日期才不會被切掉
    static let plotPadding: CGFloat = 16
    static let lineStyle = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
    /// 境界門檻的虛線
    static let ruleStyle = StrokeStyle(lineWidth: 1, dash: [4, 4])
    static let pointSize: CGFloat = 8
    static let latestPointSize: CGFloat = 10
    static let pointStroke: CGFloat = 2
    /// 圖的上下各多留這麼多 FFMI，最高與最低的線才不會貼邊
    static let domainPadding = 0.25
    /// 日期最多標幾個，再多會擠在一起
    static let maximumDateLabels = 6
    /// 橫軸最少幾天寬：全部量測都在同一天時，範圍才不會是 0 到 0
    static let minimumDaySpan = 1
}

/// 圖上的一條境界門檻：畫在哪個 FFMI、左邊寫什麼（「金丹 19.5」）。
private struct FFMIChartCardLine {
    let value: Double
    let label: String
}

/// FFMI 走勢（畫布 AnalysisRealm）：每次量測一個點，橫軸照日期排，
/// 隔一週和隔三個月的寬度不一樣，停了多久也看得出來。
/// （2026-11-22 分析頁審查 D1 改的；網頁版是照先後等距排。）
/// 境界門檻畫虛線，現在這個大境界鋪一層淡底。只有一筆時不畫圖，改顯示一句話（PRD S8）。
struct FFMIChartCard: View {
    let points: [FFMIPoint]
    let standing: RealmStanding
    let sex: Sex
    let today: String

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            header
            if let first = points.first, let last = points.last, points.count > 1 {
                chart(first: first, last: last)
            } else {
                Text(singleNote)
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("FFMI 走勢")
                .font(RencanType.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if points.count > 1 {
                Text("共 \(points.count) 次量測")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
        }
    }

    private var singleNote: String {
        guard let only = points.first else { return "還沒有量測紀錄。" }
        let value = Formulas.fmt(only.ffmi, digits: 1)
        return "目前只有一次量測（FFMI \(value)）。下個月再量一次，這裡就會畫出你的修為曲線。"
    }

    // MARK: 圖

    private func chart(first: FFMIPoint, last: FFMIPoint) -> some View {
        let lines = thresholdLines
        return Chart {
            marks
        }
        .chartXScale(
            domain: 0...max(Metrics.minimumDaySpan, last.dayOffset),
            range: .plotDimension(padding: Metrics.plotPadding)
        )
        .chartYScale(domain: valueDomain(lines, fallback: first.ffmi))
        .chartXAxis { dateAxis }
        .chartYAxis { thresholdAxis(lines) }
        .frame(height: Metrics.chartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartLabel(first: first, last: last))
    }

    @ChartContentBuilder
    private var marks: some ChartContent {
        if let bandRange {
            RectangleMark(
                yStart: .value("境界下限", bandRange.lowerBound),
                yEnd: .value("境界上限", bandRange.upperBound)
            )
            .foregroundStyle(Color.rencan.tint)
        }
        ForEach(points.indices, id: \.self) { index in
            LineMark(
                x: .value("距第一次量測幾天", points[index].dayOffset),
                y: .value("FFMI", points[index].ffmi)
            )
            .foregroundStyle(Color.rencan.accent)
            .lineStyle(Metrics.lineStyle)
            PointMark(
                x: .value("距第一次量測幾天", points[index].dayOffset),
                y: .value("FFMI", points[index].ffmi)
            )
            .symbol { pointSymbol(isLatest: index == points.count - 1) }
            .annotation(position: .top) { latestLabel(index) }
        }
    }

    /// 最新那一點是實心的大圓，其他是空心小圓。
    private func pointSymbol(isLatest: Bool) -> some View {
        let size = isLatest ? Metrics.latestPointSize : Metrics.pointSize
        return Circle()
            .fill(isLatest ? Color.rencan.accent : Color.rencan.surface)
            .overlay(Circle().stroke(Color.rencan.accent, lineWidth: Metrics.pointStroke))
            .frame(width: size, height: size)
    }

    /// 只有最新那一點上面寫數字。
    @ViewBuilder
    private func latestLabel(_ index: Int) -> some View {
        if index == points.count - 1 {
            Text(Formulas.fmt(points[index].ffmi, digits: 1))
                .font(RencanType.caption.weight(.bold))
                .foregroundStyle(Color.rencan.textPrimary)
        }
    }

    // MARK: 軸

    private var dateAxis: some AxisContent {
        AxisMarks(values: labelDayOffsets) { value in
            AxisValueLabel(anchor: .top) {
                Text(dateLabel(value))
                    .font(RencanType.caption)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
        }
    }

    private func thresholdAxis(_ lines: [FFMIChartCardLine]) -> some AxisContent {
        AxisMarks(position: .leading, values: lines.map(\.value)) { value in
            AxisGridLine(stroke: Metrics.ruleStyle)
                .foregroundStyle(Color.rencan.fieldBorder)
            AxisValueLabel {
                Text(thresholdLabel(value, in: lines))
                    .font(RencanType.caption)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
        }
    }

    /// 哪幾個點底下標日期（回傳它們距第一次量測幾天）。橫軸照日期排之後，兩次量測可能靠得很近，
    /// 所以從最新那一筆往回挑：跟上一個標了日期的點至少隔「整段天數分成幾格」的一格，才再標一個。
    private var labelDayOffsets: [Int] {
        guard let last = points.last else { return [] }
        let gaps = Metrics.maximumDateLabels - 1
        let minimumGap = max(Metrics.minimumDaySpan, (last.dayOffset + gaps - 1) / gaps)
        var labelled = [last.dayOffset]
        var previous = last.dayOffset
        for point in points.dropLast().reversed() where previous - point.dayOffset >= minimumGap {
            labelled.append(point.dayOffset)
            previous = point.dayOffset
        }
        return labelled.reversed()
    }

    private func dateLabel(_ value: AxisValue) -> String {
        guard let dayOffset = value.as(Int.self),
            let point = points.last(where: { $0.dayOffset == dayOffset })
        else { return "" }
        return DayStamp.short(point.date, today: today)
    }

    private func thresholdLabel(_ value: AxisValue, in lines: [FFMIChartCardLine]) -> String {
        guard let bound = value.as(Double.self) else { return "" }
        return lines.first(where: { $0.value == bound })?.label ?? ""
    }

    // MARK: 門檻與範圍

    /// 要畫的境界門檻：走勢跨過的那幾條，加上現在這個大境界的下限與上限（下一個大境界的門檻）。
    /// 門檻的數字用 sex.displayedRealmBounds()，跟天梯寫的一樣。
    private var thresholdLines: [FFMIChartCardLine] {
        let bounds = sex.displayedRealmBounds()
        let values = points.map(\.ffmi)
        guard let lowest = values.min(), let highest = values.max() else { return [] }
        return Tables.realms.indices.compactMap { index -> FFMIChartCardLine? in
            guard bounds.indices.contains(index) else { return nil }
            let bound = bounds[index]
            let isCrossed = bound > lowest && bound < highest
            let isAroundNow = index == standing.realmIndex || index == standing.realmIndex + 1
            guard isCrossed || isAroundNow else { return nil }
            let label = Tables.realms[index].name + " " + RealmLadderBounds.text(bound)
            return FFMIChartCardLine(value: bound, label: label)
        }
    }

    /// 現在這個大境界的 FFMI 範圍，圖上鋪一層淡底。
    private var bandRange: ClosedRange<Double>? {
        let bounds = sex.displayedRealmBounds()
        let index = standing.realmIndex
        guard bounds.indices.contains(index), bounds.indices.contains(index + 1) else { return nil }
        guard bounds[index] < bounds[index + 1] else { return nil }
        return bounds[index]...bounds[index + 1]
    }

    /// 縱軸範圍：包住所有的點、要畫的門檻與淡底，上下再留一點空。
    private func valueDomain(
        _ lines: [FFMIChartCardLine], fallback: Double
    ) -> ClosedRange<Double> {
        var values = points.map(\.ffmi) + lines.map(\.value)
        if let bandRange {
            values.append(bandRange.lowerBound)
            values.append(bandRange.upperBound)
        }
        let lowest = values.min() ?? fallback
        let highest = values.max() ?? fallback
        return (lowest - Metrics.domainPadding)...(highest + Metrics.domainPadding)
    }

    private func chartLabel(first: FFMIPoint, last: FFMIPoint) -> String {
        let from = DayStamp.monthDay(first.date, today: today)
        let until = DayStamp.monthDay(last.date, today: today)
        let start = Formulas.fmt(first.ffmi, digits: 1)
        let end = Formulas.fmt(last.ffmi, digits: 1)
        return "FFMI 走勢，共 \(points.count) 次量測，從\(from)的 \(start) 到\(until)的 \(end)"
    }
}
