import RencanCore
import SwiftUI

/// 編輯一筆修煉：改重量、次數、組數、日期，存回去等級跟著重算；也可以在這裡刪除（PRD S15）。
/// 功法不能改：記錯功法就刪掉重記，免得一筆紀錄悄悄換了身分。
struct EditRecordView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    let record: LiftRecord
    let digest: Digest

    @State private var kg: Double = 0
    @State private var reps = 1
    @State private var sets = 1
    @State private var date = Date()
    @State private var errorMessage: String?
    @State private var isLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "編輯這一筆")
            ScrollView {
                VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                    HStack(spacing: 0) {
                        Text(move.artName)
                            .font(RencanType.term)
                            .foregroundStyle(Color.rencan.strong)
                        Text("・" + move.name)
                            .font(RencanType.body)
                    }
                    LiftFieldsView(
                        move: move, bodyweightKg: record.bodyweightKg, kg: $kg, reps: $reps,
                        sets: $sets, date: $date
                    )
                    if let errorMessage {
                        Text(errorMessage)
                            .font(RencanType.subheadline)
                            .foregroundStyle(Color.rencan.destructive)
                    }
                    Button("刪除這一筆", role: .destructive, action: delete)
                        .font(RencanType.body)
                        .foregroundStyle(Color.rencan.destructive)
                        .frame(maxWidth: .infinity, minHeight: RencanLayout.rowHeight)
                        .background(
                            Color.rencan.surface,
                            in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
                        )
                }
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.bottom, RencanLayout.sectionSpacing)
            }
            Button("存回去", action: save)
                .buttonStyle(RencanPrimaryButtonStyle())
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.vertical, RencanLayout.itemSpacing)
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
        .onAppear(perform: load)
    }

    private var move: Move {
        LiftText.move(of: record) ?? Tables.moves[0]
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        kg = record.kg
        reps = record.reps
        sets = record.sets
        date = DayStamp.date(from: record.day) ?? Date()
    }

    private func save() {
        let draft = LiftDraft(
            move: move.key, kg: kg, reps: reps, sets: sets, day: DayStamp.string(from: date)
        )
        do {
            try store.update(record, with: draft)
            flow.sheet = nil
            flow.showToast("已更新\(move.artName)")
        } catch {
            errorMessage = RencanError.message(for: error)
        }
    }

    private func delete() {
        do {
            let snapshot = try store.delete(record)
            flow.sheet = nil
            flow.undo = snapshot
        } catch {
            errorMessage = RencanError.message(for: error)
        }
    }
}
