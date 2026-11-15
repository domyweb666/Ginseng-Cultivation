import RencanCore
import SwiftUI

/// 境界碑：立繪、境界與期別、FFMI、根基、距下一期還差多少肌肉、三期進度。
/// 體脂超過門檻時照樣顯示境界，但標「根基不穩」、進度條灰掉（PRD S7）。
struct SteleView: View {
    let stele: SteleDigest
    let sex: Sex

    var body: some View {
        VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
            HStack(alignment: .center, spacing: RencanLayout.sectionSpacing) {
                portrait
                summary
            }
            progress
        }
        .rencanCard(cornerRadius: RencanLayout.heroCornerRadius)
        .accessibilityIdentifier("stele")
    }

    private var standing: RealmStanding { stele.standing }

    private var portrait: some View {
        Image(RencanPortrait.name(realmIndex: standing.realmIndex, sex: sex))
            .resizable()
            .scaledToFill()
            .frame(
                width: RencanLayout.portraitSize.width, height: RencanLayout.portraitSize.height
            )
            .background(Color.rencan.tint)
            .clipShape(RoundedRectangle(cornerRadius: RencanLayout.portraitCornerRadius))
            .accessibilityLabel("\(standing.realm.name)期人蔘立繪")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
            Text("目前境界")
                .font(RencanType.footnote)
                .foregroundStyle(Color.rencan.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: RencanLayout.chipVerticalPadding) {
                Text(standing.realm.name)
                    .font(RencanType.realmName)
                Text(Tables.stages[standing.stageIndex])
                    .font(RencanType.realmStage)
            }
            .foregroundStyle(Color.rencan.strong)
            .accessibilityElement(children: .combine)
            Text("FFMI \(Formulas.fmt(stele.ffmi, digits: 2))・\(standing.realm.summary)")
                .font(RencanType.subheadline)
                .foregroundStyle(Color.rencan.textSecondary)
            RencanChip(text: gateText, isWarning: !stele.isStable)
        }
    }

    private var bodyFat: String {
        Formulas.fmt(stele.measurement.bodyFatPercent, digits: 1)
    }

    private var limit: String {
        Formulas.fmt(sex.bodyFatStableThresholdPercent, digits: 0)
    }

    /// 根基那一行（網頁版 index.html L357–361 的四種說法）。
    private var gateText: String {
        switch stele.gate {
        case .stable:
            return "根基穩固・體脂 \(bodyFat)%"
        case .wavering:
            return "根基浮動・體脂 \(bodyFat)%"
        case .low:
            return "體脂 \(bodyFat)%，偏低"
        case .unstable:
            return "根基不穩・體脂 \(bodyFat)%"
        }
    }

    @ViewBuilder
    private var progress: some View {
        VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
            if case .unstable(let overBy) = stele.gate {
                Text("降到 \(limit)% 以下境界才生效，還差 \(Formulas.fmt(overBy, digits: 1))%")
                    .font(RencanType.subheadline)
                    .foregroundStyle(Color.rencan.destructive)
            } else if let gap = stele.gap {
                HStack(alignment: .firstTextBaseline) {
                    Text("下一期 \(gap.nextLabel)")
                        .font(RencanType.subheadline)
                        .foregroundStyle(Color.rencan.textSecondary)
                    Spacer()
                    Text("還差 \(Formulas.fmt(gap.leanNeededKg, digits: 1)) 公斤肌肉")
                        .font(RencanType.headline)
                }
            } else {
                Text("已達渡劫後期")
                    .font(RencanType.headline)
            }
            stageBars
        }
    }

    /// 初期、中期、後期三格：過了的填滿，現在這一期照比例，還沒到的空著。
    private var stageBars: some View {
        HStack(spacing: RencanLayout.barGap) {
            ForEach(Tables.stages.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
                    ProgressBar(percent: percent(ofStage: index), isMuted: !stele.isStable)
                    Text(Tables.stages[index])
                        .font(RencanType.caption)
                        .foregroundStyle(
                            index == standing.stageIndex
                                ? Color.rencan.textPrimary : Color.rencan.textSecondary
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressLabel)
    }

    private func percent(ofStage index: Int) -> Double {
        if index < standing.stageIndex { return 100 }
        return index == standing.stageIndex ? stele.stagePercent : 0
    }

    private var progressLabel: String {
        let stage = Tables.stages[standing.stageIndex]
        let walked = Formulas.fmt(stele.stagePercent, digits: 0)
        return "\(standing.realm.name)\(stage)走了百分之 \(walked)"
    }
}
