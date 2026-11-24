import RencanCore
import SwiftUI

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
    /// 正在問健康 app。這段時間「從健康 app 帶入」那顆不能再按。
    @State private var isReadingHealth = false
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

    private var intro: some View {
        VStack(spacing: RencanLayout.itemSpacing) {
            Image(RencanPortrait.name(realmIndex: 0, sex: sex ?? .male))
                .interpolation(.none)
                .resizable()
                .scaledToFill()
                .frame(
                    width: RencanLayout.portraitSize.width,
                    height: RencanLayout.portraitSize.height
                )
                .background(Color.rencan.tint)
                .clipShape(RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius))
                .accessibilityHidden(true)
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

/// 身高的加減鈕：一次一公分，按住會連續加減。第一次打開與設定頁共用。
struct HeightStepper: View {
    @Binding var heightCm: Double
    /// 加減了幾格。按鈕只動這個數，真正改身高在 onChange：設定頁每走一格就存檔重畫，按住時系統一直叫
    /// 按下去那一刻的動作，裡面的身高是舊的，會停在第一格（2026-11-25 檢查線實測）。
    @State private var steps = 0

    var body: some View {
        HStack {
            RoundStepperButton(systemImage: "minus", label: "身高減一公分") {
                steps -= 1
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
                steps += 1
            }
        }
        .onChange(of: steps) { old, new in
            let range = Tables.heightRangeCm
            heightCm = min(range.upperBound, max(range.lowerBound, heightCm + Double(new - old)))
        }
    }
}
