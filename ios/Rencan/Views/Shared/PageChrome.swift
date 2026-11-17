import SwiftUI

// 三頁共用的按鈕樣式（畫布 https://claude.ai/artifact/R99HXs3rb9xRRaKEZNUZg2）。

/// 主按鈕：產品色實心，一個畫面最多一顆。
struct RencanPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RencanType.headline)
            .foregroundStyle(Color.rencan.onAccent)
            .frame(maxWidth: .infinity, minHeight: RencanLayout.buttonHeight)
            .background(
                Color.rencan.accent,
                in: RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 浮動的主按鈕：膠囊形、寬度跟著字走、底下有陰影。境界頁的「記一筆修煉」用。
struct RencanFloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RencanType.headline)
            .foregroundStyle(Color.rencan.onAccent)
            .padding(.horizontal, RencanLayout.floatingButtonPadding)
            .frame(minHeight: RencanLayout.buttonHeight)
            .background(Color.rencan.accent, in: Capsule())
            .shadow(
                color: Color.rencan.shadow.opacity(RencanLayout.floatingShadowOpacity),
                radius: RencanLayout.floatingShadowRadius,
                y: RencanLayout.floatingShadowY
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 次要按鈕：淺灰底，一個畫面可以有幾顆。
struct RencanSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RencanType.headline)
            .foregroundStyle(Color.rencan.textPrimary)
            .frame(maxWidth: .infinity, minHeight: RencanLayout.secondaryButtonHeight)
            .background(
                Color.rencan.surfaceMuted,
                in: RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 底部分頁列：浮在底部的半透明膠囊，三格由左到右是設定、境界、分析，選中那格墊一塊淺灰、字變產品色。
/// 樣子照 iOS 26 原生的浮動分頁列（2026-11-18 為了能左右滑改成自己畫，見 PagesView）。
struct RencanTabBar: View {
    @Binding var page: RencanPage

    /// 一格的寬高、膠囊的內距
    private static let itemWidth: CGFloat = 88
    private static let itemHeight: CGFloat = 54
    private static let barPadding: CGFloat = 4
    /// 圖示與字之間
    private static let iconLabelSpacing: CGFloat = 2
    /// 有 Home 條的手機，分頁列往下沉進底部留白多少（原生的分頁列也沉在那裡）
    private static let sinkIntoSafeArea: CGFloat = 14
    /// 沒有 Home 條的手機（底部不留白），分頁列離螢幕底至少這麼遠
    private static let minimumBottomGap: CGFloat = 8
    /// 分頁列上面再空一點，內容的最後一行才不會貼著它
    private static let topGap: CGFloat = 8
    private static let barHeight = itemHeight + barPadding * 2

    /// 分頁列底邊離螢幕底多遠。
    static func bottomGap(safeAreaBottom: CGFloat) -> CGFloat {
        max(safeAreaBottom - sinkIntoSafeArea, minimumBottomGap)
    }

    /// 每一頁的底部要讓出多高（從底部留白的上緣算起）。
    static func clearance(safeAreaBottom: CGFloat) -> CGFloat {
        max(bottomGap(safeAreaBottom: safeAreaBottom) + barHeight + topGap - safeAreaBottom, 0)
    }

    var body: some View {
        HStack(spacing: 0) {
            item(.settings, title: "設定", symbol: "gearshape")
            item(.realm, title: "境界", symbol: "mountain.2")
            item(.analysis, title: "分析", symbol: "chart.xyaxis.line")
        }
        .padding(Self.barPadding)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.rencan.separator))
        .shadow(
            color: Color.rencan.shadow.opacity(RencanLayout.floatingShadowOpacity),
            radius: RencanLayout.floatingShadowRadius,
            y: RencanLayout.floatingShadowY
        )
    }

    private func item(_ target: RencanPage, title: String, symbol: String) -> some View {
        let isSelected = page == target
        return Button {
            withAnimation(.easeInOut(duration: RencanLayout.fadeSeconds)) {
                page = target
            }
        } label: {
            VStack(spacing: Self.iconLabelSpacing) {
                Image(systemName: symbol)
                    .symbolVariant(.fill)
                    .font(RencanType.tabIcon)
                Text(title)
                    .font(RencanType.caption)
            }
            .foregroundStyle(isSelected ? Color.rencan.accent : Color.rencan.textPrimary)
            .frame(width: Self.itemWidth, height: Self.itemHeight)
            .background {
                if isSelected {
                    Capsule().fill(Color.rencan.surfaceMuted)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tab-\(title)")
    }
}

extension View {
    /// 白卡：分組內容放這裡，相關的列放同一張，不要每列各包一張。
    /// 上下內距預設跟左右一樣；只有一行字的小卡（境界頁的宗門小卡）用小一點的。
    func rencanCard(
        cornerRadius: CGFloat = RencanLayout.cardCornerRadius,
        verticalPadding: CGFloat = RencanLayout.cardPadding
    ) -> some View {
        padding(.horizontal, RencanLayout.cardPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rencan.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.rencan.shadow.opacity(RencanLayout.shadowOpacity),
                radius: RencanLayout.shadowRadius,
                y: RencanLayout.shadowY
            )
    }
}
