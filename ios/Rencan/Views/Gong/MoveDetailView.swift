import Charts
import RencanCore
import SwiftData
import SwiftUI

/// 這一頁自己的版面常數。
private enum Metrics {
    /// 走勢圖的高度
    static let chartHeight: CGFloat = 180
    /// 至少要幾筆才畫得出走勢
    static let minimumTrendPoints = 2
    /// 區塊標題比卡片邊再縮進一點
    static let titleInset: CGFloat = 4
    /// 紀錄卡的左右內距、一列的最小高度與上下內距（跟「最近修煉」同一組數字）
    static let cardInset: CGFloat = 16
    static let rowMinHeight: CGFloat = 60
    static let rowVerticalPadding: CGFloat = 10
}

/// 單一功法頁（點功法卡彈出來）：這門功法的估計 1RM 走勢圖，下面是它的全部紀錄，新的在上。
/// 走勢圖的點跟功法卡上那條小走勢線是同一份（MoveCard.history），照記錄的先後由左到右排，
/// 橫軸是第幾筆，不是日期。
struct MoveDetailView: View {
    @Environment(AppFlow.self) private var flow
    /// 這門功法的全部紀錄，新的在上。資料庫只撈這一門、排好，不在畫面裡篩全部再排
    /// （2026-11-26 性能審查）。
    @Query private var ownLifts: [LiftRecord]
    let key: MoveKey
    let digest: Digest

    init(key: MoveKey, digest: Digest) {
        self.key = key
        self.digest = digest
        let move = key.rawValue
        let isThisMove = #Predicate<LiftRecord> { $0.move == move }
        _ownLifts = Query(RecentLiftsList.newestFirstQuery(matching: isThisMove))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: title, dismissLabel: "關閉")
            ScrollView {
                VStack(alignment: .leading, spacing: RencanLayout.sectionSpacing) {
                    if let card {
                        trendCard(card)
                    }
                    records
                }
                .padding(.horizontal, RencanLayout.screenMargin)
                .padding(.bottom, RencanLayout.sectionSpacing)
            }
        }
        .background(Color.rencan.canvas.ignoresSafeArea())
    }

    /// 每門功法 Digest 都會給一張卡，這裡照代號找出這一門。
    private var card: MoveCard? {
        digest.moveCards.first { $0.move.key == key }
    }

    private var title: String {
        guard let move = card?.move else { return "功法" }
        return move.artName + "・" + move.name
    }

    /// 上半張：最佳 1RM、幾倍體重、離下一階多遠、等級，下面是走勢圖。
    private func trendCard(_ card: MoveCard) -> some View {
        VStack(alignment: .leading, spacing: RencanLayout.groupSpacing) {
            HStack(alignment: .top, spacing: RencanLayout.groupSpacing) {
                VStack(alignment: .leading, spacing: RencanLayout.chipVerticalPadding) {
                    Text(card.oneRepMaxText ?? card.statusText)
                        .font(RencanType.title3)
                    if let ratioText = card.ratioText {
                        Text(ratioText + "・" + card.statusText)
                            .font(RencanType.subheadline)
                            .foregroundStyle(Color.rencan.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                RencanChip(text: card.levelName)
            }
            .accessibilityElement(children: .combine)
            if card.history.count >= Metrics.minimumTrendPoints {
                chart(card)
                Text(card.trendText + "。由左到右照記錄的先後。")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            } else if card.best != nil {
                Text("再記一筆，就畫得出走勢。")
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
        }
        .rencanCard()
        .accessibilityIdentifier("move-trend")
    }

    /// 估計 1RM 走勢。縱軸不從 0 開始，幾公斤的進步才看得出來。
    private func chart(_ card: MoveCard) -> some View {
        Chart(Array(card.history.enumerated()), id: \.offset) { item in
            LineMark(
                x: .value("第幾筆", item.offset + 1), y: .value("估計 1RM（公斤）", item.element)
            )
            .foregroundStyle(Color.rencan.accent)
            PointMark(
                x: .value("第幾筆", item.offset + 1), y: .value("估計 1RM（公斤）", item.element)
            )
            .foregroundStyle(Color.rencan.accent)
        }
        .chartXAxis(.hidden)
        .chartXScale(domain: 1...card.history.count)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: Metrics.chartHeight)
    }

    /// 這門功法的全部紀錄。一筆都沒有時不畫這一塊，上半張已經寫「還沒有紀錄」。
    /// 練了幾年一門會有幾百列，用 LazyVStack 捲到才建。
    @ViewBuilder
    private var records: some View {
        if !ownLifts.isEmpty {
            VStack(alignment: .leading, spacing: RencanLayout.itemSpacing) {
                SectionTitle(text: "全部紀錄")
                    .padding(.horizontal, Metrics.titleInset)
                LazyVStack(spacing: 0) {
                    ForEach(ownLifts) { record in
                        if record.uid != ownLifts.first?.uid {
                            RowDivider()
                        }
                        row(record)
                    }
                }
                .padding(.horizontal, Metrics.cardInset)
                .background(
                    Color.rencan.surface,
                    in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
                )
            }
        }
    }

    /// 一列紀錄，右邊寫哪一天（不是今年的會帶年份）。點了換成編輯表單：
    /// 「最近修煉」只列 20 筆，更舊的紀錄只有這裡改得到、刪得到。
    private func row(_ record: LiftRecord) -> some View {
        Button {
            flow.sheet = .editLift(record)
        } label: {
            LiftRow(record: record) {
                Text(DayStamp.monthDay(record.day, today: digest.today))
                    .font(RencanType.footnote)
                    .foregroundStyle(Color.rencan.textSecondary)
            }
            .padding(.vertical, Metrics.rowVerticalPadding)
            .frame(minHeight: Metrics.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("編輯這一筆")
    }
}
