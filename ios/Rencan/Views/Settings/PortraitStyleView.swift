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
}

/// 選造型頁（組塊 M1）：上面是現在選的造型的大圖預覽，下面原版加十一種排成三欄。
/// 點一格就換、馬上存，境界碑與慶祝畫面跟著換。
/// M1 先讓每種都能直接選（付費計畫：先讓多米在手機上一種一種看），鎖、價格、購買鍵是 M3、M4。
/// 預覽和小圖都用使用者現在的境界與性別；還沒量過就用煉氣。
struct PortraitStyleView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Query private var settingsRows: [UserSettings]
    let digest: Digest

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "立繪造型", dismissLabel: "完成")
            ScrollView {
                VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                    preview
                    grid
                }
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.bottom, RencanLayout.sectionSpacing)
            }
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
    }

    private var selected: PortraitStyle {
        settingsRows.first?.portraitStyle ?? .original
    }

    private var realmIndex: Int { digest.stele?.standing.realmIndex ?? 0 }
    private var sex: Sex { digest.sex ?? .male }

    private var preview: some View {
        HStack(alignment: .bottom, spacing: Metrics.previewSpacing) {
            portrait(selected, size: RencanLayout.portraitSize)
                .clipShape(RoundedRectangle(cornerRadius: RencanLayout.portraitCornerRadius))
                .accessibilityLabel(selected.displayName + "造型的立繪")
            Text(selected.displayName)
                .font(RencanType.sectTitle)
                .foregroundStyle(Color.rencan.strong)
                .accessibilityIdentifier("style-preview-name")
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
        let isSelected = style == selected
        return Button {
            choose(style)
        } label: {
            VStack(spacing: RencanLayout.itemSpacing) {
                portrait(style, size: Metrics.thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.thumbnailCornerRadius))
                Text(style.displayName)
                    .font(RencanType.footnote.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.rencan.strong : Color.rencan.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(RencanLayout.minimumTextScale)
            }
            .padding(.vertical, RencanLayout.groupSpacing)
            .frame(maxWidth: .infinity)
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
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("style-" + style.rawValue)
    }

    /// 立繪放大或縮小都用整數倍、關掉平滑，像素格子才不會糊。
    private func portrait(_ style: PortraitStyle, size: CGSize) -> some View {
        Image(RencanPortrait.name(realmIndex: realmIndex, sex: sex, style: style))
            .interpolation(.none)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
    }

    private func choose(_ style: PortraitStyle) {
        guard style != selected else { return }
        do {
            try store.setPortraitStyle(style)
            HapticsService.light()
        } catch {
            flow.showError(error)
        }
    }
}
