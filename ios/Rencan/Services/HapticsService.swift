import UIKit

/// 觸覺回饋：慶祝時震一下（success），記下一筆時輕點一下（light）。
/// 模擬器沒有震動馬達，這兩個呼叫在模擬器上不會有反應，手感只能在真機驗。
@MainActor
enum HapticsService {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
