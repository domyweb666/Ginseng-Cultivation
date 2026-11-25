import RencanCore
import SwiftUI

/// 修煉紀錄在清單裡的一列：功法名・動作名，下面一行「90 公斤 × 5 下 × 3 組」。
/// 今天的修煉、最近修煉、單一功法的紀錄都用它，右邊放什麼由呼叫的地方決定。
struct LiftRow<Trailing: View>: View {
    let record: LiftRecord
    private let trailing: Trailing

    init(record: LiftRecord, @ViewBuilder trailing: () -> Trailing) {
        self.record = record
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                title
                Text(LiftText.detail(of: record))
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            Spacer(minLength: 0)
            trailing
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        let move = LiftText.move(of: record)
        return HStack(spacing: 0) {
            Text(move?.artName ?? record.move)
                .font(RencanType.termBody)
            Text("・" + (move?.name ?? ""))
                .font(RencanType.body)
        }
    }
}

/// 修煉紀錄寫成字的規則，集中在這裡。
enum LiftText {
    static func move(of record: LiftRecord) -> Move? {
        Tables.moves.first { $0.key.rawValue == record.move }
    }

    /// 公斤數：整數不寫小數點，62.5 這種寫一位。
    static func kg(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return Formulas.fmt(value, digits: isWhole ? 0 : 1)
    }

    /// 「90 公斤 × 5 下 × 3 組」；引體向上徒手寫「自重」，加重寫「自重加 10 公斤」。
    static func detail(of record: LiftRecord) -> String {
        let tail = " × \(record.reps) 下 × \(record.sets) 組"
        guard move(of: record)?.usesBodyweight == true else {
            return "\(kg(record.kg)) 公斤" + tail
        }
        return (record.kg == 0 ? "自重" : "自重加 \(kg(record.kg)) 公斤") + tail
    }

    /// 「上次 10 月 3 日・60 公斤 × 5 下 × 3 組」；今天記的寫「上次 今天・…」。
    static func last(_ record: LiftRecord, today: String) -> String {
        let day = record.day == today ? "今天" : DayStamp.monthDay(record.day, today: today)
        return "上次 \(day)・" + detail(of: record)
    }
}
