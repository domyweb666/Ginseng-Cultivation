import RencanCore
import SwiftUI

/// 記一筆修煉的彈出表單（照畫布 LogSheet）：功法 3×2 格子、重量、次數、組數、日期，
/// 下面即時預覽這一組算出來的等級。欄位先帶上次那門功法的數字。
/// 存檔失敗時紅字留在表單裡，內容不清掉，絕不說「已記下」（PRD S24）。
struct LiftFormView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    let digest: Digest
    let lifts: [LiftRecord]

    @State private var moveKey: MoveKey = .squat
    @State private var kg: Double = LiftFormView.defaultKg
    @State private var reps = LiftFormView.defaultReps
    @State private var sets = LiftFormView.defaultSets
    @State private var date = Date()
    @State private var errorMessage: String?
    @State private var isLoaded = false

    /// 沒有上一筆可以帶時的起始值：空槓 20 公斤、5 下、3 組（次數與組數照網頁版表單）。
    private static let defaultKg: Double = 20
    private static let defaultReps = 5
    private static let defaultSets = 3
    private static let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "記一筆修煉")
            ScrollView {
                VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                    movePicker
                    LiftFieldsView(
                        move: move, bodyweightKg: bodyweightKg, kg: $kg, reps: $reps, sets: $sets,
                        date: $date
                    )
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
            Button("記下", action: submit)
                .buttonStyle(RencanPrimaryButtonStyle())
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.vertical, RencanLayout.itemSpacing)
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .onAppear(perform: loadLast)
    }

    private var move: Move {
        Tables.moves.first { $0.key == moveKey } ?? Tables.moves[0]
    }

    private var day: String {
        DayStamp.string(from: date)
    }

    private var bodyweightKg: Double? {
        digest.bodyweight(on: day)
    }

    private var movePicker: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            Text("功法")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            LazyVGrid(columns: LiftFormView.columns, spacing: RencanLayout.itemSpacing) {
                ForEach(Tables.moves, id: \.key) { item in
                    moveButton(item)
                }
            }
        }
    }

    private func moveButton(_ item: Move) -> some View {
        let isSelected = item.key == moveKey
        return Button {
            moveKey = item.key
            fill(for: item.key)
        } label: {
            VStack(spacing: 1) {
                Text(item.artName)
                    .font(RencanType.termBody)
                Text(item.name)
                    .font(RencanType.caption)
            }
            .foregroundStyle(isSelected ? Color.rencan.onAccent : Color.rencan.textPrimary)
            .frame(maxWidth: .infinity, minHeight: RencanLayout.moveButtonHeight)
            .background(
                isSelected ? Color.rencan.accent : Color.rencan.surface,
                in: RoundedRectangle(cornerRadius: RencanLayout.fieldCornerRadius)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.artName + "・" + item.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 這一組算出來的估計 1RM、比值、等級、下一階還差幾公斤。
    private var previewResult: LiftPreview? {
        guard let sex = digest.sex, let bodyweightKg else { return nil }
        return Digest.preview(move: move, kg: kg, reps: reps, bodyweightKg: bodyweightKg, sex: sex)
    }

    @ViewBuilder
    private var preview: some View {
        if let result = previewResult {
            HStack(spacing: RencanLayout.groupSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewTitle(result))
                        .font(RencanType.callout)
                    Text(nextText(result.kgToNextLevel, nextLevelName: result.nextLevelName))
                        .font(RencanType.footnote)
                        .foregroundStyle(Color.rencan.textSecondary)
                }
                Spacer(minLength: 0)
                RencanChip(text: result.levelName)
            }
            .modifier(HintPanel())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("lift-preview")
        } else {
            Text("還沒量過體重，這一筆會記下來，等級等量過體重再算。")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .modifier(HintPanel())
        }
    }

    private func previewTitle(_ result: LiftPreview) -> String {
        let oneRepMax = Formulas.fmt(result.estimatedOneRepMaxKg, digits: 0)
        return "預估 1RM \(oneRepMax) 公斤・\(Formulas.fmt(result.ratio, digits: 2)) 倍體重"
    }

    private func nextText(_ kgToNext: Int?, nextLevelName: String?) -> String {
        guard let kgToNext, let nextLevelName else { return "已到化境" }
        return "1RM 再加 \(kgToNext) 公斤升\(nextLevelName)"
    }

    /// 打開表單時：功法停在上次記的那一門，數字帶那一門上次的。
    private func loadLast() {
        guard !isLoaded else { return }
        isLoaded = true
        if let last = lifts.last, let key = MoveKey(rawValue: last.move) {
            moveKey = key
        }
        fill(for: moveKey)
    }

    private func fill(for key: MoveKey) {
        let isBodyweightMove = Tables.moves.first { $0.key == key }?.usesBodyweight == true
        guard let last = lifts.last(where: { $0.move == key.rawValue }) else {
            kg = isBodyweightMove ? 0 : LiftFormView.defaultKg
            reps = LiftFormView.defaultReps
            sets = LiftFormView.defaultSets
            return
        }
        kg = last.kg
        reps = last.reps
        sets = last.sets
    }

    private func submit() {
        let draft = LiftDraft(move: moveKey, kg: kg, reps: reps, sets: sets, day: day)
        do {
            let judgement = try store.addLift(draft, digest: digest)
            flow.sheet = nil
            if let celebration = Celebration.make(for: judgement, move: move) {
                flow.celebration = celebration
                HapticsService.success()
            } else {
                flow.showToast(Celebration.toast(for: judgement, move: move))
                HapticsService.light()
            }
        } catch {
            errorMessage = RencanError.message(for: error)
        }
    }
}
