import RencanCore
import SwiftUI

/// 分析頁的境界段（照畫布 AnalysisRealm）：宗門卡、FFMI 走勢、突破紀錄、天梯、境界怎麼算。
/// 還沒量過（或還沒填身高、選性別）時整段只有一句話。
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

    /// 一張卡裡只有那句話，置中。
    private var emptyState: some View {
        Text("還沒量過體組成。回境界頁輸入一次體重和體脂率，這裡就會有走勢、突破紀錄和天梯。")
            .font(RencanType.subheadline)
            .foregroundStyle(Color.rencan.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .rencanCard()
    }
}
