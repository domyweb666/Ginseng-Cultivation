import RencanCore
import SwiftData
import SwiftUI

// 這個檔假設現有的檔會這樣配合（由主會話接）：
//   StoreServiceBulk.swift `func setHealthRead(enabled: Bool) throws`
//                          （存 UserSettings.healthReadEnabled，寫法照 setHealthWrite）
//   SettingsView.swift     「身體」區後面排一行 `SettingsHealthSection(digest: digest)`
// 已經有、這裡直接用的：HealthKitService（RencanApp 注入）、HealthImport.merge（RencanCore）、
// StoreService.importHealthMeasurements／setHealthWrite、AppFlow.showError、MascotView、
// SectionTitle、RowDivider。

/// 這一區自己的版面常數（數值照畫布 Settings，跟 SettingsView 裡同名的一樣）。
private enum Metrics {
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 卡片的左右內距，卡片下面那幾行說明也縮這麼多
    static let cardInset: CGFloat = 16
    /// 重建時那一列右邊的小人蔘。比列高（52）小一點，這一列才不會跟著變高
    static let mascotHeight: CGFloat = 44
}

/// 設定頁的「健康 app」區（片 E2、E3、E4，照畫布 Settings）：
/// 讀取的開關、回寫的開關、從健康 app 重建量測紀錄。
/// 自己不包 ScrollView、不加左右邊距，由 SettingsView 排進去。
/// 讀取的開關是 app 自己的（UserSettings.healthReadEnabled）；系統那邊允不允許讀在手機的設定裡管，
/// app 查不到。回寫預設關，打開那一刻才問寫入授權，沒拿到就彈回去（PRD S25）。
/// 裝置沒有健康 app（UI 測試模式也算）時整區只有一句說明，不放按不動的開關。
struct SettingsHealthSection: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Environment(HealthKitService.self) private var health
    @Query private var settingsRows: [UserSettings]
    let digest: Digest
    /// 回寫的開關剛被打開、寫入授權還在問。這段時間開關先顯示成開的。
    @State private var isTurningWriteOn = false
    /// 這次打開回寫被擋下來（健康 app 沒有允許寫入）。
    @State private var wasWriteRefused = false
    @State private var isAskingRebuild = false
    @State private var isRebuilding = false

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            SectionTitle(text: "健康 app")
                .padding(.horizontal, Metrics.titleInset)
            if health.isAvailable {
                card
                note(SettingsHealthText.scope, identifier: "health-scope")
                note(SettingsHealthText.systemPermission, identifier: "health-system-hint")
            } else {
                note(SettingsHealthText.unavailable, identifier: "health-unavailable")
            }
            if showsWriteDenied {
                Text(SettingsHealthText.writeDenied)
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.destructive)
                    .padding(.horizontal, Metrics.cardInset)
                    .accessibilityIdentifier("health-write-denied")
            }
        }
        .confirmationDialog(
            "要從健康 app 重建量測紀錄嗎？", isPresented: $isAskingRebuild,
            titleVisibility: .visible
        ) {
            Button("重建") {
                Task { await rebuild() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(SettingsHealthText.rebuildExplanation)
        }
    }

    private var isReadEnabled: Bool {
        health.isAvailable && (settingsRows.first?.healthReadEnabled ?? false)
    }

    private var isWriteEnabled: Bool {
        health.isAvailable && (settingsRows.first?.healthWriteEnabled ?? false)
    }

    /// 健康 app 沒允許寫入的時候才出現：剛剛打開被擋下來，或回寫開著但寫入授權後來被關掉。
    private var showsWriteDenied: Bool {
        guard health.isAvailable, !isTurningWriteOn else { return false }
        return wasWriteRefused || (isWriteEnabled && !health.isWriteAuthorized)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: readBinding) {
                Text("讀取體重與體脂")
                    .font(RencanType.body)
            }
            .tint(Color.rencan.accent)
            .frame(minHeight: RencanLayout.rowHeight)
            .accessibilityIdentifier("health-read-toggle")
            RowDivider()
            Toggle(isOn: writeBinding) {
                Text("量測寫回健康 app")
                    .font(RencanType.body)
            }
            .tint(Color.rencan.accent)
            .frame(minHeight: RencanLayout.rowHeight)
            .accessibilityIdentifier("health-write-toggle")
            RowDivider()
            rebuildRow
        }
        .padding(.horizontal, Metrics.cardInset)
        .background(
            Color.rencan.surface,
            in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    /// 從健康 app 重建量測紀錄（片 E4）。按了先講會做什麼，確認才讀。讀取關著時不能按。
    /// 讀的這段時間右邊是思考的小人蔘（片 K4），讀完換回箭頭。
    private var rebuildRow: some View {
        let isUsable = isReadEnabled && !isRebuilding
        return Button {
            isAskingRebuild = true
        } label: {
            HStack(spacing: RencanLayout.groupSpacing) {
                Text(isRebuilding ? SettingsHealthText.rebuilding : SettingsHealthText.rebuild)
                    .font(RencanType.body)
                    .foregroundStyle(
                        isUsable ? Color.rencan.textPrimary : Color.rencan.textSecondary
                    )
                Spacer()
                if isRebuilding {
                    MascotView(action: .think, height: Metrics.mascotHeight)
                } else {
                    Image(systemName: "chevron.right")
                        .font(RencanType.footnote.weight(.semibold))
                        .foregroundStyle(Color.rencan.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: RencanLayout.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isUsable)
        .accessibilityIdentifier("health-rebuild")
    }

    /// 卡片下面的一行說明。
    private func note(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(RencanType.footnote)
            .foregroundStyle(Color.rencan.textSecondary)
            .padding(.horizontal, Metrics.cardInset)
            .accessibilityIdentifier(identifier)
    }

    /// 讀取的開關只存 app 自己的設定。打開之後 RootTabView 會馬上去健康 app 看一次。
    private var readBinding: Binding<Bool> {
        Binding(
            get: { isReadEnabled },
            set: { isOn in
                do {
                    try store.setHealthRead(enabled: isOn)
                } catch {
                    flow.showError(error)
                }
            }
        )
    }

    /// 開關顯示的值來自存好的設定；打開的過程中先顯示成開的。
    /// 沒拿到寫入授權時設定沒有動，isTurningWriteOn 一變回 false 開關就自己彈回去。
    private var writeBinding: Binding<Bool> {
        Binding(
            get: { isWriteEnabled || isTurningWriteOn },
            set: { isOn in
                guard !isTurningWriteOn else { return }
                if isOn {
                    Task { await turnWriteOn() }
                } else {
                    turnWriteOff()
                }
            }
        )
    }

    /// 打開回寫：這一刻才問寫入授權（三種都要允許），拿到才存設定。
    private func turnWriteOn() async {
        isTurningWriteOn = true
        defer { isTurningWriteOn = false }
        do {
            guard try await health.requestWriteAuthorization() else {
                wasWriteRefused = true
                return
            }
            try store.setHealthWrite(enabled: true)
            wasWriteRefused = false
        } catch {
            flow.showError(error)
        }
    }

    private func turnWriteOff() {
        do {
            try store.setHealthWrite(enabled: false)
            wasWriteRefused = false
        } catch {
            flow.showError(error)
        }
    }

    /// 把健康 app 裡過去全部的樣本讀一次，整理成一天一筆，本機還沒有的那幾天才新增。
    /// 帶進來的量測不放慶祝，做完出一句小提示講新增了幾筆。
    private func rebuild() async {
        isRebuilding = true
        defer { isRebuilding = false }
        do {
            try await health.requestReadAuthorization()
            let samples = try await health.bodySamples(since: nil)
            let merged = try HealthImport.merge(samples: samples, existing: digest.measurements)
            let added = try store.importHealthMeasurements(merged.additions)
            let found = merged.candidates.count
            flow.showToast(SettingsHealthText.rebuilt(added: added, found: found))
        } catch {
            flow.showError(error)
        }
    }
}

/// 健康 app 區畫面上的字。筆數先組成字串再交給小提示，數字才不會被系統加上千分位。
enum SettingsHealthText {
    /// 前一句是畫布 Settings 上那一行，後一句講回寫只寫什麼。
    static let scope = "只讀體重、體脂率、去脂體重、身高、生理性別五項。寫回只寫你手打的量測。"
    static let unavailable = "這台裝置沒有健康 app，體組成請用手動輸入。"
    static let rebuild = "從健康 app 重建量測紀錄"
    static let rebuilding = "正在讀健康 app"
    /// 系統設定裡健康授權的位置。iOS 改版可能換名字，上架前要在真機上對一次。
    private static let systemPath = "手機的「設定」→「隱私權與安全性」→「健康」→「人蔘修煉」"

    static var systemPermission: String {
        "開關開著還是讀不到的話，到" + systemPath + "把讀取打開。"
    }

    static var writeDenied: String {
        let reason = "健康 app 沒有允許寫入體重、體脂率、去脂體重，所以回寫沒打開。"
        let fix = "到" + systemPath + "把這三項的寫入打開，再回來開一次。"
        return reason + fix
    }

    /// 按下重建之前那段說明：會讀什麼、怎麼合併、什麼不會動。
    static var rebuildExplanation: String {
        let reads = "會把健康 app 裡過去全部的體重、體脂率、去脂體重讀一次，同一天的合成一筆量測。"
        let keeps = "這支手機上已經有量測的那一天不會動。帶進來的量測不放慶祝。"
        return reads + keeps
    }

    /// 重建做完的小提示。found 是健康 app 裡湊得成一筆的天數。
    static func rebuilt(added: Int, found: Int) -> String {
        if added > 0 { return "新增 \(added) 筆量測" }
        if found == 0 { return "新增 0 筆：健康 app 裡沒有同一天的體重和體脂率" }
        return "新增 0 筆：健康 app 有的那幾天這裡都有了"
    }
}
