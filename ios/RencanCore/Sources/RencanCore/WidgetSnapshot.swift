import Foundation

// 小工具看的那一小份資料（組塊 G，PRD S19、S20；藍圖 a18）。
// 主 app 每次存檔後從 Digest 抄一份放進 App Group，小工具只讀這一份，不碰資料庫、不自己算境界。
// 裡面不放體重、體脂率、FFMI：小工具會出現在主畫面與鎖定畫面，只放境界名、還差幾公斤肌肉、
// 這一週有修煉的日期、累計修煉幾天。
// 本週天數不直接存數字：存的是這一週的日期，小工具拿「它畫的那一天」再數一次，
// 跨到下一週沒打開 app，天數也會自己歸零；歸零之後改寫累計幾天（2026-11-25 多米定）。

/// 小工具上的天數：本週的還是累計的，幾天。
public struct WidgetDayCount: Equatable {
    public static let weekCaption = "本週"
    static let totalCaption = "累計"

    /// 「本週」或「累計」。
    public let caption: String
    public let days: Int

    public init(caption: String, days: Int) {
        self.caption = caption
        self.days = days
    }
}

public struct WidgetSnapshot: Codable, Equatable {
    /// App Group 的代號，跟兩個 target 的 entitlements 寫的是同一個。
    public static let appGroupID = "group.org.domyweb.rencan"
    /// 快照放在 App Group 的 UserDefaults 哪一格。格式改了就換尾巴的版號。
    public static let storageKey = "widgetSnapshot.v1"
    /// 小工具的種類代號，主 app 叫它刷新時用。
    public static let widgetKind = "RencanWidget"

    /// 還沒量過，或還沒填身高性別時畫面上的字。
    public static let notStartedText = "尚未入道"
    /// 從沒打開過 app、讀不到快照時用的那一份。
    public static let empty = WidgetSnapshot(
        realmName: nil, stageName: nil, isUnstable: false, nextLabel: nil, kgToNext: nil,
        weekDays: [], trainDays: 0, updatedAtMs: 0
    )

    /// 大境界的名字，例如「金丹」；還沒入道是 nil。
    public let realmName: String?
    /// 期別，例如「中期」。
    public let stageName: String?
    /// 根基不穩（體脂超過門檻）。
    public let isUnstable: Bool
    /// 下一期的名字，例如「金丹後期」；已經是最高一期時為 nil。
    public let nextLabel: String?
    /// 到下一期還差幾公斤肌肉。
    public let kgToNext: Double?
    /// 寫快照那一週有修煉的日期（yyyy-MM-dd，不重複，由早到晚）。
    public let weekDays: [String]
    /// 累計修煉幾天。2026-11-25 以前寫的快照沒有這一格，讀進來是 nil。
    public let trainDays: Int?
    /// 寫快照的時間（1970 起算的毫秒）。
    public let updatedAtMs: Int

    public init(
        realmName: String?, stageName: String?, isUnstable: Bool, nextLabel: String?,
        kgToNext: Double?, weekDays: [String], trainDays: Int?, updatedAtMs: Int
    ) {
        self.realmName = realmName
        self.stageName = stageName
        self.isUnstable = isUnstable
        self.nextLabel = nextLabel
        self.kgToNext = kgToNext
        self.weekDays = weekDays
        self.trainDays = trainDays
        self.updatedAtMs = updatedAtMs
    }

    /// 從畫面用的同一份 Digest 抄出來，數字不另外算。
    public init(digest: Digest, updatedAtMs: Int) throws {
        let days = try Formulas.daysThisWeek(digest.lifts.map(\.date), today: digest.today)
        var isUnstable = false
        if let stele = digest.stele, case .unstable = stele.gate {
            isUnstable = true
        }
        self.init(
            realmName: digest.stele?.standing.realm.name,
            stageName: digest.stele.map { Tables.stages[$0.standing.stageIndex] },
            isUnstable: isUnstable,
            nextLabel: digest.stele?.gap?.nextLabel,
            kgToNext: digest.stele?.gap?.leanNeededKg,
            weekDays: days,
            trainDays: digest.trainDays,
            updatedAtMs: updatedAtMs
        )
    }

    // MARK: 畫面上的字

    /// 境界那一行：「金丹中期」或「尚未入道」。
    public var realmText: String {
        guard let realmName, let stageName else { return WidgetSnapshot.notStartedText }
        return realmName + stageName
    }

    /// 中型小工具多的那幾行，一行一句。整句交給系統自己折的話會斷在「公／斤」中間
    /// （2026-11-16 在模擬器上看到的），所以這裡先分好。
    public var detailLines: [String] {
        guard realmName != nil else { return ["先量一次體組成"] }
        if isUnstable { return ["根基不穩", "體脂降下來才能突破"] }
        guard let nextLabel, let kgToNext else { return ["已是最高的一期"] }
        return ["距\(nextLabel)", "還差 \(Formulas.fmt(kgToNext, digits: 1)) 公斤肌肉"]
    }

    /// 同樣的話接成一句，給讀螢幕的功能唸。
    public var detailText: String {
        detailLines.joined(separator: isUnstable ? "，" : "")
    }

    /// 以 today 這一天來看，這一週修煉了幾天。快照是上週寫的話會是 0。
    public func weekCount(today: String) throws -> Int {
        try Formulas.daysThisWeek(weekDays, today: today).count
    }

    /// 以 today 這一天來看要寫的天數：這一週練過就寫本週，還沒練就寫累計。
    /// 累計也是 0（新手）、或舊版快照沒有累計，照舊寫本週 0 天。
    public func dayCount(today: String) throws -> WidgetDayCount {
        let week = try weekCount(today: today)
        guard week == 0, let trainDays, trainDays > 0 else {
            return WidgetDayCount(caption: WidgetDayCount.weekCaption, days: week)
        }
        return WidgetDayCount(caption: WidgetDayCount.totalCaption, days: trainDays)
    }

    // MARK: 存與讀

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// 讀不懂（格式不對、舊版留下的）就丟錯，小工具改顯示「打開 app 更新」。
    public static func decode(_ data: Data) throws -> WidgetSnapshot {
        try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
