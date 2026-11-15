import SwiftUI

// 三頁共用的外框元件（畫布 https://claude.ai/artifact/R99HXs3rb9xRRaKEZNUZg2）。

/// 換頁的圖示按鈕：齒輪、分析圖示、回境界箭頭都是它。
/// 標籤是 Limrun 自驗腳本找元件的依據（「設定」「分析」「回境界」），改字要一起改腳本。
struct PageIconButton: View {
    @Environment(AppFlow.self) private var flow
    let target: RencanPage
    let systemImage: String
    let label: String

    var body: some View {
        Button {
            withAnimation { flow.page = target }
        } label: {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.rencan.strong)
                .frame(width: RencanLayout.tapTarget, height: RencanLayout.tapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

/// 側頁共用的「回境界」按鈕。設定頁在左，箭頭朝右；分析頁在右，箭頭朝左。
struct BackToRealmButton: View {
    let edge: HorizontalEdge

    var body: some View {
        PageIconButton(
            target: .realm,
            systemImage: edge == .leading ? "chevron.left" : "chevron.right",
            label: "回境界"
        )
    }
}

/// 底部頁點：選中那頁拉長成膠囊、用產品色，形狀不同，不只靠顏色分。
struct PageDots: View {
    let current: RencanPage

    var body: some View {
        HStack(spacing: RencanLayout.itemSpacing) {
            ForEach(RencanPage.allCases, id: \.self) { page in
                Capsule()
                    .fill(page == current ? Color.rencan.accent : Color.rencan.textTertiary)
                    .frame(
                        width: page == current
                            ? RencanLayout.pageDotActiveWidth : RencanLayout.pageDot,
                        height: RencanLayout.pageDot
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(current.rawValue + 1) 頁，共 \(RencanPage.allCases.count) 頁")
    }
}

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
