import SwiftUI
import UIKit

// 這個檔假設現有的檔會這樣配合（由主會話接）：
//   RencanApp.swift 畫面上 `.environment(services.notifications)`（NotificationService）
// 已經有、這裡直接用的：SectionTitle、RowDivider（Components.swift）、RencanType、RencanLayout。

/// 這一區自己的版面常數（數值跟 SettingsView 的一樣，照畫布 Settings）。
private enum Metrics {
    /// 兩組之間，跟設定頁區塊與區塊之間一樣
    static let sectionGap: CGFloat = 14
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
}

/// 設定頁會開到 app 外面的兩個地方。
@MainActor
enum SettingsAboutLinks {
    /// 隱私政策頁。產品定稿只寫「放在 domyweb.org 一頁」，確切網址還沒定：這是預定的路徑，
    /// 上架前（片 J1）要跟實際放上去的那一頁對過。一律 https（安全標準類別 3）。
    static let privacyPolicy = URL(string: "https://domyweb.org/rencan/privacy")

    /// 系統設定裡這個 app 的那一頁，通知的開關在那裡。
    static var systemSettings: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
}

/// 版本那一列的字。
enum SettingsAboutVersion {
    /// 「1.0（23）」：版本號，括號裡是第幾次建置。
    static var text: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return (version ?? "未知") + "（" + (build ?? "未知") + "）"
    }
}

/// 設定頁最下面兩組（片 I2）：「權限」是授權狀態與到系統設定改，「關於」是隱私政策與版本。
/// 自己不包 ScrollView、不加左右邊距，由 SettingsView 排進去。
struct SettingsAboutSection: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            permissionGroup
            aboutGroup
        }
        // 使用者從系統設定改完回來，狀態要跟著變。
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await notifications.refreshPermission()
        }
    }

    private var permissionGroup: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "權限")
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                valueRow(
                    title: "通知", value: notificationStatus,
                    identifier: "about-notification-status"
                )
                // 掛點（組塊 E）：健康 app 的授權狀態列放這裡，前面補一條 RowDivider()，寫法照上面那一列：
                //   valueRow(title: "健康 app", value: 狀態文字, identifier: "about-health-status")
                RowDivider()
                Button {
                    if let url = SettingsAboutLinks.systemSettings {
                        openURL(url)
                    }
                } label: {
                    linkRow(title: "到系統設定改", systemImage: "chevron.right")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("about-open-settings")
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "關於")
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                if let url = SettingsAboutLinks.privacyPolicy {
                    Link(destination: url) {
                        linkRow(title: "隱私政策", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("about-privacy")
                    RowDivider()
                }
                valueRow(
                    title: "版本", value: SettingsAboutVersion.text, identifier: "about-version"
                )
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }

    private var notificationStatus: String {
        switch notifications.permission {
        case .notAsked:
            return "還沒問過"
        case .allowed:
            return "已允許"
        case .denied:
            return "沒有允許"
        }
    }

    /// 左邊名稱、右邊一個值的列（通知的狀態、版本）。
    private func valueRow(title: String, value: String, identifier: String) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Text(title)
                .font(RencanType.body)
            Spacer()
            Text(value)
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.textSecondary)
                .accessibilityIdentifier(identifier)
        }
        .frame(minHeight: RencanLayout.rowHeight)
    }

    /// 點了會離開這一頁的列：左邊名稱、右邊一個小箭頭。箭頭只是裝飾，VoiceOver 不讀。
    /// 用的地方一定要掛 `.buttonStyle(.plain)`：預設樣式在手機開了「按鈕形狀」時，
    /// 會在整列後面墊一塊米色膠囊，超出卡片內距、壓到分隔線（多米 2026-11-16 真機截圖）。
    private func linkRow(title: String, systemImage: String) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Text(title)
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.textPrimary)
            Spacer()
            Image(systemName: systemImage)
                .font(RencanType.footnote.weight(.semibold))
                .foregroundStyle(Color.rencan.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: RencanLayout.rowHeight)
        .contentShape(Rectangle())
    }
}
