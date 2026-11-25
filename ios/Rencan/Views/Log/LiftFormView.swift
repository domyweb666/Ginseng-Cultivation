import RencanCore
import SwiftUI

/// 記一筆修煉的彈出表單（照畫布 LogSheet）：功法先選腿、推、拉分頁，下面兩欄四格，重量、次數、組數、日期，
/// 下面即時預覽這一組算出來的等級。欄位先帶上次那門功法的數字，功法格下面一行寫上次是哪天、多少。
/// 存檔失敗時紅字留在表單裡，內容不清掉，絕不說「已記下」（PRD S24）。
struct LiftFormView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    let digest: Digest
    let lifts: [LiftRecord]

    @State private var moveKey: MoveKey = .squat
    /// 現在看哪一組功法。只換分頁不換選中的功法，要點了格子才換。
    @State private var group: MoveGroup = .legs
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
    /// 一組四門排兩欄（2026-11-18 多米選 B 版：三排十二格太雜，改成分頁一次只看一組，
    /// 格子夠寬，「羅馬尼亞硬舉」不會被切掉）。
    /// 四格之間留 12（2026-11-21 多米真機看：原本 8 擠在一起很彆扭），跟下面重量、次數那幾張卡的間距一樣；
    /// 分頁列離四格 16（2026-11-23 跟著分頁列加高一起改）。
    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: RencanLayout.groupSpacing), count: 2
    )

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
        VStack(alignment: .leading, spacing: RencanLayout.segmentGap) {
            RencanSegmentedControl(
                title: "功法分組", options: MoveGroup.allCases, selection: $group
            )
            VStack(alignment: .leading, spacing: RencanLayout.groupSpacing) {
                LazyVGrid(columns: LiftFormView.columns, spacing: RencanLayout.groupSpacing) {
                    ForEach(Tables.moves.filter { $0.group == group }, id: \.key) { item in
                        moveButton(item)
                    }
                }
                lastLine
            }
        }
    }

    /// 選中的功法上次是哪天、多少。欄位一加減就看不到上次的數字了，所以另外寫一行（2026-11-25）。
    @ViewBuilder
    private var lastLine: some View {
        if let last = lastRecord(of: moveKey) {
            Text(LiftText.last(last, today: digest.today))
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
                .accessibilityIdentifier("lift-last")
        }
    }

    private func moveButton(_ item: Move) -> some View {
        let isSelected = item.key == moveKey
        return Button {
            moveKey = item.key
            fill(for: item.key)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.artName)
                    .font(RencanType.termBody)
                Text(item.name)
                    .font(RencanType.footnote)
                    .foregroundStyle(
                        isSelected ? Color.rencan.onAccent : Color.rencan.textSecondary
                    )
            }
            .lineLimit(1)
            .minimumScaleFactor(RencanLayout.minimumTextScale)
            .padding(.horizontal, RencanLayout.groupSpacing)
            .foregroundStyle(isSelected ? Color.rencan.onAccent : Color.rencan.textPrimary)
            .frame(
                maxWidth: .infinity, minHeight: RencanLayout.moveButtonHeight, alignment: .leading
            )
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

    /// 打開表單時：功法停在上次記的那一門、分頁停在那一門的組，數字帶那一門上次的。
    private func loadLast() {
        guard !isLoaded else { return }
        isLoaded = true
        if let last = lifts.last, let key = MoveKey(rawValue: last.move) {
            moveKey = key
        }
        group = move.group
        fill(for: moveKey)
    }

    /// 這門功法上次記的那一筆；「上次」那行跟帶入的數字都用它。
    private func lastRecord(of key: MoveKey) -> LiftRecord? {
        lifts.last { $0.move == key.rawValue }
    }

    private func fill(for key: MoveKey) {
        let isBodyweightMove = Tables.moves.first { $0.key == key }?.usesBodyweight == true
        guard let last = lastRecord(of: key) else {
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
        // 存好之後表單還在往下收，這時再按到「記下」不能再存一筆。
        guard flow.sheet != nil else { return }
        let draft = LiftDraft(move: moveKey, kg: kg, reps: reps, sets: sets, day: day)
        do {
            let judgement = try store.addLift(draft, digest: digest)
            flow.sheet = nil
            if let celebration = Celebration.make(for: judgement, move: move) {
                // 這條路不震：慶祝畫面出來時自己震，這裡再震就是兩次。
                flow.celebration = celebration
            } else {
                flow.showToast(Celebration.toast(for: judgement, move: move))
                HapticsService.light()
            }
        } catch {
            errorMessage = RencanError.message(for: error)
        }
    }
}
