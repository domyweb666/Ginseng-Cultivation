import RencanCore
import SwiftUI

/// 功法段最上面的三格（畫布 AnalysisGong）：累計修煉、這個月、練到大成幾門。
struct GongStats: View {
    let digest: Digest

    var body: some View {
        StatPanel {
            StatCell(value: String(digest.trainDays), unit: "天", caption: "累計修煉")
            StatCell(value: String(digest.monthCount), unit: "天", caption: "這個月")
            StatCell(value: String(digest.accomplishedCount), unit: "門", caption: "練到大成")
        }
    }
}
