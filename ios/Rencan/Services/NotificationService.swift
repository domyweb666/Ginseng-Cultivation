import Foundation
import Observation
import RencanCore
import UserNotifications

// 這個檔假設現有的檔會這樣配合（由主會話接，清單在片 I1、I2 的回報）：
//   RencanApp.swift   AppServices 多一個 `let notifications: NotificationService`，
//                     init 裡呼叫 `notifications.startListening()`，
//                     畫面上 `.environment(services.notifications)`
//   RootTabView.swift `.task(id: notifications.pendingPage)` 把 pendingPage 交給 flow.page 後清成 nil
// 已經有、這裡直接用的：RencanPage（RootTabView.swift）、UITestSupport.isUITest、DeepLink（DeepLink.swift）。

/// 這個 app 能不能發通知。系統的五種狀態收成畫面用得到的三種。
enum NotificationPermission {
    /// 還沒問過使用者
    case notAsked
    case allowed
    case denied
}

/// 通知上的固定字。只有一句話，不放體重、體脂率、境界這些跟身體有關的字（安全標準類別 1）。
private enum ReminderNotice {
    /// 同一個識別碼再排一次會蓋掉舊的，所以改日子不用先取消。
    static let identifier = "monthly-measure"
    static let title = "該量一次了"
    static let body = "站上體脂秤量一下，回來看境界有沒有動。"
}

/// 每月量測提醒（片 I1）：問通知權限、查授權狀態、排每月一次的本機通知、取消；
/// 使用者點了通知，把要開的那一頁放在 pendingPage 等畫面來拿。
/// UI 測試模式（-rencanUITest）不碰系統的通知：不問權限、不排、不取消，問權限一律當作允許。
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    /// 現在的授權狀態。使用者會到系統設定改，回到前景時要 refreshPermission 重查。
    private(set) var permission: NotificationPermission = .notAsked
    /// 使用者點通知要開的那一頁。畫面拿走後要清成 nil。
    var pendingPage: RencanPage?

    /// 開始接「使用者點了通知」。要在 app 一起來就呼叫，點通知把 app 叫起來的那一下才收得到。
    func startListening() {
        guard !UITestSupport.isUITest else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// 重查授權狀態，結果放在 permission。
    func refreshPermission() async {
        guard !UITestSupport.isUITest else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permission = NotificationService.summary(of: settings.authorizationStatus)
    }

    /// 跳系統的通知權限視窗。系統只會跳一次，之後直接回上次的答案。結果放在 permission。
    func requestPermission() async throws {
        guard !UITestSupport.isUITest else {
            permission = .allowed
            return
        }
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        permission = granted ? .allowed : .denied
    }

    /// 排每月一次的提醒：每月 day 日、Reminder 定的時間，一直重複。日子不在 1 到 28 丟 invalidDate。
    func scheduleMonthly(day: Int) async throws {
        guard Reminder.isValid(day: day) else { throw RencanError.invalidDate }
        guard !UITestSupport.isUITest else { return }
        let content = UNMutableNotificationContent()
        content.title = ReminderNotice.title
        content.body = ReminderNotice.body
        content.sound = .default
        content.userInfo = [DeepLink.pageKey: DeepLinkPage.realm.rawValue]
        // 指定西曆：手機設成農曆、回曆時「每月幾日」才不會照那個曆法算（跟 DayStamp 同一個理由）。
        var moment = DateComponents()
        moment.calendar = Calendar(identifier: .gregorian)
        moment.day = day
        moment.hour = Reminder.hour
        moment.minute = Reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: true)
        let request = UNNotificationRequest(
            identifier: ReminderNotice.identifier, content: content, trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    /// 取消還沒發出去的每月提醒。
    func cancelMonthly() {
        guard !UITestSupport.isUITest else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ReminderNotice.identifier])
    }

    // MARK: 使用者點了通知

    /// 系統在使用者點通知時呼叫。只拿固定頁名那一個字，通知上其他東西都不讀。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let name = response.notification.request.content.userInfo[DeepLink.pageKey] as? String
        Task { @MainActor in
            self.open(pageNamed: name)
        }
        completionHandler()
    }

    /// 頁名不認得就當沒收到（DeepLink 只認三個固定頁名）。
    private func open(pageNamed name: String?) {
        guard let name, let page = DeepLink.page(named: name) else { return }
        pendingPage = page
    }

    /// 系統的狀態收成三種。暫時授權、App Clip 那種也算允許；認不得的新狀態當作沒允許。
    private static func summary(of status: UNAuthorizationStatus) -> NotificationPermission {
        switch status {
        case .notDetermined:
            return .notAsked
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }
}
