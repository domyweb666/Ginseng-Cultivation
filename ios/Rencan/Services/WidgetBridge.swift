import Foundation
import RencanCore
import WidgetKit

/// 把小工具要看的那一小份寫進 App Group，再叫小工具重畫（藍圖 a10、a18；片 G1）。
/// 只有 StoreService 存檔成功之後、還有 app 剛打開時會叫這裡，畫面不直接碰。
/// 快照的內容由 RencanCore 的 WidgetSnapshot 從 Digest 抄出來，這裡不算任何數字。
struct WidgetBridge {
    /// App Group 的那一格。拿不到（沒有 App Group 權限）時是 nil，這時什麼都不寫。
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroupID)) {
        self.defaults = defaults
    }

    /// 寫一份新的快照。digest 算不出來或寫不進去都不算存檔失敗（紀錄已經在資料庫裡了），
    /// 這時把舊快照拿掉，小工具改顯示「打開 app 更新」，不留一份過期的境界在主畫面上。
    func publish(_ makeDigest: () throws -> Digest) {
        guard let defaults else { return }
        do {
            let snapshot = try WidgetSnapshot(
                digest: makeDigest(), updatedAtMs: Date().millisecondsSince1970
            )
            let data = try snapshot.encoded()
            defaults.set(data, forKey: WidgetSnapshot.storageKey)
        } catch {
            defaults.removeObject(forKey: WidgetSnapshot.storageKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
    }
}
