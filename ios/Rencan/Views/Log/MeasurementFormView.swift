import RencanCore
import SwiftData
import SwiftUI

/// 從健康 app 帶進欄位的那一筆當時的樣子：三欄的字與日期。
/// 存檔時欄位還跟它一樣，這筆的來源才記健康 app；改過任何一欄就算手打的。
private struct HealthFill: Equatable {
    let weightText: String
    let bodyFatText: String
    let leanText: String
    let day: String
}

/// 手動輸入體組成的彈出表單（照畫布 MeasureSheet）：體重、體脂率、去脂體重（選填）、日期，
/// 下面預覽結算後的境界。同一天已經有一筆時先問要不要蓋掉（PRD S9）。
/// 健康 app 有比本機還新的一筆時，三欄與日期先帶好，只要按「結算境界」（PRD S2）。
/// 回寫開著時，手打的那筆存好之後寫回健康 app（PRD S25）。
struct MeasurementFormView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Environment(HealthKitService.self) private var health
    @Environment(PurchaseService.self) private var purchases
    @Query private var settingsRows: [UserSettings]
    let digest: Digest

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var leanText = ""
    @State private var date = Date()
    @State private var errorMessage: String?
    @State private var isAskingReplace = false
    @State private var isLoaded = false
    @State private var healthFill: HealthFill?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "輸入體組成")
            content
            Button("結算境界") {
                submit(replacing: false)
            }
            .buttonStyle(RencanPrimaryButtonStyle())
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.vertical, RencanLayout.itemSpacing)
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .onAppear(perform: load)
        .task {
            await fillFromHealth()
        }
        .confirmationDialog(
            "這一天已經有一筆量測，要蓋掉嗎？", isPresented: $isAskingReplace,
            titleVisibility: .visible
        ) {
            Button("蓋掉", role: .destructive) {
                submit(replacing: true)
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RencanLayout.groupSpacing) {
                fields
                if let healthFill, healthFill == currentFill {
                    Text("已帶入健康 app " + DayStamp.monthDay(healthFill.day) + "的量測。")
                        .font(RencanType.footnote)
                        .foregroundStyle(Color.rencan.strong)
                        .accessibilityIdentifier("health-fill-note")
                }
                Text("體脂秤有給去脂體重就填，會直接用那個數字；沒填就用體脂率換算。")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
                sourcesRow
                datePicker
                preview
                if let errorMessage {
                    Text(errorMessage)
                        .font(RencanType.subheadline)
                        .foregroundStyle(Color.rencan.destructive)
                        .accessibilityIdentifier("form-error")
                }
            }
            .padding(.horizontal, RencanLayout.screenMargin)
            .padding(.bottom, RencanLayout.sectionSpacing)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var fields: some View {
        VStack(spacing: 0) {
            field("體重", text: $weightText, unit: "公斤", placeholder: "", identifier: "weight")
            RowDivider()
            field("體脂率", text: $bodyFatText, unit: "%", placeholder: "", identifier: "bodyfat")
            RowDivider()
            field(
                "去脂體重（選填）", text: $leanText, unit: "公斤", placeholder: "自動算",
                identifier: "lean"
            )
        }
        .padding(.horizontal, RencanLayout.sectionSpacing)
        .background(
            Color.rencan.surface, in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private func field(
        _ title: String, text: Binding<String>, unit: String, placeholder: String,
        identifier: String
    ) -> some View {
        HStack(spacing: RencanLayout.itemSpacing) {
            Text(title)
                .font(RencanType.body)
            Spacer(minLength: 0)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(RencanType.title3)
                .frame(width: RencanLayout.numberFieldWidth)
                .padding(.horizontal, RencanLayout.itemSpacing)
                .frame(minHeight: RencanLayout.numberFieldHeight)
                .background(
                    Color.rencan.canvas,
                    in: RoundedRectangle(cornerRadius: RencanLayout.fieldCornerRadius)
                )
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .frame(width: RencanLayout.unitWidth, alignment: .leading)
        }
        .frame(minHeight: RencanLayout.formRowHeight)
    }

    /// 出處放在欄位正下方，不用捲就看得到：2026-11-23 審查點名這張表單的計算沒有出處（1.4.1）。
    private var sourcesRow: some View {
        HealthSourcesRow()
            .padding(.horizontal, RencanLayout.sectionSpacing)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
    }

    private var datePicker: some View {
        DatePicker("量測日期", selection: $date, in: ...Date(), displayedComponents: .date)
            .font(RencanType.body)
            .padding(.horizontal, RencanLayout.sectionSpacing)
            .frame(minHeight: RencanLayout.rowHeight)
            .background(
                Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
            )
    }

    /// 欄位裡的字換成數字。逗號當小數點（有些鍵盤的小數點是逗號）。
    private func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    /// 欄位都填好才有草稿；體重或體脂率不是數字就是 nil。去脂體重留空是 nil，填了但不是數字也擋下。
    private var draft: MeasurementDraft? {
        guard let weightKg = number(weightText), let bodyFat = number(bodyFatText) else {
            return nil
        }
        let trimmedLean = leanText.trimmingCharacters(in: .whitespaces)
        let leanMassKg = number(leanText)
        guard trimmedLean.isEmpty || leanMassKg != nil else { return nil }
        return MeasurementDraft(
            weightKg: weightKg, bodyFatPercent: bodyFat, leanMassKg: leanMassKg,
            day: DayStamp.string(from: date), source: source
        )
    }

    /// 欄位現在的樣子，拿來跟從健康 app 帶入時比。
    private var currentFill: HealthFill {
        HealthFill(
            weightText: weightText, bodyFatText: bodyFatText, leanText: leanText,
            day: DayStamp.string(from: date)
        )
    }

    /// 欄位還是健康 app 帶入的樣子，來源就記健康 app（這筆不寫回去）；改過就是手打的。
    private var source: RecordSource {
        healthFill == currentFill ? .health : .manual
    }

    /// 草稿換成規則引擎吃的純值。
    private var previewEntry: MeasurementEntry? {
        guard let draft else { return nil }
        return MeasurementEntry(
            id: "preview", date: draft.day, weightKg: draft.weightKg,
            bodyFatPercent: draft.bodyFatPercent, leanMassKg: draft.leanMassKg
        )
    }

    /// 還沒存，先用同一套判定算「結算後會是什麼」。
    private func previewJudgement(_ entry: MeasurementEntry) -> MeasurementJudgement? {
        guard let heightCm = digest.heightCm, let sex = digest.sex else { return nil }
        do {
            try Validation.check(entry)
            return try Judgement.measurementOutcome(
                new: entry, before: digest.measurements, lifts: digest.lifts, heightCm: heightCm,
                sex: sex
            )
        } catch {
            // 數字還沒填完或超出範圍時就沒有預覽；錯誤訊息在按「結算境界」時才顯示。
            return nil
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let entry = previewEntry, let judgement = previewJudgement(entry), let sex = digest.sex {
            MeasurementPreview(judgement: judgement, entry: entry, sex: sex)
        }
        Text("這一天已經有一筆量測的話，結算前會先問你要不要蓋掉。")
            .font(RencanType.footnote)
            .foregroundStyle(Color.rencan.textSecondary)
    }

    /// 打開表單時帶上次量的體重與體脂率（跟網頁版一樣），要改再改。
    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let last = digest.stele?.measurement else { return }
        weightText = Formulas.fmt(last.weightKg, digits: 1)
        bodyFatText = Formulas.fmt(last.bodyFatPercent, digits: 1)
    }

    private func submit(replacing: Bool) {
        // 存好之後表單還在往下收，這時再按到「結算境界」不能再送一次。
        guard flow.sheet != nil else { return }
        guard let draft, let sex = digest.sex else {
            errorMessage = "體重和體脂率要填數字"
            return
        }
        do {
            let judgement = try store.saveMeasurement(draft, replacing: replacing, digest: digest)
            writeBackIfEnabled(draft)
            flow.sheet = nil
            flow.page = .realm
            let style = purchases.effective(settingsRows.first?.portraitStyle ?? .original)
            if let celebration = Celebration.make(for: judgement, sex: sex, style: style) {
                // 這條路不震：慶祝畫面出來時自己震，這裡再震就是兩次。
                flow.celebration = celebration
            } else {
                flow.showToast(Celebration.toast(for: judgement, sex: sex))
                HapticsService.light()
            }
        } catch RencanError.sameDayMeasurement {
            isAskingReplace = true
        } catch {
            errorMessage = RencanError.message(for: error)
        }
    }
}

// MARK: 健康 app（組塊 E）

extension MeasurementFormView {
    /// 健康 app 最新一筆體組成比本機最新一筆還新，就把三欄與日期先帶好（PRD S2）。
    /// 設定裡把讀取關了、裝置沒有健康 app 就不讀；讀的這段時間使用者已經動過欄位就不蓋。
    /// 讀不出來時把原因寫在表單的紅字（小提示會被這張表單蓋住），手填照常能用。
    private func fillFromHealth() async {
        guard health.isAvailable, settingsRows.first?.healthReadEnabled ?? false else { return }
        load()
        let untouched = currentFill
        do {
            try await health.requestReadAuthorization()
            guard let newest = try await health.latestBodyComposition() else { return }
            if let lastDay = digest.measurements.map(\.date).max(), newest.date <= lastDay {
                return
            }
            guard untouched == currentFill else { return }
            guard let noon = DayStamp.date(from: newest.date) else {
                throw RencanError.invalidDate
            }
            weightText = Formulas.fmt(newest.weightKg, digits: 1)
            bodyFatText = Formulas.fmt(newest.bodyFatPercent, digits: 1)
            leanText = newest.leanMassKg.map { Formulas.fmt($0, digits: 1) } ?? ""
            // 日期選擇器只到現在這一刻；今天的量測用現在，不用中午（上午打開時中午還沒到）。
            date = newest.date == DayStamp.today ? Date() : noon
            healthFill = currentFill
        } catch {
            errorMessage = (error as? HealthError)?.message ?? RencanError.message(for: error)
        }
    }

    /// 回寫開著、而且這筆是手打的，就寫回健康 app（PRD S25）；健康 app 帶入的不重複寫回去。
    /// 量測這時候已經存好了：寫不回去只出一句小提示，不動存好的那一筆。
    private func writeBackIfEnabled(_ draft: MeasurementDraft) {
        guard draft.source == .manual, health.isAvailable else { return }
        guard settingsRows.first?.healthWriteEnabled ?? false else { return }
        let service = health
        let banner = flow
        Task {
            do {
                try await service.writeBack(draft)
            } catch {
                banner.showError(error)
            }
        }
    }
}

/// 「結算後」的預覽：境界、會不會突破、FFMI 與去脂體重、根基不穩的提醒。
private struct MeasurementPreview: View {
    let judgement: MeasurementJudgement
    let entry: MeasurementEntry
    let sex: Sex

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
            Text("結算後")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: RencanLayout.itemSpacing) {
                Text(judgement.standing.label)
                    .font(RencanType.sectTitle)
                    .foregroundStyle(Color.rencan.strong)
                if isBreakthrough {
                    Text("突破")
                        .font(RencanType.caption)
                        .foregroundStyle(Color.rencan.onAccent)
                        .padding(.horizontal, RencanLayout.chipHorizontalPadding)
                        .padding(.vertical, RencanLayout.chipVerticalPadding)
                        .background(Color.rencan.accent, in: Capsule())
                }
            }
            Text("FFMI \(Formulas.fmt(judgement.ffmi, digits: 2))" + leanText)
                .font(RencanType.subheadline)
            if judgement.averageCount > 1 {
                Text("境界看近 \(judgement.averageCount) 次的平均，升上去就不會掉。")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            if judgement.outcome == .unstable {
                Text("體脂超過 \(limit)%，根基不穩：這次會記下，但不算突破。")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.destructive)
            }
        }
        .modifier(HintPanel())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("measurement-preview")
    }

    private var isBreakthrough: Bool {
        switch judgement.outcome {
        case .enteredPath, .breakthrough, .majorBreakthrough:
            return true
        case .unstable, .settled:
            return false
        }
    }

    private var limit: String {
        Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
    }

    private var leanText: String {
        "・去脂 " + Formulas.fmt(Formulas.leanOf(entry), digits: 1) + " 公斤"
    }
}
