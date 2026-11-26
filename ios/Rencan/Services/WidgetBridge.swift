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
    /// 跟現在那份除了寫入時間以外都一樣就不寫、不叫小工具重畫（換造型、改道號不影響小工具）。
    /// 跨午夜不用靠這裡：小工具自己排了七天、每天午夜換一格。
    func publish(_ makeDigest: () throws -> Digest) {
        guard let defaults else { return }
        do {
            let snapshot = try WidgetSnapshot(
                digest: makeDigest(), updatedAtMs: Date().millisecondsSince1970
            )
            if let stored = Self.stored(in: defaults), Self.sameContent(stored, snapshot) {
                return
            }
            let data = try snapshot.encoded()
            defaults.set(data, forKey: WidgetSnapshot.storageKey)
        } catch {
            defaults.removeObject(forKey: WidgetSnapshot.storageKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
    }

    /// App Group 裡現在那一份。沒有或讀不懂（舊版留下的）都回 nil，照常寫一份新的蓋掉。
    private static func stored(in defaults: UserDefaults) -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: WidgetSnapshot.storageKey) else { return nil }
        do {
            return try WidgetSnapshot.decode(data)
        } catch {
            return nil
        }
    }

    /// 除了寫入時間以外每一格都一樣：把新的那份換上舊的寫入時間再整份比。
    /// WidgetSnapshot 之後多了欄位，這裡要跟著帶過去，不然新欄位會被當成一樣。
    private static func sameContent(_ stored: WidgetSnapshot, _ fresh: WidgetSnapshot) -> Bool {
        let restamped = WidgetSnapshot(
            realmName: fresh.realmName, stageName: fresh.stageName, isUnstable: fresh.isUnstable,
            nextLabel: fresh.nextLabel, kgToNext: fresh.kgToNext, weekDays: fresh.weekDays,
            trainDays: fresh.trainDays, updatedAtMs: stored.updatedAtMs
        )
        return restamped == stored
    }
}
