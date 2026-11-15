import RencanCore
import SwiftUI

/// 第一次打開：只問身高與性別（照畫布 Onboard）。沒有教學頁、沒有輪播（產品定稿「引導越少越好」）。
/// 性別沒選不能開始，也不預設成男（.vibe/女性版規則.md 第五節）。
/// 從健康 app 帶入身高與性別在組塊 E 接上。
struct FirstLaunchView: View {
    @Environment(StoreService.self) private var store
    /// 加減鈕的起點。使用者要自己調到對的數字再按開始，這不是替他假設的身高。
    @State private var heightCm = FirstLaunchView.startingHeightCm
    @State private var sex: Sex?
    @State private var errorMessage: String?

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
                if let errorMessage {
                    Text(errorMessage)
                        .font(RencanType.subheadline)
                        .foregroundStyle(Color.rencan.destructive)
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.top, RencanLayout.sectionSpacing)
        }
        .safeAreaInset(edge: .bottom) { startButton }
        .background(Color.rencan.canvas.ignoresSafeArea())
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var startButton: some View {
        if let sex {
            Button("開始") {
                start(sex)
            }
            .buttonStyle(RencanPrimaryButtonStyle())
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.vertical, RencanLayout.itemSpacing)
        } else {
            Text("選好性別再開始")
                .font(RencanType.headline)
                .foregroundStyle(Color.rencan.textSecondary)
                .frame(maxWidth: .infinity, minHeight: RencanLayout.buttonHeight)
                .background(
                    Color.rencan.surfaceMuted,
                    in: RoundedRectangle(cornerRadius: RencanLayout.buttonCornerRadius)
                )
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.vertical, RencanLayout.itemSpacing)
        }
    }

    private func start(_ sex: Sex) {
        do {
            try store.saveProfile(heightCm: heightCm, sex: sex)
        } catch {
            errorMessage = RencanError.message(for: error)
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
