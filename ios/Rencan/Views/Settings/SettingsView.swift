import RencanCore
import SwiftUI
import VeggieKit

/// 這一頁自己的版面常數（數值照畫布 Settings）。
private enum Metrics {
    /// 區塊與區塊之間
    static let sectionGap: CGFloat = 14
    /// 大標題、區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
    /// 分段控制裡一格的寬與高
    static let segmentWidth: CGFloat = 56
    static let segmentHeight: CGFloat = 30
    static let segmentCornerRadius: CGFloat = 8
    /// 分段控制的底軌：比裡面的格子四邊各多出一點
    static let trackPadding: CGFloat = 2
    static let trackCornerRadius: CGFloat = 10
    /// 格子的點擊範圍拉到 44pt，底軌只畫中間那一段，看起來還是畫布上的高度
    static let trackVerticalInset = (RencanLayout.tapTarget - segmentHeight) / 2 - trackPadding
    /// 選中那格底下的小陰影
    static let segmentShadowRadius: CGFloat = 3
    static let segmentShadowY: CGFloat = 1
}

/// 設定頁（分頁列最右那格，照畫布 Settings）：文楷大標題，下面一區一張卡。
/// 順序照蔬菜家族共用規格（2026-11-19）：app 自己的設定（身體、立繪造型、健康 app、提醒）→
/// 一般 → 資料 → 購買、支援 → 關於與頁尾。後面幾區的列用 VeggieKit 的共用元件，顏色字體照人蔘修煉。
/// 每一區自己一個檔（Settings*Section.swift），這裡只管「身體」區與排順序。
struct SettingsView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    let digest: Digest
    /// 身高加減到一半、還沒存的數字；nil 是沒在改，畫面照 digest 顯示。
    @State private var draftHeightCm: Double?

    /// 身高停手多久才存。按住連走時每走一格都存的話，每格都要存檔、寫小工具、整份重算（2026-11-26 性能審查）。
    private static let heightSavePauseSeconds = 0.4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                header
                // 身高與性別沒填齊時 RootTabView 會停在第一次打開那頁，進不到這裡。
                if let heightCm = digest.heightCm, let sex = digest.sex {
                    bodySection(heightCm: heightCm, sex: sex)
                }
                SettingsStyleSection()
                SettingsHealthSection(digest: digest)
                SettingsReminderSection(digest: digest)
                SettingsGeneralSection()
                SettingsDataSection(digest: digest)
                SettingsSupportSection(digest: digest)
                SettingsAboutSection()
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.bottom, RencanLayout.sectionSpacing)
        }
        .veggieStyle(.rencan)
    }

    private var header: some View {
        HStack {
            Text("設定")
                .font(RencanType.pageTitle)
                .padding(.horizontal, Metrics.titleInset)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .frame(minHeight: RencanLayout.tapTarget)
        .padding(.top, RencanLayout.pageTitleTopInset)
    }

    /// 「身體」區：身高與性別同一張卡，改了馬上存，境界跟著重算。
    private func bodySection(heightCm: Double, sex: Sex) -> some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "身體")
                .padding(.horizontal, Metrics.titleInset)
            VStack(alignment: .leading, spacing: 0) {
                heightRow(heightCm: heightCm, sex: sex)
                RowDivider()
                sexRow(heightCm: heightCm, sex: sex)
            }
            .padding(.horizontal, Metrics.cardInset)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
        }
    }

    /// 身高直接放加減鈕（跟第一次打開那頁同一顆），不另開一頁。
    /// 加減時先顯示草稿的數字，停手一下才存；存完草稿就清掉，數字回到來自 digest：
    /// 存不進去時數字留在原本的值，不會停在沒存到的數字上。
    /// 停手前就離開這頁的話，離開那一刻馬上存，不會漏掉。
    private func heightRow(heightCm: Double, sex: Sex) -> some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            Text("身高")
                .font(RencanType.body)
            HeightStepper(
                heightCm: Binding(
                    get: { draftHeightCm ?? heightCm },
                    set: { draftHeightCm = $0 }
                )
            )
        }
        .padding(.vertical, RencanLayout.groupSpacing)
        .task(id: draftHeightCm) {
            guard draftHeightCm != nil else { return }
            guard await Task.pause(seconds: SettingsView.heightSavePauseSeconds) else { return }
            saveDraftHeight(sex: sex)
        }
        .onDisappear {
            saveDraftHeight(sex: sex)
        }
    }

    /// 把還沒存的身高存起來。先清草稿再存：存好了 digest 就是新的數字，存不進去就回到原本的值。
    private func saveDraftHeight(sex: Sex) {
        guard let draft = draftHeightCm else { return }
        draftHeightCm = nil
        save(heightCm: draft, sex: sex)
    }

    private func sexRow(heightCm: Double, sex: Sex) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Text("性別")
                .font(RencanType.body)
            Spacer()
            HStack(spacing: Metrics.trackPadding) {
                sexButton(.male, title: "男", heightCm: heightCm, current: sex)
                sexButton(.female, title: "女", heightCm: heightCm, current: sex)
            }
            .padding(.horizontal, Metrics.trackPadding)
            .background {
                RoundedRectangle(cornerRadius: Metrics.trackCornerRadius)
                    .fill(Color.rencan.surfaceMuted)
                    .padding(.vertical, Metrics.trackVerticalInset)
            }
        }
        .frame(minHeight: RencanLayout.rowHeight)
    }

    /// 分段控制的一格。選中的那格是白底加小陰影，字也比較深，不只靠顏色分。
    private func sexButton(
        _ value: Sex, title: String, heightCm: Double, current: Sex
    ) -> some View {
        let isSelected = value == current
        let textColor = isSelected ? Color.rencan.textPrimary : Color.rencan.textSecondary
        let shadowOpacity = isSelected ? RencanLayout.shadowOpacity : 0
        return Button {
            // 身高還在等停手時就點性別：連同還沒存的身高一起存，草稿清掉，等著的那次就不會再存一次
            let pendingHeightCm = draftHeightCm ?? heightCm
            draftHeightCm = nil
            save(heightCm: pendingHeightCm, sex: value)
        } label: {
            Text(title)
                .font(RencanType.subheadline.weight(.semibold))
                .foregroundStyle(textColor)
                .frame(minWidth: Metrics.segmentWidth, minHeight: Metrics.segmentHeight)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.segmentCornerRadius)
                        .fill(Color.rencan.surface.opacity(isSelected ? 1 : 0))
                        .shadow(
                            color: Color.rencan.shadow.opacity(shadowOpacity),
                            radius: Metrics.segmentShadowRadius,
                            y: Metrics.segmentShadowY
                        )
                }
                .frame(minHeight: RencanLayout.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 身高的範圍檢查在 StoreService.saveProfile 裡（沒過會丟錯），這裡不另寫一套，也不繞過。
    private func save(heightCm: Double, sex: Sex) {
        guard heightCm != digest.heightCm || sex != digest.sex else { return }
        do {
            try store.saveProfile(heightCm: heightCm, sex: sex)
        } catch {
            flow.showError(error)
        }
    }
}
