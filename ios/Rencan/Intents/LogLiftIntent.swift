import AppIntents
import RencanCore

/// Siri／捷徑「記修煉」（片 H1，PRD S17）：不開 app，存今天的一筆，回一句話。
/// 存檔走 StoreService.addLift，跟記一筆表單同一條路、同一套驗證；Siri 給的值不另外放行
/// （安全標準）。回覆的句子由 RencanCore 的 SiriReply 組，這裡只取資料與存檔。
struct LogLiftIntent: AppIntent {
    static let title: LocalizedStringResource = "記修煉"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "功法", requestValueDialog: "哪一門功法？")
    var move: MoveChoice

    /// 槓上的重量；引體向上是額外加重，徒手說 0。
    @Parameter(title: "重量（公斤）", requestValueDialog: "幾公斤？")
    var kg: Double

    @Parameter(title: "次數", requestValueDialog: "做了幾下？")
    var reps: Int

    /// 沒講就是 1 組（PRD S17）。
    @Parameter(title: "組數", default: 1)
    var sets: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = reply()
        return .result(dialog: "\(text)")
    }

    /// 存檔失敗、驗證沒過、還沒填身高性別，都回那句原因，絕不說已記下（PRD S24）。
    @MainActor
    private func reply() -> String {
        guard let chosen = move.tableMove else {
            return SiriReply.logFailure(RencanError.unknownMove)
        }
        do {
            let services = try AppServices.shared()
            let digest = try services.digest()
            let draft = LiftDraft(
                move: chosen.key, kg: kg, reps: reps, sets: sets, day: digest.today
            )
            let judgement = try services.store.addLift(draft, digest: digest)
            return SiriReply.logged(judgement, move: chosen, kg: kg, reps: reps, sets: sets)
        } catch {
            return SiriReply.logFailure(error)
        }
    }
}
