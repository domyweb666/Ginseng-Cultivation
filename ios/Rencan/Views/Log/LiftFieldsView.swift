import RencanCore
import SwiftUI

/// 記一筆與編輯共用的四個欄位：重量、次數、組數、日期（照畫布 LogSheet）。
/// 欄位數定死就是這四個加功法，不准再多（產品定稿「邊界」）。
struct LiftFieldsView: View {
    let move: Move
    /// 那一天的體重；沒量過是 nil。引體向上的標題要寫自重幾公斤。
    let bodyweightKg: Double?
    @Binding var kg: Double
    @Binding var reps: Int
    @Binding var sets: Int
    @Binding var date: Date

    /// 重量一次加減多少（槓片最小一對 1.25 公斤）。
    private static let kgStep: Double = 2.5

    var body: some View {
        VStack(spacing: RencanLayout.groupSpacing) {
            weightCard
            HStack(spacing: RencanLayout.groupSpacing) {
                counter("次數", value: $reps, range: Tables.repsRange)
                counter("組數", value: $sets, range: Tables.setsRange)
            }
            DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                .font(RencanType.body)
                .padding(.horizontal, RencanLayout.sectionSpacing)
                .frame(minHeight: RencanLayout.rowHeight)
                .background(
                    Color.rencan.surface,
                    in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
                )
        }
    }

    private var weightLabel: String {
        guard move.usesBodyweight else { return "重量" }
        guard let bodyweightKg else { return "額外負重" }
        return "額外負重（自重 \(Formulas.fmt(bodyweightKg, digits: 1)) 公斤另計）"
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
            Text(weightLabel)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            HStack {
                RoundStepperButton(systemImage: "minus", label: "重量減 2.5 公斤") {
                    kg = max(0, kg - LiftFieldsView.kgStep)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: RencanLayout.chipVerticalPadding) {
                    Text(LiftText.kg(kg))
                        .font(RencanType.bigNumber)
                        .accessibilityIdentifier("kg-value")
                    Text("公斤")
                        .font(RencanType.body)
                        .foregroundStyle(Color.rencan.textSecondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                RoundStepperButton(systemImage: "plus", label: "重量加 2.5 公斤") {
                    kg += LiftFieldsView.kgStep
                }
            }
        }
        .padding(RencanLayout.panelPadding)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private func counter(
        _ title: String, value: Binding<Int>, range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
            Text(title)
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            HStack {
                RoundStepperButton(systemImage: "minus", label: title + "減一") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                }
                Spacer()
                Text(String(value.wrappedValue))
                    .font(RencanType.mediumNumber)
                    .accessibilityLabel("\(title) \(value.wrappedValue)")
                Spacer()
                RoundStepperButton(systemImage: "plus", label: title + "加一") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                }
            }
        }
        .padding(RencanLayout.groupSpacing)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }
}
