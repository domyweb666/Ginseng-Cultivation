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
