import Foundation

/// Date 與「yyyy-MM-dd」字串互換，以及畫面上日期的寫法。
/// 一律用西曆加手機的時區：手機設成民國曆或佛曆時，Calendar.current 的年份不是西元年，
/// 存下去的字串就跟網頁版對不上了。
enum DayStamp {
    /// 只建一次（2026-11-26 性能審查）。時區用 autoupdatingCurrent：手機換時區後每次算都跟著換，
    /// 跟原本每次重建、每次讀 .current 的結果一樣，不會卡在第一次讀到的時區。
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    static var today: String {
        string(from: Date())
    }

    static func string(from date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 字串格式不對時回 nil。
    static func date(from day: String) -> Date? {
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        let parts = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2], hour: 12)
        return calendar.date(from: parts)
    }

    /// 今天往前或往後幾天。
    static func day(offsetFromToday offset: Int) -> String {
        let shifted = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return string(from: shifted)
    }

    /// 「11 月 3 日」；不是今年的加上年份。
    static func monthDay(_ day: String, today: String = DayStamp.today) -> String {
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return day }
        let text = "\(numbers[1]) 月 \(numbers[2]) 日"
        return day.prefix(4) == today.prefix(4) ? text : "\(numbers[0]) 年 \(text)"
    }

    /// 表單上的日期列：「今天・11 月 12 日」或「11 月 3 日」。
    static func formLabel(_ day: String, today: String = DayStamp.today) -> String {
        day == today ? "今天・" + monthDay(day, today: today) : monthDay(day, today: today)
    }

    /// 最近修煉那種窄欄位：「今天」或「11/10」。
    static func short(_ day: String, today: String = DayStamp.today) -> String {
        guard day != today else { return "今天" }
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return day }
        return "\(numbers[1])/\(numbers[2])"
    }
}
