import RencanCore
import SwiftData
import SwiftUI

// 這個檔假設現有的檔會這樣配合（由主會話接）：
//   UserSettings.swift  `var reminderEnabled: Bool = false`
//                       `var reminderDay: Int = Reminder.defaultDay`
//   StoreService.swift  `func saveReminder(enabled: Bool, day: Int) throws`
//                       （日子不在 1 到 28 丟 RencanError.invalidDate，存不進去丟 saveFailed）
//   RencanApp.swift     畫面上 `.environment(services.notifications)`（NotificationService）
// 已經有、這裡直接用的：AppFlow.showError、Task.pause(seconds:)、SectionTitle、RowDivider、
// RencanSecondaryButtonStyle、SettingsAboutLinks.systemSettings（SettingsAboutSection.swift）。

/// 這一區自己的版面常數（數值照畫布 Settings）。
private enum Metrics {
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距，卡片下面那行說明也縮這麼多
    static let cardInset: CGFloat = 16
    /// 提醒日那顆膠囊按鈕
    static let chipHeight: CGFloat = 34
    static let chipHorizontalPadding: CGFloat = 12
    /// 說明出現後停多久才跳系統的通知權限視窗：要來得及看完那一句
    static let explainSeconds: Double = 1.2
    /// 說明旁邊拜託的小人蔘（片 K4）高度：一閃而過的位置用最小那一級
    static let mascotHeight: CGFloat = 56
}

/// 設定頁的「提醒」區（片 I1，照畫布 Settings）：每月量測提醒的開關、提醒日。
/// 自己不包 ScrollView、不加左右邊距，由 SettingsView 排進去。
/// 開關與日子存在 UserSettings，這裡用 @Query 讀；digest 這一區目前用不到，
/// 留著是讓設定頁每一區的寫法一樣（SettingsView 每區都傳 digest）。
struct SettingsReminderSection: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [UserSettings]
    let digest: Digest
    /// 開關剛被打開、權限還在問。這段時間開關先顯示成開的，問完才知道留不留得住。
    @State private var isTurningOn = false
    /// 開關下方那句說明有沒有出現（K4）。
    @State private var isExplaining = false
    /// 這次打開被擋下來（沒有通知權限）。
    @State private var wasRefused = false

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "提醒")
                .padding(.horizontal, Metrics.titleInset)
            card
            Text("每月這一天早上 8 點提醒你量一次。通知上只有一句話，不會寫你的體重和體脂。")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .padding(.horizontal, Metrics.cardInset)
            if showsDeniedHint {
                deniedHint
            }
        }
        // 使用者從系統設定改完回來，授權狀態要重查。
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await notifications.refreshPermission()
        }
    }

    private var isEnabled: Bool {
        settingsRows.first?.reminderEnabled ?? false
    }

    private var day: Int {
        settingsRows.first?.reminderDay ?? Reminder.defaultDay
    }

    /// 沒有通知權限、提醒發不出去的時候才出現：剛剛打開被擋下來，或開著提醒但權限後來被關掉。
    private var showsDeniedHint: Bool {
        notifications.permission == .denied && (wasRefused || isEnabled)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: toggleBinding) {
                Text("每月量測提醒")
                    .font(RencanType.body)
            }
            .tint(Color.rencan.accent)
            .frame(minHeight: RencanLayout.rowHeight)
            .accessibilityIdentifier("reminder-toggle")
            if isExplaining {
                explainRow
            }
            RowDivider()
            dayRow
        }
        .padding(.horizontal, Metrics.cardInset)
        .background(
            Color.rencan.surface,
            in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    /// K4 的位置：開關下方先出現小人蔘（拜託）加這句話，停一下才跳系統的通知權限視窗。
    private var explainRow: some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            // VoiceOver 不讀角色，只讀右邊這句話。
            MascotView(action: .please, height: Metrics.mascotHeight)
            Text("等一下手機會問要不要允許通知，按「允許」才提醒得到你。")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("reminder-explain")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, RencanLayout.groupSpacing)
        .transition(.opacity)
    }

    /// 提醒日：右邊一顆膠囊按鈕，點了跳出 1 到 28 日的選單。提醒沒開也可以先選好日子。
    private var dayRow: some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Text("提醒日")
                .font(RencanType.body)
            Spacer()
            Menu {
                Picker("提醒日", selection: dayBinding) {
                    ForEach(Reminder.allowedDays, id: \.self) { option in
                        Text(Reminder.dayLabel(option))
                            .tag(option)
                    }
                }
            } label: {
                Text(Reminder.label(day: day))
                    .font(RencanType.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rencan.strong)
                    .padding(.horizontal, Metrics.chipHorizontalPadding)
                    .frame(minHeight: Metrics.chipHeight)
                    .background(Color.rencan.soft, in: Capsule())
                    .frame(minHeight: RencanLayout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("reminder-day")
        }
        .frame(minHeight: RencanLayout.rowHeight)
    }

    private var deniedHint: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            Text("手機沒有允許這個 app 發通知，提醒發不出去。")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.destructive)
                .padding(.horizontal, Metrics.cardInset)
                .accessibilityIdentifier("reminder-denied")
            Button("到系統設定打開通知") {
                if let url = SettingsAboutLinks.systemSettings {
                    openURL(url)
                }
            }
            .buttonStyle(RencanSecondaryButtonStyle())
            .accessibilityIdentifier("reminder-open-settings")
        }
    }

    /// 開關顯示的值來自存好的設定；打開的過程中先顯示成開的。
    /// 被擋下來時設定沒有動，isTurningOn 一變回 false 開關就自己彈回去。
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { isEnabled || isTurningOn },
            set: { isOn in
                guard !isTurningOn else { return }
                if isOn {
                    Task { await turnOn() }
                } else {
                    turnOff()
                }
            }
        )
    }

    private var dayBinding: Binding<Int> {
        Binding(
            get: { day },
            set: { newDay in
                Task { await changeDay(to: newDay) }
            }
        )
    }

    /// 打開提醒。還沒問過權限：先出現說明，停一下再跳系統視窗（K4）。
    /// 沒拿到權限就什麼都不存，開關彈回去，下面出現「到系統設定打開通知」。
    private func turnOn() async {
        isTurningOn = true
        defer {
            isTurningOn = false
            isExplaining = false
        }
        do {
            await notifications.refreshPermission()
            if notifications.permission == .notAsked {
                withAnimation { isExplaining = true }
                guard await Task.pause(seconds: Metrics.explainSeconds) else { return }
                try await notifications.requestPermission()
            }
            guard notifications.permission == .allowed else {
                wasRefused = true
                return
            }
            try await enable()
            wasRefused = false
        } catch {
            flow.showError(error)
        }
    }

    /// 先排通知再存設定。存不進去就把剛排的通知取消，設定與通知不會對不上。
    private func enable() async throws {
        try await notifications.scheduleMonthly(day: day)
        do {
            try store.saveReminder(enabled: true, day: day)
        } catch {
            notifications.cancelMonthly()
            throw error
        }
    }

    /// 關掉提醒。先存設定，存成功才取消通知。
    private func turnOff() {
        do {
            try store.saveReminder(enabled: false, day: day)
            notifications.cancelMonthly()
        } catch {
            flow.showError(error)
        }
    }

    /// 換提醒日。提醒開著就照新的日子重排；中間哪一步失敗，通知排回原本的日子。
    private func changeDay(to newDay: Int) async {
        let oldDay = day
        guard newDay != oldDay else { return }
        do {
            if isEnabled {
                try await notifications.scheduleMonthly(day: newDay)
            }
            try store.saveReminder(enabled: isEnabled, day: newDay)
        } catch {
            flow.showError(error)
            await restoreSchedule(day: oldDay)
        }
    }

    /// 換日子失敗後把通知排回原本那一天（設定沒有存成新的日子）。
    private func restoreSchedule(day oldDay: Int) async {
        guard isEnabled else { return }
        do {
            try await notifications.scheduleMonthly(day: oldDay)
        } catch {
            flow.showError(error)
        }
    }
}
