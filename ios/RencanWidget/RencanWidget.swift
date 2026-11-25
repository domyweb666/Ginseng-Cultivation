import RencanCore
import SwiftUI
import WidgetKit

// 小工具（組塊 G，PRD S19、S20；藍圖 a18）。
// 只讀主 app 存在 App Group 的那一份快照，不碰資料庫、不自己算境界。
// 主畫面小的：境界加本週天數。中的：多一句還差幾公斤肌肉。鎖定畫面圓形：只有本週天數。
// 這一週還沒練、以前練過的人，天數改寫累計（WidgetSnapshot.dayCount）。
// 鎖定畫面不放境界與任何身體數字。

/// 小工具畫的一格：某一天看到的樣子。
struct RencanEntry: TimelineEntry {
    let date: Date
    /// 讀不到快照（從沒打開過 app，或快照讀不懂）時是 nil。
    let snapshot: WidgetSnapshot?
    /// 以這一格的日期來看，要寫的天數。算不出來是 nil。
    let dayCount: WidgetDayCount?

    /// 加小工具時預覽用的樣子。
    static let sample = RencanEntry(
        date: Date(), snapshot: WidgetSnapshot.empty,
        dayCount: WidgetDayCount(caption: WidgetDayCount.weekCaption, days: 0)
    )
}

/// 讀快照、排時間線。
struct RencanProvider: TimelineProvider {
    /// 一次排幾天：今天加後面六天，每天午夜換一格，跨週時會自己從本週換成累計。
    private static let daysAhead = 7

    func placeholder(in context: Context) -> RencanEntry {
        RencanEntry.sample
    }

    func getSnapshot(in context: Context, completion: @escaping (RencanEntry) -> Void) {
        completion(RencanProvider.entry(at: Date(), snapshot: RencanProvider.readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RencanEntry>) -> Void) {
        let snapshot = RencanProvider.readSnapshot()
        let now = Date()
        let dates = [now] + WidgetDay.midnights(after: now, count: RencanProvider.daysAhead - 1)
        let entries = dates.map { RencanProvider.entry(at: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// App Group 裡那一份。沒有或讀不懂都回 nil，畫面改顯示「打開 app 更新」。
    private static func readSnapshot() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroupID) else { return nil }
        guard let data = defaults.data(forKey: WidgetSnapshot.storageKey) else { return nil }
        do {
            return try WidgetSnapshot.decode(data)
        } catch {
            return nil
        }
    }

    private static func entry(at date: Date, snapshot: WidgetSnapshot?) -> RencanEntry {
        guard let snapshot else {
            return RencanEntry(date: date, snapshot: nil, dayCount: nil)
        }
        var count: WidgetDayCount?
        do {
            count = try snapshot.dayCount(today: WidgetDay.string(from: date))
        } catch {
            count = nil
        }
        return RencanEntry(date: date, snapshot: snapshot, dayCount: count)
    }
}

/// 日期換成「yyyy-MM-dd」與算午夜。一律西曆加手機時區，跟主 app 的 DayStamp 同一個規矩。
enum WidgetDay {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func string(from date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// date 之後的幾個午夜（明天零點、後天零點……）。
    static func midnights(after date: Date, count: Int) -> [Date] {
        let start = calendar.startOfDay(for: date)
        return (1...max(count, 1)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }
}

struct RencanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: RencanProvider()) { entry in
            RencanWidgetView(entry: entry)
        }
        .configurationDisplayName("境界與本週修煉")
        .description("看現在的境界，和這一週修煉了幾天。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
