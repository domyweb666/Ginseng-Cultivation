import SwiftUI
import VeggieKit

/// 這一區自己的版面常數（數值跟 SettingsView 的一樣，照畫布 Settings）。
private enum Metrics {
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
    /// 頁尾（圖示、版本號）離上面「關於」那張卡再多空一段。VeggieFooter 自己上下只留 24，
    /// 接在卡片下面太擠，像黏在一起（2026-11-21 多米真機看的，對照蒜日子約 48）
    static let footerTopGap: CGFloat = 24
}

/// 設定頁最下面（蔬菜家族共用規格，2026-11-19 照規格重排）：「關於」一區，加上頁尾。
/// 關於：蔬菜家族的其他 app（清單寫死在 VeggieKit，不連網；一個都沒上架就整列藏起來）、隱私權政策、開源授權。
/// 頁尾：app 圖示、「人蔘修煉 1.0（36）」、Made by DOMYWEB、官網臉書 IG；長按版本號複製版本資訊。
/// 原本的「權限」區拿掉了：通知搬到「一般」，健康 app 的授權本來就在「健康 app」區。
struct SettingsAboutSection: View {
    @Environment(AppFlow.self) private var flow

    @State private var page: AboutPage?

    private let config = VeggieConfig.rencan

    /// 關於區點進去的下一頁，用表單彈出來
    enum AboutPage: String, Identifiable {
        case family
        case licenses

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            aboutGroup
            VeggieFooter(config: config, logo: Image("AppLogo")) { text in
                flow.showToast(text)
            }
            .padding(.top, Metrics.footerTopGap)
        }
        .sheet(item: $page) { page in
            AboutPageSheet(page: page, config: config)
        }
    }

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: VeggieText.about)
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                if !VeggieApp.others(excluding: config.slug).isEmpty {
                    pageRow(.family, icon: "square.grid.2x2", title: VeggieText.family)
                    RowDivider()
                }
                if let url = config.privacyURL {
                    Link(destination: url) {
                        VeggieRow(
                            icon: "hand.raised", title: VeggieText.privacy, accessory: .external
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("about-privacy")
                    RowDivider()
                }
                pageRow(.licenses, icon: "doc.text", title: VeggieText.licenses)
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }

    private func pageRow(_ target: AboutPage, icon: String, title: String) -> some View {
        Button {
            page = target
        } label: {
            VeggieRow(icon: icon, title: title, accessory: .push)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("about-" + target.rawValue)
    }
}

/// 其他 app、開源授權那兩頁：包一層導覽（授權還要再點進去看全文），左上角「關閉」。
private struct AboutPageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let page: SettingsAboutSection.AboutPage
    let config: VeggieConfig

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("關閉") {
                            dismiss()
                        }
                        .foregroundStyle(Color.rencan.strong)
                    }
                }
        }
        .veggieStyle(.rencan)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .family:
            VeggieFamilyView(config: config)
        case .licenses:
            VeggieLicensesView(items: VeggieLicense.rencan)
        }
    }
}
