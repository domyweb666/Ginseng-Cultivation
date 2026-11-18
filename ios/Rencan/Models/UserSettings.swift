import Foundation
import RencanCore
import SwiftData

/// 設定，整個 app 只有一筆，存在本機。
/// 身高與性別沒填就是 nil：沒有預設值，沒填就停在第一次打開那一頁（.vibe/女性版規則.md）。
@Model
final class UserSettings {
    var heightCm: Double?
    /// 「male」或「female」。
    var sexCode: String?
    /// 手打的量測要不要寫回健康 app。預設關，打開那一刻才問寫入授權。
    var healthWriteEnabled: Bool = false
    /// 使用者有沒有在設定裡把「讀取體重與體脂」關掉。系統授權在健康 app 管，這是 app 自己的開關。
    var healthReadEnabled: Bool = true
    /// 每月量測提醒有沒有開。預設關，打開那一刻才問通知權限。
    var reminderEnabled: Bool = false
    /// 每月幾號提醒（1 到 28）。
    var reminderDay: Int = Reminder.defaultDay
    /// 立繪造型的代碼（PortraitStyle.rawValue）。預設原版；舊資料沒有這欄，SwiftData 自動補預設值。
    var portraitStyleCode: String = "original"

    init() {}

    var sex: Sex? {
        get { sexCode.flatMap(Sex.init(rawValue:)) }
        set { sexCode = newValue?.rawValue }
    }

    /// 認不得的代碼（例如之後拿掉的造型）一律當原版，不會顯示一張不存在的圖。
    var portraitStyle: PortraitStyle {
        PortraitStyle(rawValue: portraitStyleCode) ?? .original
    }

    /// 身高與性別都有了，才算得出境界。
    var isProfileComplete: Bool {
        heightCm != nil && sex != nil
    }
}
