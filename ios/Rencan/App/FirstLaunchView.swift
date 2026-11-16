import RencanCore
import SwiftUI

/// 這一頁自己的版面常數。
private enum Metrics {
    /// 立繪旁邊的小人蔘（PRD S29：問身高那頁用大的那一級）
    static let mascotHeight: CGFloat = 96
    /// 小人蔘與立繪之間的縫
    static let mascotGap: CGFloat = 8
}

/// 第一次打開：只問身高與性別（照畫布 Onboard）。沒有教學頁、沒有輪播（產品定稿「引導越少越好」）。
/// 性別沒選不能開始，也不預設成男（.vibe/女性版規則.md 第五節）。
/// 健康 app 可用時，這一頁一出現就問一次讀取授權（一次五種），抓得到身高就帶進身高欄、
/// 抓得到生理性別就先選好；兩樣都抓到直接存檔進三頁（PRD S1）。抓不到或被拒絕就照手填。
struct FirstLaunchView: View {
    @Environment(StoreService.self) private var store
    @Environment(HealthKitService.self) private var health
    /// 加減鈕的起點。使用者要自己調到對的數字再按開始，這不是替他假設的身高。
    @State private var heightCm = FirstLaunchView.startingHeightCm
    @State private var sex: Sex?
    @State private var errorMessage: String?
    /// 正在問健康 app。這段時間小人蔘從揮手換成思考（片 K4）。
    @State private var isReadingHealth = false
    /// 健康 app 讀不出來。小人蔘換成抓頭，紅字講原因，手填照常能用。
    @State private var didHealthFail = false
    /// 從健康 app 帶了什麼進來、還缺什麼的那句話。
    @State private var healthNote: String?

    private static let startingHeightCm: Double = 170

    var body: some View {
        ScrollView {
            VStack(spacing: RencanLayout.sectionSpacing) {
                intro
                form
                Text("境界用身高校正過的 FFMI 算，男女各一套標準，之後可以在設定改。")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
                    .multilineTextAlignment(.center)
                if let healthNote {
                    Text(healthNote)
                        .font(RencanType.footnote)
                        .foregroundStyle(Color.rencan.textSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("first-health-note")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(RencanType.subheadline)
                        .foregroundStyle(Color.rencan.destructive)
                        .accessibilityIdentifier("first-error")
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.top, RencanLayout.sectionSpacing)
        }
        .safeAreaInset(edge: .bottom) { bottomButtons }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .task {
            await fillFromHealth(isAskedByUser: false)
        }
    }

    /// 小人蔘平常揮手（片 K3）；正在問健康 app 是思考、讀不出來是抓頭（片 K4）。
    private var mascotAction: MascotAction {
        if isReadingHealth { return .think }
        return didHealthFail ? .oops : .wave
    }

    private var intro: some View {
        VStack(spacing: RencanLayout.itemSpacing) {
            Image(RencanPortrait.name(realmIndex: 0, sex: sex ?? .male))
                .resizable()
                .scaledToFill()
                .frame(
                    width: RencanLayout.portraitSize.width,
                    height: RencanLayout.portraitSize.height
                )
                .background(Color.rencan.tint)
                .clipShape(RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius))
                .accessibilityHidden(true)
                .overlay(alignment: .bottomTrailing) {
                    PortraitSideMascot(action: mascotAction, height: Metrics.mascotHeight)
                }
            Text("人蔘修煉")
                .font(RencanType.pageTitle)
                .foregroundStyle(Color.rencan.strong)
                .accessibilityAddTraits(.isHeader)
            Text("先說你多高、男生還是女生，境界就能算。")
                .font(RencanType.body)
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                Text("身高")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
                HeightStepper(heightCm: $heightCm)
            }
            RowDivider()
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                Text("性別")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
                HStack(spacing: RencanLayout.groupSpacing) {
                    sexButton(.male, title: "男")
                    sexButton(.female, title: "女")
                }
            }
        }
        .rencanCard(cornerRadius: RencanLayout.heroCornerRadius)
    }

    private func sexButton(_ value: Sex, title: String) -> some View {
        let isSelected = sex == value
        return Button {
            sex = value
        } label: {
            Text(title)
                .font(RencanType.headline)
                .foregroundStyle(isSelected ? Color.rencan.onAccent : Color.rencan.textPrimary)
                .frame(maxWidth: .infinity, minHeight: RencanLayout.buttonHeight)
                .background(
                    isSelected ? Color.rencan.accent : Color.rencan.surfaceMuted,
                    in: RoundedRectangle(cornerRadius: RencanLayout.fieldCornerRadius)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 底部兩顆（照畫布 Onboard）：上面是「從健康 app 帶入身高與性別」，下面是開始。
    /// 裝置沒有健康 app 時上面那顆不出現，按了也帶不到東西。
    private var bottomButtons: some View {
        VStack(spacing: 0) {
            if health.isAvailable {
                Button("從健康 app 帶入身高與性別") {
                    Task { await fillFromHealth(isAskedByUser: true) }
                }
                .font(RencanType.headline)
                .foregroundStyle(Color.rencan.strong)
                .frame(maxWidth: .infinity, minHeight: RencanLayout.tapTarget)
                .disabled(isReadingHealth)
                .accessibilityIdentifier("first-health-fill")
            }
            startButton
                .padding(.vertical, RencanLayout.itemSpacing)
        }
        .padding(.horizontal, RencanLayout.screenMargin)
    }

    @ViewBuilder
    private var startButton: some View {
        if let sex {
            Button("開始") {
                start(sex)
            }
            .buttonStyle(RencanPrimaryButtonStyle())
        } else {
            Text("選好性別再開始")
                .font(RencanType.headline)
                .foregroundStyle(Color.rencan.textSecondary)
                .frame(maxWidth: .infinity, minHeight: RencanLayout.buttonHeight)
                .background(
                    Color.rencan.surfaceMuted,
                    in: RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
                )
        }
    }

    private func start(_ sex: Sex) {
        do {
            try store.saveProfile(heightCm: heightCm, sex: sex)
        } catch {
            errorMessage = RencanError.message(for: error)
        }
    }

    /// 問健康 app 的讀取授權（系統只會跳一次視窗），再把身高與生理性別帶進來。
    /// 身高取到整公分，跟加減鈕一格一公分對得上。兩樣都有就直接開始（PRD S1）。
    /// isAskedByUser：使用者自己按了那顆按鈕。這時候什麼都沒帶到也要講一聲，
    /// 一打開自動問的那一次沒帶到就安靜地照手填。
    private func fillFromHealth(isAskedByUser: Bool) async {
        guard health.isAvailable, !isReadingHealth else { return }
        isReadingHealth = true
        defer { isReadingHealth = false }
        do {
            try await health.requestReadAuthorization()
            let foundHeight = try await health.latestHeightCm()
            let foundSex = try health.biologicalSex()
            didHealthFail = false
            errorMessage = nil
            if let foundHeight {
                heightCm = foundHeight.rounded()
            }
            if let foundSex {
                sex = foundSex
            }
            healthNote = FirstLaunchText.healthNote(
                hasHeight: foundHeight != nil, hasSex: foundSex != nil,
                isAskedByUser: isAskedByUser
            )
            if foundHeight != nil, let foundSex {
                start(foundSex)
            }
        } catch {
            didHealthFail = true
            healthNote = nil
            errorMessage = (error as? HealthError)?.message ?? RencanError.message(for: error)
        }
    }
}

/// 第一次打開那頁從健康 app 帶入之後要講的話。
enum FirstLaunchText {
    static func healthNote(hasHeight: Bool, hasSex: Bool, isAskedByUser: Bool) -> String? {
        switch (hasHeight, hasSex) {
        case (true, true):
            return nil
        case (true, false):
            return "身高從健康 app 帶進來了，性別請自己選。"
        case (false, true):
            return "性別從健康 app 帶進來了，身高請自己調。"
        case (false, false):
            return isAskedByUser ? "健康 app 裡沒讀到身高和性別，請自己填。" : nil
        }
    }
}

/// 站在立繪右下角外面的小人蔘：掛在立繪的 overlay 上，立繪照舊置中，版面不會被擠。
/// 第一次打開那頁與境界頁的空狀態共用。
struct PortraitSideMascot: View {
    let action: MascotAction
    let height: CGFloat

    var body: some View {
        MascotView(action: action, height: height)
            .alignmentGuide(.trailing) { dimensions in
                dimensions[.leading] - Metrics.mascotGap
            }
    }
}

/// 身高的加減鈕：一次一公分，按住會連續加減。第一次打開與設定頁共用。
struct HeightStepper: View {
    @Binding var heightCm: Double

    var body: some View {
        HStack {
            RoundStepperButton(systemImage: "minus", label: "身高減一公分") {
                heightCm = max(Tables.heightRangeCm.lowerBound, heightCm - 1)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: RencanLayout.chipVerticalPadding) {
                Text(Formulas.fmt(heightCm, digits: 0))
                    .font(RencanType.bigNumber)
                    .accessibilityIdentifier("height-value")
                Text("公分")
                    .font(RencanType.body)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            RoundStepperButton(systemImage: "plus", label: "身高加一公分") {
                heightCm = min(Tables.heightRangeCm.upperBound, heightCm + 1)
            }
        }
    }
}
