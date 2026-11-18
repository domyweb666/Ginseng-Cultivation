import RencanCore
import SwiftData
import SwiftUI

/// 這一頁自己的版面常數（照畫布 InAppShop 選造型頁）。
private enum Metrics {
    /// 格子排幾欄：原版加十一種剛好四排
    static let columnCount = 3
    /// 格子裡的小圖：立繪原圖 168×210 的一半，像素才排得齊
    static let thumbnailSize = CGSize(width: 84, height: 105)
    static let thumbnailCornerRadius: CGFloat = 8
    /// 選中那格的外框
    static let selectedBorderWidth: CGFloat = 2
    /// 大圖預覽與名字之間
    static let previewSpacing: CGFloat = 16
    /// 小鎖離小圖右上角的距離
    static let lockInset: CGFloat = 4
}

/// 選造型頁（組塊 M1 換造型、M4 加鎖與購買）：上面是大圖預覽，下面原版加十一種排成三欄，
/// 再下面是「全套十一種」。底部固定一顆購買鍵。
/// - 買過的（原版免費）點了就換、馬上存，境界碑與慶祝畫面跟著換。
/// - 沒買的有小鎖，點了只換預覽、不存；要買按底下的購買鍵，買到才換上。
/// - 價格字串用 Apple 給的；讀不到就寫「連不上 App Store」，購買鍵不能按（出錯倒向鎖住）。
/// 預覽和小圖都用使用者現在的境界與性別；還沒量過就用煉氣。
struct PortraitStyleView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Environment(PurchaseService.self) private var purchases
    @Query private var settingsRows: [UserSettings]
    let digest: Digest

    /// 點了還沒買的造型：只換預覽。nil 時預覽跟著現在套用的造型。
    @State private var previewing: PortraitStyle?
    /// 選中的是「全套十一種」那張卡
    @State private var isBundleSelected = false
    /// 正在跟 App Store 買或恢復，按鈕先停用，免得連按兩次
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "立繪造型", dismissLabel: "完成")
            ScrollView {
                VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                    preview
                    grid
                    if !purchases.ownsEverything {
                        bundleCard
                    }
                    restoreButton
                }
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.bottom, RencanLayout.sectionSpacing)
            }
            .safeAreaInset(edge: .bottom) {
                if let productID = purchaseTarget {
                    buyBar(productID)
                }
            }
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .task {
            await purchases.refresh()
        }
    }

    /// 現在套用的造型：存的那個，沒買（或退款了）就是原版。
    private var applied: PortraitStyle {
        purchases.effective(settingsRows.first?.portraitStyle ?? .original)
    }

    /// 大圖預覽上的造型
    private var shown: PortraitStyle { previewing ?? applied }

    /// 底下購買鍵要買的商品。選中全套、或正在預覽一種沒買的，才有。
    private var purchaseTarget: String? {
        if isBundleSelected { return PurchaseService.bundleProductID }
        guard !purchases.owns(shown) else { return nil }
        return shown.productID
    }

    private var realmIndex: Int { digest.stele?.standing.realmIndex ?? 0 }
    private var sex: Sex { digest.sex ?? .male }

    private var preview: some View {
        HStack(alignment: .bottom, spacing: Metrics.previewSpacing) {
            portrait(shown, size: RencanLayout.portraitSize)
                .clipShape(RoundedRectangle(cornerRadius: RencanLayout.portraitCornerRadius))
                .accessibilityLabel(shown.displayName + "造型的立繪")
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                Text(shown.displayName)
                    .font(RencanType.sectTitle)
                    .foregroundStyle(Color.rencan.strong)
                    .accessibilityIdentifier("style-preview-name")
                if !purchases.owns(shown) {
                    Text("還沒買，先看看樣子")
                        .font(RencanType.footnote)
                        .foregroundStyle(Color.rencan.textSecondary)
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: RencanLayout.groupSpacing),
                count: Metrics.columnCount
            ),
            spacing: RencanLayout.groupSpacing
        ) {
            ForEach(PortraitStyle.allCases) { style in
                cell(style)
            }
        }
    }

    private func cell(_ style: PortraitStyle) -> some View {
        let isSelected = !isBundleSelected && style == shown
        let isOwned = purchases.owns(style)
        return Button {
            choose(style)
        } label: {
            VStack(spacing: RencanLayout.itemSpacing) {
                portrait(style, size: Metrics.thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.thumbnailCornerRadius))
                    .overlay(alignment: .topTrailing) {
                        if !isOwned {
                            lockBadge
                        }
                    }
                Text(style.displayName)
                    .font(RencanType.footnote.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.rencan.strong : Color.rencan.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(RencanLayout.minimumTextScale)
            }
            .padding(.vertical, RencanLayout.groupSpacing)
            .frame(maxWidth: .infinity)
            .modifier(ChoiceCard(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOwned ? style.displayName : style.displayName + "，還沒買")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("style-" + style.rawValue)
    }

    /// 小圖右上角的小鎖。只是記號，VoiceOver 讀格子的「還沒買」就好。
    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(RencanType.caption)
            .foregroundStyle(Color.rencan.onAccent)
            .padding(Metrics.lockInset)
            .background(Color.rencan.strong, in: Circle())
            .padding(Metrics.lockInset)
            .accessibilityHidden(true)
    }

    /// 全套十一種：一張橫的卡，點了選中，底下的購買鍵就變成買全套。
    private var bundleCard: some View {
        Button {
            isBundleSelected = true
        } label: {
            HStack(spacing: RencanLayout.groupSpacing) {
                VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                    Text("全套十一種")
                        .font(RencanType.headline)
                        .foregroundStyle(bundleTitleColor)
                    Text("十一種造型一次買下，男女七個境界都能換")
                        .font(RencanType.footnote)
                        .foregroundStyle(Color.rencan.textSecondary)
                }
                Spacer(minLength: 0)
                Text(purchases.displayPrices[PurchaseService.bundleProductID] ?? "")
                    .font(RencanType.headline)
                    .foregroundStyle(Color.rencan.strong)
            }
            .padding(RencanLayout.groupSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(ChoiceCard(isSelected: isBundleSelected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isBundleSelected ? .isSelected : [])
        .accessibilityIdentifier("style-bundle")
    }

    private var bundleTitleColor: Color {
        isBundleSelected ? Color.rencan.strong : Color.rencan.textPrimary
    }

    private var restoreButton: some View {
        Button("恢復購買") {
            Task { await restore() }
        }
        .font(RencanType.body)
        .foregroundStyle(Color.rencan.strong)
        .frame(maxWidth: .infinity, minHeight: RencanLayout.tapTarget)
        .disabled(isWorking)
        .accessibilityIdentifier("style-restore")
    }

    /// 底部固定的購買鍵。讀不到價格時改寫「連不上 App Store」、不能按。
    private func buyBar(_ productID: String) -> some View {
        let price = purchases.isStoreUnavailable ? nil : purchases.displayPrices[productID]
        let name = isBundleSelected ? "全套十一種" : shown.displayName
        return VStack(spacing: RencanLayout.itemSpacing) {
            Button {
                Task { await buy(productID) }
            } label: {
                Text(price.map { "購買「\(name)」 \($0)" } ?? "連不上 App Store")
            }
            .buttonStyle(RencanPrimaryButtonStyle())
            .disabled(price == nil || isWorking)
            .accessibilityIdentifier("style-buy")
        }
        .padding(.horizontal, RencanLayout.screenMargin)
        .padding(.vertical, RencanLayout.itemSpacing)
        .background(Color.rencan.canvas)
    }

    /// 立繪放大或縮小都用整數倍、關掉平滑，像素格子才不會糊。
    private func portrait(_ style: PortraitStyle, size: CGSize) -> some View {
        Image(RencanPortrait.name(realmIndex: realmIndex, sex: sex, style: style))
            .interpolation(.none)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
    }

    /// 點一格：買過的直接換上，沒買的只換預覽。
    private func choose(_ style: PortraitStyle) {
        isBundleSelected = false
        guard purchases.owns(style) else {
            previewing = style
            return
        }
        previewing = nil
        apply(style)
    }

    private func apply(_ style: PortraitStyle) {
        guard style != settingsRows.first?.portraitStyle else { return }
        do {
            try store.setPortraitStyle(style)
            HapticsService.light()
        } catch {
            flow.showError(error)
        }
    }

    /// 買到了就把正在預覽的那種換上（買全套時也是），回到「跟著套用的造型」。
    /// 使用者自己按取消不算錯，什麼都不說。
    private func buy(_ productID: String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            guard try await purchases.purchase(productID) else { return }
            let bought = shown
            isBundleSelected = false
            previewing = nil
            if purchases.owns(bought) {
                apply(bought)
            }
            flow.showToast("買好了，已經換上")
        } catch {
            flow.showError(error)
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await purchases.restore()
            flow.showToast(purchases.ownedProductIDs.isEmpty ? "沒有找到買過的造型" : "已經恢復買過的造型")
        } catch {
            flow.showError(error)
        }
    }
}

/// 格子與全套卡共用的底色與選中外框。
private struct ChoiceCard: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                isSelected ? Color.rencan.tint : Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
                    .stroke(
                        isSelected ? Color.rencan.accent : Color.clear,
                        lineWidth: Metrics.selectedBorderWidth
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius))
    }
}
