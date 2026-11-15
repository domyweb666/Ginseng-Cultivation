import RencanCore
import SwiftUI

private enum Metrics {
    /// 區塊標題比卡片往內縮一點（畫布 margin 0 4）
    static let titleInset: CGFloat = 4
    /// 卡片上下內距（畫布 6）
    static let cardVerticalPadding: CGFloat = 6
    /// 境界名那一欄的寬度（畫布 44）
    static let nameWidth: CGFloat = 44
}

/// 天梯與走勢圖共用的門檻寫法：整數不帶小數（21），其餘寫一位（19.5），跟畫布一樣。
/// 門檻本身來自 sex.displayedRealmBounds()，已經進位到 0.1，這裡只決定怎麼寫。
enum RealmLadderBounds {
    static func text(_ bound: Double) -> String {
        Formulas.fmt(bound, digits: bound == bound.rounded() ? 0 : 1)
    }

    /// 第幾個大境界的範圍，例如「19.5–21」。
    static func range(_ bounds: [Double], at index: Int) -> String {
        guard bounds.indices.contains(index), bounds.indices.contains(index + 1) else { return "" }
        return text(bounds[index]) + "–" + text(bounds[index + 1])
    }

    /// 給 VoiceOver 唸的範圍，例如「FFMI 19.5 到 21」。
    static func spokenRange(_ bounds: [Double], at index: Int) -> String {
        guard bounds.indices.contains(index), bounds.indices.contains(index + 1) else { return "" }
        return "FFMI " + text(bounds[index]) + " 到 " + text(bounds[index + 1])
    }
}

/// 天梯：七個大境界由高到低排，現在那一列鋪底色並寫「你在這裡・後期」。
/// 女性看到的範圍是換算回她自己 FFMI 的數字（.vibe/女性版規則.md 第一節）。
struct RealmLadder: View {
    let standing: RealmStanding
    let sex: Sex

    var body: some View {
        let bounds = sex.displayedRealmBounds()
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "天梯")
                .padding(.horizontal, Metrics.titleInset)
            VStack(spacing: 0) {
                ForEach(Array(Tables.realms.indices.reversed()), id: \.self) { index in
                    row(index, bounds: bounds)
                }
            }
            .padding(.horizontal, RencanLayout.itemSpacing)
            .padding(.vertical, Metrics.cardVerticalPadding)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }

    private func row(_ index: Int, bounds: [Double]) -> some View {
        let isCurrent = index == standing.realmIndex
        let realm = Tables.realms[index]
        let note = isCurrent ? "你在這裡・" + Tables.stages[standing.stageIndex] : realm.summary
        let tone = isCurrent ? Color.rencan.strong : Color.rencan.textSecondary
        return HStack(spacing: RencanLayout.groupSpacing) {
            Text(realm.name)
                .font(RencanType.termBody)
                .foregroundStyle(isCurrent ? Color.rencan.strong : Color.rencan.textPrimary)
                .frame(minWidth: Metrics.nameWidth, alignment: .leading)
            Text(note)
                .font(isCurrent ? RencanType.footnote.weight(.semibold) : RencanType.footnote)
                .foregroundStyle(tone)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(RealmLadderBounds.range(bounds, at: index))
                .font(RencanType.footnote)
                .foregroundStyle(tone)
        }
        .padding(.horizontal, RencanLayout.itemSpacing)
        .frame(minHeight: RencanLayout.tapTarget)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: RencanLayout.fieldCornerRadius)
                    .fill(Color.rencan.soft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(realm.name)，\(note)，\(RealmLadderBounds.spokenRange(bounds, at: index))"
        )
    }
}
