import AppIntents
import RencanCore

/// Siri／捷徑「問境界」（片 H2，PRD S18）：不開 app，回一句現在的境界、FFMI、距下一期還差多少。
/// 數字從 Digest 拿，跟境界碑同一份算法；句子由 RencanCore 的 SiriReply 組。
struct RealmStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "問境界"
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = reply()
        return .result(dialog: "\(text)")
    }

    /// 資料庫打不開或資料算不出來時回那句原因，不編一個境界給他。
    @MainActor
    private func reply() -> String {
        do {
            let digest = try AppServices.shared().digest()
            return SiriReply.realmStatus(digest)
        } catch {
            return SiriReply.realmFailure(error)
        }
    }
}
