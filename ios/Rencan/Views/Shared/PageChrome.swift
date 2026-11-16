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
    func rencanCard(cornerRadius: CGFloat = RencanLayout.cardCornerRadius) -> some View {
        padding(RencanLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rencan.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.rencan.shadow.opacity(RencanLayout.shadowOpacity),
                radius: RencanLayout.shadowRadius,
                y: RencanLayout.shadowY
            )
    }
}
