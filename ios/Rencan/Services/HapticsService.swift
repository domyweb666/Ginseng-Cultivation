import UIKit
import VeggieKit

/// 觸覺回饋：慶祝時震一下（success），記下一筆時輕點一下（light）。
/// 設定頁「一般」區的「觸覺回饋」關掉時兩個都不震（蔬菜家族共用規格，2026-11-19 加）。
/// 模擬器沒有震動馬達，這兩個呼叫在模擬器上不會有反應，手感只能在真機驗。
@MainActor
enum HapticsService {
    static func success() {
        guard VeggieHaptics.isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func light() {
        guard VeggieHaptics.isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
