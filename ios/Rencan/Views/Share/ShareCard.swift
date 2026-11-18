import RencanCore
import SwiftUI

/// 修煉卡的版面常數：照 .uiux/介面選項-2026-11-19/分享卡選項.html 的甲版（360×640 點，存圖放大三倍）。
private enum Metrics {
    static let size = CGSize(width: 360, height: 640)
    /// 外框（境界色漸層）的寬、外圈圓角；裡面米白卡面的內距與圓角
    static let frameWidth: CGFloat = 6
    static let outerCornerRadius: CGFloat = 22
    static let innerPadding: CGFloat = 6
    static let innerCornerRadius: CGFloat = 16
    /// 上下各段之間
    static let rowGap: CGFloat = 5
    /// 最上面一列：高、印章大小與圓角、彼此間距
    static let headerHeight: CGFloat = 36
    static let headerSpacing: CGFloat = 8
    static let sealSize: CGFloat = 28
    static let sealCornerRadius: CGFloat = 5
    /// 立繪：168×210 的兩倍，像素格才會整齊
    static let portraitCornerRadius: CGFloat = 10
    /// 宗門身分那一條、三格數字、功法格子
    static let bandHeight: CGFloat = 22
    static let statHeight: CGFloat = 30
    static let moveHeight: CGFloat = 23
    static let cellGap: CGFloat = 4
    static let cellCornerRadius: CGFloat = 6
    static let cellPadding: CGFloat = 8
    static let footerHeight: CGFloat = 36
    /// 字級（卡是固定大小的圖，字也固定）
    static let daoLabelSize: CGFloat = 10
    static let daoNameSize: CGFloat = 22
    static let realmSize: CGFloat = 22
    static let stageSize: CGFloat = 15
    static let sealTextSize: CGFloat = 18
    static let bandTitleSize: CGFloat = 14
    static let bandTextSize: CGFloat = 12
    static let statNumberSize: CGFloat = 14
    static let statLabelSize: CGFloat = 10
    static let moveNameSize: CGFloat = 13
    static let moveLevelSize: CGFloat = 11
    static let brandSize: CGFloat = 16
    static let smallSize: CGFloat = 10
    static let dateSize: CGFloat = 11
}

/// 修煉卡上要寫的東西，全部從 Digest 算好，卡只管排版。
/// 存成 Hashable：道號、體脂開關一改，分享頁就照新的內容重出一張圖。
struct ShareCardContent: Hashable {
    /// 道號最多幾個字（卡上那一格放得下的量）
    static let daoNameLimit = 8
    /// 卡上放幾門功法：練得最高的六門
    static let moveCount = 6
    /// 存圖放大幾倍：360×640 點 → 1080×1920，剛好是限時動態的大小
    static let exportScale: CGFloat = 3

    struct MoveLine: Hashable {
        let name: String
        let level: String
    }

    let daoName: String
    let realmIndex: Int
    let realmName: String
    let stage: String
    let portraitName: String
    let sectTitle: String
    let trainDays: Int
    let ffmi: String
    /// nil：使用者在分享頁把體脂關掉了，那一格整個拿掉
    let bodyFat: String?
    let gate: String
    let moves: [MoveLine]
    let date: String

    /// 還沒量過體組成（沒有境界碑）就沒有卡可以分享。
    init?(
        digest: Digest, style: PortraitStyle, daoName: String, showsBodyFat: Bool
    ) {
        guard let stele = digest.stele, let sex = digest.sex else { return nil }
        let standing = stele.standing
        self.daoName = daoName
        realmIndex = standing.realmIndex
        realmName = standing.realm.name
        stage = Tables.stages[standing.stageIndex]
        portraitName = RencanPortrait.name(realmIndex: standing.realmIndex, sex: sex, style: style)
        sectTitle = digest.sect.title
        trainDays = digest.trainDays
        ffmi = Formulas.fmt(stele.ffmi, digits: 2)
        let bodyFatText = Formulas.fmt(stele.measurement.bodyFatPercent, digits: 1) + "%"
        bodyFat = showsBodyFat ? bodyFatText : nil
        gate = Self.gateWord(stele.gate)
        // 分數高的在前；同分照功法表的順序，每次排出來都一樣
        moves = digest.moveCards.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.score != rhs.element.score {
                    return lhs.element.score > rhs.element.score
                }
                return lhs.offset < rhs.offset
            }
            .prefix(Self.moveCount)
            .map { MoveLine(name: $0.element.move.artName, level: $0.element.levelName) }
        date = digest.today.replacingOccurrences(of: "-", with: ".")
    }

    /// 傳 LINE、訊息時，圖下面跟著的那一句（2026-11-19 多米選「圖加一句話」）。
    /// App Store 的下載連結要等上架拿到 Apple ID，拿到前先寫怎麼搜尋。
    var shareMessage: String {
        "我在人蔘修煉練到" + realmName + stage + "了。App Store 搜尋「人蔘修煉」就找得到。"
    }

    /// 根基那一格的兩個字，跟境界碑上那一句同一套說法。
    private static func gateWord(_ gate: BodyFatGate) -> String {
        switch gate {
        case .stable:
            return "穩固"
        case .wavering:
            return "浮動"
        case .low:
            return "偏低"
        case .unstable:
            return "不穩"
        }
    }
}

/// 修煉卡本身（甲版）：最上面道號與境界、中間立繪、宗門身分一條、三格數字、六門功法、最下面 app 名與日期。
/// 存成圖片與分享頁預覽用的是同一個 View，所以固定用淺色，存下來的圖不管手機開不開深色都一樣。
struct ShareCard: View {
    let content: ShareCardContent

    var body: some View {
        VStack(spacing: Metrics.rowGap) {
            header
            portrait
            band
            numbers
            Spacer(minLength: 0)
            footer
        }
        .padding(Metrics.innerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.rencan.cardBase,
            in: RoundedRectangle(cornerRadius: Metrics.innerCornerRadius)
        )
        .padding(Metrics.frameWidth)
        .background(frame, in: RoundedRectangle(cornerRadius: Metrics.outerCornerRadius))
        .frame(width: Metrics.size.width, height: Metrics.size.height)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// 存成 1080×1920 的圖。做不出來回 nil，由分享頁跟使用者說。
    @MainActor
    static func render(_ content: ShareCardContent) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(content: content))
        renderer.scale = ShareCardContent.exportScale
        return renderer.uiImage
    }

    /// 外框：這個境界的小字色到底色再回到小字色，顏色跟著境界換。
    private var frame: LinearGradient {
        let light = Color.rencan.realmSub(content.realmIndex)
        let dark = Color.rencan.realmBase(content.realmIndex)
        return LinearGradient(
            colors: [light, dark, light], startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(spacing: Metrics.headerSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("道號")
                    .font(RencanType.cardText(Metrics.daoLabelSize))
                    .foregroundStyle(Color.rencan.cardMuted)
                // 沒填道號就留白，不擋分享
                Text(content.daoName.isEmpty ? " " : content.daoName)
                    .font(RencanType.cardDisplay(Metrics.daoNameSize))
                    .foregroundStyle(Color.rencan.cardText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(content.realmName)
                .font(RencanType.cardDisplay(Metrics.realmSize))
                .foregroundStyle(Color.rencan.cardTitle)
            Text(content.stage)
                .font(RencanType.cardDisplay(Metrics.stageSize))
                .foregroundStyle(Color.rencan.cardTitle)
            Text("境")
                .font(RencanType.cardDisplay(Metrics.sealTextSize))
                .foregroundStyle(Color.rencan.onSeal)
                .frame(width: Metrics.sealSize, height: Metrics.sealSize)
                .background(
                    Color.rencan.seal,
                    in: RoundedRectangle(cornerRadius: Metrics.sealCornerRadius)
                )
        }
        .padding(.horizontal, Metrics.headerSpacing / 2)
        .frame(height: Metrics.headerHeight)
    }

    private var portrait: some View {
        Image(content.portraitName)
            .interpolation(.none)
            .resizable()
            .frame(
                width: RencanLayout.largePortraitSize.width,
                height: RencanLayout.largePortraitSize.height
            )
            .clipShape(RoundedRectangle(cornerRadius: Metrics.portraitCornerRadius))
    }

    private var band: some View {
        HStack {
            Text(content.sectTitle)
                .font(RencanType.cardDisplay(Metrics.bandTitleSize))
            Spacer(minLength: 0)
            Text("累計修煉 \(content.trainDays) 天")
                .font(RencanType.cardText(Metrics.bandTextSize))
        }
        .foregroundStyle(Color.rencan.onCardBand)
        .padding(.horizontal, Metrics.cellPadding)
        .frame(height: Metrics.bandHeight)
        .background(
            Color.rencan.cardBand, in: RoundedRectangle(cornerRadius: Metrics.cellCornerRadius)
        )
    }

    /// 三格數字（體脂關掉就剩兩格），下面兩排各三門功法。
    private var numbers: some View {
        VStack(spacing: Metrics.cellGap) {
            HStack(spacing: Metrics.cellGap) {
                stat(content.ffmi, label: "FFMI")
                if let bodyFat = content.bodyFat {
                    stat(bodyFat, label: "體脂")
                }
                stat(content.gate, label: "根基")
            }
            let half = (content.moves.count + 1) / 2
            moveRow(Array(content.moves.prefix(half)))
            moveRow(Array(content.moves.dropFirst(half)))
        }
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(RencanType.cardText(Metrics.statNumberSize, weight: .bold))
                .foregroundStyle(Color.rencan.cardText)
            Text(label)
                .font(RencanType.cardText(Metrics.statLabelSize))
                .foregroundStyle(Color.rencan.cardBand)
        }
        .padding(.horizontal, Metrics.cellPadding)
        .frame(maxWidth: .infinity, minHeight: Metrics.statHeight, alignment: .leading)
        .background(
            Color.rencan.cardStat, in: RoundedRectangle(cornerRadius: Metrics.cellCornerRadius)
        )
    }

    private func moveRow(_ lines: [ShareCardContent.MoveLine]) -> some View {
        HStack(spacing: Metrics.cellGap) {
            ForEach(lines, id: \.self) { line in
                HStack {
                    Text(line.name)
                        .font(RencanType.cardDisplay(Metrics.moveNameSize))
                        .foregroundStyle(Color.rencan.cardBand)
                    Spacer(minLength: 0)
                    Text(line.level)
                        .font(RencanType.cardText(Metrics.moveLevelSize))
                        .foregroundStyle(Color.rencan.cardTitle)
                }
                .padding(.horizontal, Metrics.cellPadding)
                .frame(maxWidth: .infinity, minHeight: Metrics.moveHeight)
                .background(
                    Color.rencan.cardMove,
                    in: RoundedRectangle(cornerRadius: Metrics.cellCornerRadius)
                )
            }
        }
    }

    /// 最下面：app 名、怎麼找到它、日期。上架拿到下載連結後，右下角再補 QR 碼。
    private var footer: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("人蔘修煉")
                    .font(RencanType.cardDisplay(Metrics.brandSize))
                    .foregroundStyle(Color.rencan.cardTitle)
                Text("App Store 搜尋：人蔘修煉")
                    .font(RencanType.cardText(Metrics.smallSize))
                    .foregroundStyle(Color.rencan.cardMuted)
            }
            Spacer(minLength: 0)
            Text(content.date)
                .font(RencanType.cardText(Metrics.dateSize))
                .foregroundStyle(Color.rencan.cardMuted)
        }
        .padding(.horizontal, Metrics.headerSpacing / 2)
        .frame(height: Metrics.footerHeight)
    }

    private var accessibilityText: String {
        var parts = ["修煉卡", content.realmName + content.stage, content.sectTitle]
        if !content.daoName.isEmpty {
            parts.insert("道號" + content.daoName, at: 1)
        }
        parts.append("FFMI " + content.ffmi)
        if let bodyFat = content.bodyFat {
            parts.append("體脂 " + bodyFat)
        }
        parts.append("根基" + content.gate)
        return parts.joined(separator: "，")
    }
}
