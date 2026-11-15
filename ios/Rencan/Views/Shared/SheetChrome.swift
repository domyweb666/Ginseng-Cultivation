import SwiftUI

// 彈出表單共用的外框（畫布 LogSheet、MeasureSheet）。

/// 表單最上面那一列：左邊「取消」、中間標題。
/// 只是看、沒有要存的頁（單一功法頁）把左邊換成「關閉」。
struct SheetHeader: View {
    @Environment(AppFlow.self) private var flow
    let title: String
    var dismissLabel = "取消"

    var body: some View {
        ZStack {
            Text(title)
                .font(RencanType.headline)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(dismissLabel) {
                    flow.sheet = nil
                }
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.strong)
                .frame(minHeight: RencanLayout.tapTarget)
                Spacer()
            }
        }
        .padding(.horizontal, RencanLayout.screenMargin)
        .padding(.top, RencanLayout.sectionSpacing)
        .padding(.bottom, RencanLayout.itemSpacing)
    }
}

/// 淡金底的提示框：表單底下的預覽、說明。
struct HintPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, RencanLayout.sectionSpacing)
            .padding(.vertical, RencanLayout.groupSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.rencan.tint,
                in: RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
                    .stroke(Color.rencan.soft)
            )
    }
}
