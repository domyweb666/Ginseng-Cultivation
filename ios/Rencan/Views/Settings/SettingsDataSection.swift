import RencanCore
import SwiftUI
import UniformTypeIdentifiers

// 這個檔假設 StoreService 有下面兩個函式（組塊 F，由主會話貼進 StoreService.swift）：
//   func importRecords(_ plan: WebImportPlan) throws   （經 ImportExportService.commit 呼叫）
//   func deleteAllRecords() throws

/// 這一區自己的版面常數（數值照畫布 Settings，跟 SettingsView 裡同名的一樣）。
private enum Metrics {
    /// 「資料」那一區與「刪除全部紀錄」那張卡之間
    static let sectionGap: CGFloat = 14
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距
    static let cardInset: CGFloat = 16
}

/// 設定頁的「資料」區（照畫布 Settings 最下面兩張卡）：匯出紀錄、匯入紀錄、刪除全部紀錄。
/// 外層的 SettingsView 已經有 ScrollView 與左右邊距，這裡不再包。
/// 匯出（PRD S23）：寫暫存檔，彈出一張小表單講「含身體數據」，再交給系統的分享表單。
/// 匯入（PRD S22）：選檔、整份檢查、先講會新增幾筆，使用者按了「匯入」才一次寫入。
/// 刪除全部紀錄（PRD S28）：不可逆，一定先問一次；身高與性別留著，健康 app 的資料不動。
struct SettingsDataSection: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    let digest: Digest

    @State private var exportFile: SettingsDataExportFile?
    @State private var isPickingFile = false
    @State private var importPlan: WebImportPlan?
    @State private var rejection: String?
    @State private var isAskingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            recordsSection
            deleteCard
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "資料")
                .padding(.horizontal, Metrics.titleInset)
            recordsCard
        }
        .alert("這個檔案不能匯入", isPresented: isShowingRejection, presenting: rejection) { _ in
            Button("知道了", role: .cancel) {}
        } message: { reason in
            Text(reason)
        }
    }

    private var recordsCard: some View {
        VStack(spacing: 0) {
            SettingsDataRow(title: "匯出紀錄", identifier: "settings-export") {
                startExport()
            }
            .sheet(item: $exportFile) { file in
                SettingsDataExportSheet(file: file)
            }
            RowDivider()
            SettingsDataRow(title: "匯入紀錄", identifier: "settings-import") {
                isPickingFile = true
            }
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.json]) { result in
                pickedFile(result)
            }
        }
        .padding(.horizontal, Metrics.cardInset)
        .background(
            Color.rencan.surface,
            in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
        .alert("匯入紀錄", isPresented: isShowingPlan, presenting: importPlan) { plan in
            importActions(plan)
        } message: { plan in
            Text(SettingsDataText.preview(plan))
        }
    }

    /// 預覽視窗的按鈕。沒有東西要新增時只有「知道了」，不給一顆按了沒事發生的「匯入」。
    @ViewBuilder
    private func importActions(_ plan: WebImportPlan) -> some View {
        if plan.hasChanges {
            Button("匯入") {
                commit(plan)
            }
            Button("取消", role: .cancel) {}
        } else {
            Button("知道了", role: .cancel) {}
        }
    }

    /// 紅字的那張卡。按了先問，確認的那顆按鈕字不一樣（全部刪除），不會連點兩下同一個位置就刪掉。
    private var deleteCard: some View {
        Button(role: .destructive) {
            isAskingDelete = true
        } label: {
            Text("刪除全部紀錄")
                .font(RencanType.body)
                .foregroundStyle(Color.rencan.destructive)
                .frame(
                    maxWidth: .infinity, minHeight: RencanLayout.rowHeight, alignment: .leading
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.cardInset)
        .background(
            Color.rencan.surface,
            in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
        .accessibilityIdentifier("settings-delete-all")
        .confirmationDialog(
            "要刪除全部紀錄嗎？", isPresented: $isAskingDelete, titleVisibility: .visible
        ) {
            Button("全部刪除", role: .destructive) {
                deleteAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(
                SettingsDataText.deleteWarning(
                    measurements: digest.measurements.count, lifts: digest.lifts.count
                )
            )
        }
    }

    /// 有預覽要給使用者看的時候是 true；視窗關掉時把預覽清掉。
    private var isShowingPlan: Binding<Bool> {
        Binding(
            get: { importPlan != nil },
            set: { isShown in
                if !isShown {
                    importPlan = nil
                }
            }
        )
    }

    private var isShowingRejection: Binding<Bool> {
        Binding(
            get: { rejection != nil },
            set: { isShown in
                if !isShown {
                    rejection = nil
                }
            }
        )
    }

    // MARK: 動作

    private func startExport() {
        do {
            let url = try ImportExportService.writeExport(of: digest)
            exportFile = SettingsDataExportFile(
                url: url, measurementCount: digest.measurements.count,
                liftCount: digest.lifts.count
            )
        } catch {
            flow.showError(error)
        }
    }

    /// 選好檔案以後：讀檔、整份檢查、算出預覽。這一步還沒寫任何東西。
    /// 壞檔在這裡擋下，用一個要按「知道了」才關的視窗說是哪一筆壞（小提示兩三秒就消失，來不及看）。
    private func pickedFile(_ result: Result<URL, Error>) {
        do {
            importPlan = try ImportExportService.readImport(from: result.get(), digest: digest)
        } catch let cancel as CocoaError where cancel.code == .userCancelled {
            // 使用者自己按了取消，不是錯誤，什麼都不用說。
            return
        } catch {
            rejection = ImportExportService.rejectionMessage(for: error)
        }
    }

    /// 使用者在預覽按了「匯入」。匯入的量測不放慶祝、不震動，只有一句小提示。
    private func commit(_ plan: WebImportPlan) {
        do {
            try ImportExportService.commit(plan, to: store)
            flow.showToast(SettingsDataText.imported(plan))
        } catch {
            flow.showError(error)
        }
    }

    private func deleteAll() {
        do {
            try store.deleteAllRecords()
            // 剛刪掉、還能復原的那筆修煉也不留，不然按「復原」會在全部刪除之後又冒出一筆。
            flow.undo = nil
            // 小工具快照（組塊 G1）做好之後，在這裡把快照清掉並叫小工具刷新。
            flow.showToast(SettingsDataText.deleted)
        } catch {
            flow.showError(error)
        }
    }
}

/// 資料卡裡的一列：左邊字、右邊小箭頭，整列都能點。
private struct SettingsDataRow: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RencanLayout.groupSpacing) {
                Text(title)
                    .font(RencanType.body)
                    .foregroundStyle(Color.rencan.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(RencanType.footnote.weight(.semibold))
                    .foregroundStyle(Color.rencan.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: RencanLayout.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// 資料區畫面上的字。筆數先組成字串再交給 Text，數字才不會被系統加上千分位。
enum SettingsDataText {
    /// 匯出前的提醒（安全標準類別 1）。
    static let exportReminder = "這個檔案含你的身體數據，自己保管。"
    static let deleted = "已刪除全部紀錄"

    static func counts(measurements: Int, lifts: Int) -> String {
        "量測 \(measurements) 筆、修煉 \(lifts) 筆"
    }

    /// 匯入預覽：檔案裡有幾筆、幾筆本機已經有、會新增幾筆、身高會不會改。
    static func preview(_ plan: WebImportPlan) -> String {
        let total = counts(measurements: plan.measurementTotal, lifts: plan.liftTotal)
        var lines: [String] = []
        lines.append("檔案裡有" + total + "。")
        if plan.alreadyHaveCount > 0 {
            lines.append("其中 \(plan.alreadyHaveCount) 筆本機已經有，不會重複匯入。")
        }
        if plan.sameDayExtraCount > 0 {
            let extra = plan.sameDayExtraCount
            lines.append("同一天有好幾筆量測的只留最後量的那筆，\(extra) 筆不匯入。")
        }
        if plan.addCount > 0 {
            let added = counts(measurements: plan.measurements.count, lifts: plan.lifts.count)
            lines.append("會新增" + added + "。")
        } else {
            lines.append("沒有要新增的紀錄。")
        }
        if let heightCm = plan.heightCm {
            lines.append("身高會照檔案改成 " + height(heightCm) + "。")
        }
        return lines.joined(separator: "\n")
    }

    /// 匯入成功的小提示。只改了身高、沒有新增紀錄時說身高。
    static func imported(_ plan: WebImportPlan) -> String {
        guard plan.addCount > 0 else { return "身高已照檔案更新" }
        return "已匯入：" + counts(measurements: plan.measurements.count, lifts: plan.lifts.count)
    }

    /// 刪除全部紀錄前的那段說明：刪什麼、救不救得回來、什麼會留著、健康 app 不受影響。
    static func deleteWarning(measurements: Int, lifts: Int) -> String {
        let total = counts(measurements: measurements, lifts: lifts)
        let removed = "會刪掉這支手機上全部的紀錄（" + total + "），刪了救不回來。"
        let untouched = "身高和性別會留著。健康 app 裡的資料不受影響。想留一份就先匯出。"
        return removed + untouched
    }

    /// 身高的寫法：整數就不帶小數（174 公分），不是整數才帶一位。
    private static func height(_ heightCm: Double) -> String {
        let digits = heightCm == heightCm.rounded() ? 0 : 1
        return Formulas.fmt(heightCm, digits: digits) + " 公分"
    }
}
