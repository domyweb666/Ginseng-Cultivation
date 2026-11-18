import Foundation
import RencanCore
import SwiftData

// StoreService 裡一次動很多筆、或不是從表單來的寫入：匯入、全部刪除、健康 app 帶入、設定開關。
// 拆到這個檔是因為 SwiftLint 一個型別本體最多 250 行；規矩一樣：全部 throws、只走 save()。

extension StoreService {
    // MARK: 匯入與全部刪除（組塊 F）

    /// 一次寫進一批匯入的紀錄，全部成功或全部不寫（.vibe/架構藍圖.md a16）。
    /// 要寫哪幾筆由 RencanCore 的 WebImportPlan 先算好，本機已經有的已經拿掉。這裡再擋一次：
    /// 任何一筆沒過檢查、撞到本機同一天的量測、撞到本機同一個 id，就整批不寫。
    /// 匯入的量測不做慶祝判定。
    func importRecords(_ plan: WebImportPlan) throws {
        try checkImport(plan)
        // 設定那一筆先拿到手：它不存在時 settings() 會自己存一次檔，要趕在放進紀錄之前。
        let current = try settings()
        for entry in plan.measurements {
            let record = Measurement(
                uid: entry.id, day: entry.date, weightKg: entry.weightKg,
                bodyFatPercent: entry.bodyFatPercent, leanMassKg: entry.leanMassKg,
                source: .imported, createdAt: Date(millisecondsSince1970: entry.createdAtMs)
            )
            context.insert(record)
        }
        for entry in plan.lifts {
            let record = LiftRecord(
                uid: entry.id, day: entry.date, move: entry.move, kg: entry.kg, reps: entry.reps,
                sets: entry.sets, bodyweightKg: entry.bodyweightKg, source: .imported,
                createdAt: Date(millisecondsSince1970: entry.createdAtMs)
            )
            context.insert(record)
        }
        if let heightCm = plan.heightCm {
            current.heightCm = heightCm
        }
        try save()
    }

    /// 匯入前的最後一道檢查。任何一條沒過就丟錯，這時候還沒有東西放進資料庫。
    private func checkImport(_ plan: WebImportPlan) throws {
        let localMeasurements = try context.fetch(FetchDescriptor<Measurement>())
        var days = Set(localMeasurements.map(\.day))
        var measurementIDs = Set(localMeasurements.map(\.uid))
        for entry in plan.measurements {
            try Validation.check(entry)
            guard days.insert(entry.date).inserted else { throw RencanError.sameDayMeasurement }
            guard measurementIDs.insert(entry.id).inserted else { throw RencanError.duplicateID }
        }
        let localLifts = try context.fetch(FetchDescriptor<LiftRecord>())
        var liftIDs = Set(localLifts.map(\.uid))
        for entry in plan.lifts {
            try Validation.check(entry)
            guard liftIDs.insert(entry.id).inserted else { throw RencanError.duplicateID }
        }
        if let heightCm = plan.heightCm {
            try Validation.check(heightCm: heightCm)
        }
    }

    /// 刪掉本機全部的量測與修煉（PRD S28）。身高與性別留著；健康 app 裡的資料不歸這裡管。
    /// 不可逆：呼叫前畫面要先讓使用者再確認一次。存檔失敗會整個退回，一筆都不少。
    /// 小工具的快照不用另外清：save() 成功後會照刪完的狀態重寫一份（尚未入道、本週 0 天）。
    func deleteAllRecords() throws {
        for record in try context.fetch(FetchDescriptor<Measurement>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<LiftRecord>()) {
            context.delete(record)
        }
        try save()
    }

    // MARK: 健康 app（組塊 E）

    /// 把健康 app 帶進來的量測存進去（片 E4）。同一天已經有一筆的不動，回實際新增幾筆。
    /// 帶進來的量測不做慶祝判定，跟補登一樣。
    func importHealthMeasurements(_ entries: [MeasurementEntry]) throws -> Int {
        var added = 0
        for entry in entries {
            try Validation.check(entry)
            guard try measurement(on: entry.date) == nil else { continue }
            let record = Measurement(
                uid: entry.id, day: entry.date, weightKg: entry.weightKg,
                bodyFatPercent: entry.bodyFatPercent, leanMassKg: entry.leanMassKg,
                source: .health, createdAt: Date(millisecondsSince1970: entry.createdAtMs)
            )
            context.insert(record)
            added += 1
        }
        try save()
        return added
    }

    /// 要不要從健康 app 讀體重與體脂（片 E2）。這是 app 自己的開關，系統的授權在手機的設定裡管。
    func setHealthRead(enabled: Bool) throws {
        let current = try settings()
        current.healthReadEnabled = enabled
        try save()
    }

    /// 手打的量測要不要寫回健康 app（片 E3）。
    func setHealthWrite(enabled: Bool) throws {
        let current = try settings()
        current.healthWriteEnabled = enabled
        try save()
    }

    /// 換立繪造型（組塊 M1）。境界碑與慶祝畫面讀 UserSettings.portraitStyle，存了就跟著換。
    func setPortraitStyle(_ style: PortraitStyle) throws {
        let current = try settings()
        current.portraitStyleCode = style.rawValue
        try save()
    }

    /// 修煉卡上的道號，打過一次就記住。前後空白去掉、超過字數截掉（卡上那一格只放得下這麼多字）。
    func setDaoName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = try settings()
        current.daoName = String(trimmed.prefix(ShareCardContent.daoNameLimit))
        try save()
    }

    // MARK: 提醒（組塊 I）

    /// 每月提醒的開關與日子。日子不在 1 到 28 不存。
    func saveReminder(enabled: Bool, day: Int) throws {
        guard Reminder.isValid(day: day) else { throw RencanError.invalidDate }
        let current = try settings()
        current.reminderEnabled = enabled
        current.reminderDay = day
        try save()
    }
}
