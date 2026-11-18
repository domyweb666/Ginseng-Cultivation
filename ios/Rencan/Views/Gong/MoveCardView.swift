import RencanCore
import SwiftUI

/// 這張卡自己的版面常數（數值照畫布 AnalysisGong 的功法卡）。
private enum Metrics {
    /// 走勢線的高度
    static let sparklineHeight: CGFloat = 30
}

/// 分析頁功法段的一張功法卡：功法名、等級、五階進度、最佳 1RM 與幾倍體重、走勢線、離下一階多遠。
/// 整張是一顆按鈕，點了彈出這門功法的走勢與全部紀錄（MoveDetailView）。
struct MoveCardView: View {
    @Environment(AppFlow.self) private var flow
    let card: MoveCard

    var body: some View {
        Button {
            flow.sheet = .moveDetail(card.move.key)
        } label: {
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                header
                SegmentBar(total: card.move.thresholds.count, filled: card.level)
                if let oneRepMaxText = card.oneRepMaxText, let ratioText = card.ratioText {
                    numbers(oneRepMaxText: oneRepMaxText, ratioText: ratioText)
                    Sparkline(values: card.history, label: card.trendText)
                        .frame(height: Metrics.sparklineHeight)
                }
                Text(card.statusText)
                    .font(RencanType.caption)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            .padding(RencanLayout.panelPadding)
            // 同一排兩張卡要一樣高：內容少的那張把底拉到跟旁邊一樣（GongView 的 cardRow）。
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
            .contentShape(RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("看這門功法的走勢與全部紀錄")
        .accessibilityIdentifier("move-card-" + card.move.key.rawValue)
    }

    /// 功法名和等級排同一行，現代名稱自己一行佔滿卡寬（2026-11-18 多米選的 A 版）。
    /// 原本現代名稱跟功法名疊在左邊、被右邊的等級擠窄，「羅馬尼亞硬舉」會拆成三行。
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: RencanLayout.itemSpacing) {
                Text(card.move.artName)
                    .font(RencanType.term)
                    .foregroundStyle(Color.rencan.strong)
                    .lineLimit(1)
                    .minimumScaleFactor(RencanLayout.minimumTextScale)
                Spacer(minLength: 0)
                RencanChip(text: card.levelName)
                    .fixedSize()
            }
            Text(card.move.name)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(RencanLayout.minimumTextScale)
        }
    }

    private func numbers(oneRepMaxText: String, ratioText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(oneRepMaxText)
                .font(RencanType.headline)
            Text(ratioText)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
        }
    }

    /// 整張卡念給 VoiceOver 的一句話（畫布的寫法：「坐馬樁 大成，五格亮 3 格」再接數字）。
    private var spokenLabel: String {
        let move = card.move
        var parts = [move.artName + "・" + move.name, card.levelName]
        parts.append("\(move.thresholds.count) 格亮 \(card.level) 格")
        if let oneRepMaxText = card.oneRepMaxText, let ratioText = card.ratioText {
            parts.append(oneRepMaxText)
            parts.append(ratioText)
            parts.append(card.trendText)
        }
        parts.append(card.statusText)
        return parts.joined(separator: "，")
    }
}

/// 功法卡上的字怎麼寫，功法卡與單一功法頁共用。數字都是 Digest 算好的，這裡只把它寫成字。
extension MoveCard {
    /// 「1RM 105 公斤」。沒有紀錄、或還沒量過體重算不出來時為 nil。
    var oneRepMaxText: String? {
        best.map { "1RM \(Formulas.fmt($0.estimatedOneRepMaxKg, digits: 0)) 公斤" }
    }

    /// 「1.46 倍體重」。
    var ratioText: String? {
        best.map { "\(Formulas.fmt($0.ratio, digits: 2)) 倍體重" }
    }

    /// 卡片最下面那一句，四選一。
    var statusText: String {
        guard hasRecords else { return "還沒有紀錄" }
        guard best != nil else { return "先量一次體重" }
        guard let needed = kgToNextLevel, let nextName = nextLevelName else { return "已到化境" }
        return "再加 \(needed) 公斤升\(nextName)"
    }

    /// 走勢寫成一句話：VoiceOver 念走勢線用，單一功法頁的走勢圖底下也寫這句。
    var trendText: String {
        guard let first = history.first, let last = history.last else { return "還沒有走勢" }
        let latest = Formulas.fmt(last, digits: 0)
        guard history.count > 1 else { return "1RM 走勢，只有 1 筆，\(latest) 公斤" }
        let earliest = Formulas.fmt(first, digits: 0)
        return "1RM 走勢，共 \(history.count) 筆，從 \(earliest) 公斤到 \(latest) 公斤"
    }
}
