import RencanCore
import SwiftUI
import VeggieKit

/// 這一區自己的版面常數（數值跟 SettingsView 的一樣，照畫布 Settings）。
private enum Metrics {
    /// 兩組之間，跟設定頁區塊與區塊之間一樣
    static let sectionGap: CGFloat = 14
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
}

/// 設定頁「購買」與「支援」兩區（蔬菜家族共用規格，2026-11-19 加）。
/// 購買：恢復購買（原本只在選造型頁裡有，規格要設定頁也一列）。
/// 支援：意見回饋（系統寫信畫面，信末只帶版本、iOS、機型、語言，不帶任何體重體脂）、
/// 在 App Store 評分（有 Apple ID 才出現）、分享給朋友（量過就開修煉卡，還沒量過送一句介紹）。
struct SettingsSupportSection: View {
    @Environment(AppFlow.self) private var flow
    @Environment(PurchaseService.self) private var purchases
    @Environment(\.openURL) private var openURL
    let digest: Digest

    @State private var isRestoring = false
    @State private var isWritingMail = false

    private let config = VeggieConfig.rencan

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            group(VeggieText.purchase) {
                restoreRow
            }
            group(VeggieText.support) {
                feedbackRow
                if let url = config.writeReviewURL {
                    RowDivider()
                    Link(destination: url) {
                        VeggieRow(icon: "star", title: VeggieText.rate, accessory: .external)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-rate")
                }
                RowDivider()
                shareRow
            }
        }
    }

    private func group(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: title)
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                rows()
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }

    // MARK: 購買

    private var restoreRow: some View {
        Button {
            Task { await restore() }
        } label: {
            VeggieRow(icon: "arrow.clockwise", title: VeggieText.restore)
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
        .accessibilityIdentifier("settings-restore")
    }

    /// 成功、沒找到、失敗各一句（規格寫好的三句）。買過什麼只認 Apple 驗證過的交易，跟選造型頁同一個來源。
    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await purchases.restore()
        } catch {
            flow.showToast(VeggieText.restoreFailed)
            return
        }
        let hasPurchases = !purchases.ownedProductIDs.isEmpty
        flow.showToast(hasPurchases ? VeggieText.restored : VeggieText.restoreNothing)
    }

    // MARK: 支援

    /// 手機有設郵件帳號就開系統寫信畫面；沒有就交給別的寄信 app（mailto），連那也沒有才說寄不出去。
    @ViewBuilder
    private var feedbackRow: some View {
        if let address = config.supportEmail {
            Button {
                writeFeedback(to: address)
            } label: {
                VeggieRow(icon: "envelope", title: VeggieText.feedback, accessory: .push)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-feedback")
            .sheet(isPresented: $isWritingMail) {
                FeedbackMailView(recipient: address, feedback: Feedback(config: config)) {
                    isWritingMail = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private func writeFeedback(to address: String) {
        if Feedback.canUseMailSheet {
            isWritingMail = true
            return
        }
        guard let url = Feedback(config: config).mailtoURL(to: address) else {
            flow.showToast(SettingsSupportText.noMailApp)
            return
        }
        openURL(url) { accepted in
            if !accepted {
                flow.showToast(SettingsSupportText.noMailApp)
            }
        }
    }

    /// 量過、有境界碑：打開修煉卡（跟境界頁右上角同一張）。還沒量過沒有卡，送 app 的一句話介紹。
    @ViewBuilder
    private var shareRow: some View {
        if digest.stele != nil {
            Button {
                flow.sheet = .shareCard
            } label: {
                VeggieRow(icon: "square.and.arrow.up", title: VeggieText.share, accessory: .push)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-share")
        } else {
            ShareLink(item: config.shareText) {
                VeggieRow(
                    icon: "square.and.arrow.up", title: VeggieText.share, accessory: .external
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-share")
        }
    }
}

/// 支援區畫面上的字。
enum SettingsSupportText {
    static let noMailApp = "這支手機沒有可以寄信的 app"
}
