import RencanCore
import SwiftUI

/// 這一段自己的版面常數。
private enum Metrics {
    /// 空狀態的小人蔘（片 K3）高度：看得久的位置用中間那一級
    static let mascotHeight: CGFloat = 96
}

/// 分析頁的境界段（照畫布 AnalysisRealm）：宗門卡、FFMI 走勢、突破紀錄、天梯、境界怎麼算。
/// 還沒量過（或還沒填身高、選性別）時整段只有聳肩的小人蔘加一句話。
/// 數字都從 Digest 拿，這裡只排版。
struct AnalysisRealmSection: View {
    let digest: Digest

    var body: some View {
        if let stele = digest.stele, let sex = digest.sex {
            VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                SectCard(sect: digest.sect)
                FFMIChartCard(
                    points: digest.ffmiHistory, standing: stele.standing, sex: sex,
                    today: digest.today
                )
                BreakthroughList(breakthroughs: digest.breakthroughs, today: digest.today)
                RealmLadder(standing: stele.standing, sex: sex)
                RealmRulesCard(sex: sex)
            }
        } else {
            emptyState
        }
    }

    /// 小人蔘聳肩在上、那句話在下，都置中。小人蔘高度固定，字放大時只有那句話往下長。
    private var emptyState: some View {
        VStack(spacing: RencanLayout.groupSpacing) {
            MascotView(action: .shrug, height: Metrics.mascotHeight)
            Text("還沒量過體組成。回境界頁輸入一次體重和體脂率，這裡就會有走勢、突破紀錄和天梯。")
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .rencanCard()
    }
}
