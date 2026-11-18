import SwiftUI
import UIKit
import VeggieKit

/// 這一區自己的版面常數（數值跟 SettingsView 的一樣，照畫布 Settings）。
private enum Metrics {
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
}

/// 系統設定裡這個 app 的那一頁，通知的開關在那裡（「一般」區的通知列、提醒區沒允許時的按鈕都開這裡）。
@MainActor
enum SettingsSystemLink {
    static var url: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
}

/// 設定頁「一般」區（蔬菜家族共用規格，2026-11-19 照規格重排）：外觀、通知、觸覺回饋。
/// 通知原本在「權限」區，那一區拿掉了；點這列直接跳系統設定改。
struct SettingsGeneralSection: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.storageKey) private var appearanceCode = Appearance.system.rawValue
    @AppStorage(VeggieHaptics.storageKey) private var isHapticsOn = true

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: VeggieText.general)
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                appearanceRow
                RowDivider()
                notificationRow
                RowDivider()
                VeggieToggleRow(
                    icon: "iphone.radiowaves.left.and.right", title: VeggieText.haptics,
                    isOn: $isHapticsOn
                )
                .accessibilityIdentifier("settings-haptics")
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
        // 使用者從系統設定改完回來，通知的狀態要跟著變。
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await notifications.refreshPermission()
        }
    }

    private var appearance: Appearance {
        Appearance(rawValue: appearanceCode) ?? .system
    }

    /// 外觀三選一，選完馬上換（設在視窗上，彈出來的表單也一起換）。
    private var appearanceRow: some View {
        Menu {
            Picker(VeggieText.appearance, selection: $appearanceCode) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } label: {
            VeggieRow(
                icon: "circle.lefthalf.filled", title: VeggieText.appearance,
                value: appearance.title, accessory: .push
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-appearance")
        .onChange(of: appearanceCode) {
            appearance.apply()
        }
    }

    private var notificationRow: some View {
        Button {
            if let url = SettingsSystemLink.url {
                openURL(url)
            }
        } label: {
            VeggieRow(
                icon: "bell", title: VeggieText.notifications, value: notificationStatus,
                accessory: .external
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-notifications")
    }

    private var notificationStatus: String {
        switch notifications.permission {
        case .notAsked:
            return "還沒問過"
        case .allowed:
            return "已開啟"
        case .denied:
            return "已關閉"
        }
    }
}
