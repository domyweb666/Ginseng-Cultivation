import Foundation

// 每月量測提醒的規則（片 I1）。這裡只放固定的數字與畫面上的字，排通知在 app 的 NotificationService。
// 規則：
//   1. 日子只能選 1 到 28。29、30、31 不是每個月都有，選了的話沒有那一天的月份就不會提醒，
//      所以不給選；這樣也不用另外決定「2 月沒有 30 日要挪到哪一天」。
//   2. 時間固定早上 8 點（畫布 Settings 的「每月 1 日 08:00」），這一版不給改。
//   3. 沒設定過時是每月 1 日。

public enum Reminder {
    /// 可以選的日子。上限 28 是平年 2 月的天數，每個月都有這一天。
    public static let allowedDays = 1...28
    /// 沒設定過時的日子。
    public static let defaultDay = 1
    /// 幾點幾分提醒（手機當地時間）。
    public static let hour = 8
    public static let minute = 0

    public static func isValid(day: Int) -> Bool {
        allowedDays.contains(day)
    }

    /// 選單裡一個選項的字：「每月 5 日」。
    public static func dayLabel(_ day: Int) -> String {
        "每月 \(day) 日"
    }

    /// 提醒日那顆按鈕上的字：「每月 1 日 08:00」。
    public static func label(day: Int) -> String {
        dayLabel(day) + " " + twoDigits(hour) + ":" + twoDigits(minute)
    }

    private static func twoDigits(_ number: Int) -> String {
        number < 10 ? "0" + String(number) : String(number)
    }
}
