import AppIntents
import RencanCore
import SwiftData

// Siri 的兩個 intent 共用的東西（組塊 H）：跟 app 同一個資料庫、畫面摘要、功法的選項。

extension AppServices {
    /// 整個程序只建一次的那一份。intent 在 app 沒開的時候也會跑，拿不到 SwiftUI 的 environment；
    /// app 與 intent 各建一個資料庫的話，Siri 記的那筆要等 app 重開才看得到。
    private static var cached: AppServices?

    /// app 與 intent 共用的資料庫與 StoreService。建不起來就丟錯誤，不給空殼。
    static func shared() throws -> AppServices {
        if let cached { return cached }
        let made = try AppServices.make(inMemory: UITestSupport.isUITest)
        cached = made
        return made
    }

    /// 現在的畫面摘要。讀法跟 RootTabView 一樣（量測照日期、修煉照建立時間、今天用 DayStamp），
    /// Siri 講的數字跟畫面上才會是同一份。
    func digest() throws -> Digest {
        let context = container.mainContext
        let byDay = FetchDescriptor<Measurement>(sortBy: [SortDescriptor(\.day)])
        let byCreation = FetchDescriptor<LiftRecord>(sortBy: [SortDescriptor(\.createdAt)])
        let measurements = try context.fetch(byDay)
        let lifts = try context.fetch(byCreation)
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
        return try Digest(
            measurements: measurements.map(\.entry), lifts: lifts.compactMap(\.entry),
            heightCm: settings?.heightCm, sex: settings?.sex, today: DayStamp.today
        )
    }
}

/// Siri 與捷徑裡的「功法」選項。顯示名是動作名，功法名當同義詞，講哪一個都認得（PRD S17）。
/// App Intents 在編譯時就把這些字抽走，只能寫字面值，不能從 Tables.moves 組出來；
/// Tables 的動作名或功法名改了，這裡要跟著改。
enum MoveChoice: String, AppEnum {
    case squat
    case dead
    case bench
    case ohp
    case row
    case pull

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "功法"

    // 多行字面值 swift-format 要尾逗號、SwiftLint 不准；這裡非寫字面值不可，只在這一段關掉那條。
    // swiftlint:disable trailing_comma
    static let caseDisplayRepresentations: [MoveChoice: DisplayRepresentation] = [
        .squat: DisplayRepresentation(title: "深蹲", subtitle: "坐馬樁", synonyms: ["坐馬樁"]),
        .dead: DisplayRepresentation(title: "硬舉", subtitle: "拔山式", synonyms: ["拔山式"]),
        .bench: DisplayRepresentation(title: "臥推", subtitle: "推山掌", synonyms: ["推山掌"]),
        .ohp: DisplayRepresentation(title: "肩推", subtitle: "托天式", synonyms: ["托天式"]),
        .row: DisplayRepresentation(title: "划船", subtitle: "挽弓式", synonyms: ["挽弓式"]),
        .pull: DisplayRepresentation(title: "引體向上", subtitle: "攀雲梯", synonyms: ["攀雲梯"]),
    ]
    // swiftlint:enable trailing_comma

    /// 對到規則引擎 Tables 裡的那門功法（代號同字）。對不到是 nil，intent 會回「不認得的功法」。
    var tableMove: Move? {
        Tables.moves.first { $0.key.rawValue == rawValue }
    }
}
