import Foundation

// 女性版換算（片 B5）。規則與出處在 .vibe/女性版規則.md。
// 男性表一個數字不動。女性只多一步：把 FFMI 換成「男性等值」再查同一張境界表，
// 不另做女性的境界表，兩邊才不會各自漂移。體脂門檻與功法門檻另有女性的數字（在 Tables）。
// 沒選性別不准算，所以凡是跟性別有關的函式，sex 都沒有預設值。

public enum Sex: String, CaseIterable {
    case male
    case female

    /// 體脂超過這個百分比，境界顯示「根基不穩」。男 20、女 27。
    public var bodyFatStableThresholdPercent: Double {
        switch self {
        case .male:
            return Tables.bodyFatStableThresholdPercent
        case .female:
            return Tables.femaleBodyFatStableThresholdPercent
        }
    }

    /// 把自己的 FFMI 換成查境界表用的「男性等值」。男性原樣不動。
    /// 女性：16.7 +（FFMI − 14.6）÷ k，k =（22 − 14.6）÷（25 − 16.7）≈ 0.8916。
    public func maleEquivalentFFMI(_ ffmi: Double) -> Double {
        switch self {
        case .male:
            return ffmi
        case .female:
            let offset = ffmi - Tables.femaleBaselineFFMI
            return Tables.maleBaselineFFMI + offset / Sex.femaleScale
        }
    }

    /// 反過來，把境界表上的門檻換回自己的 FFMI。女性：14.6 +（門檻 − 16.7）× k。
    public func ownFFMI(fromMaleEquivalent equivalent: Double) -> Double {
        switch self {
        case .male:
            return equivalent
        case .female:
            let offset = equivalent - Tables.maleBaselineFFMI
            return Tables.femaleBaselineFFMI + offset * Sex.femaleScale
        }
    }

    /// 畫面「天梯」寫的境界門檻：七個大境界的下限，最後一個是渡劫的上限，共八個數字。
    /// 一律無條件進位到 0.1，保證 FFMI 達到畫面上那個數字就一定在那個境界
    /// （四捨五入的話女性 14.4、18.4、21.1 會差一點點進不去）。
    public func displayedRealmBounds() -> [Double] {
        var bounds = Tables.realms.map(\.lowerFFMI)
        if let last = Tables.realms.last {
            bounds.append(last.upperFFMI)
        }
        return bounds.map { roundedUpToTenth(ownFFMI(fromMaleEquivalent: $0)) }
    }

    private func roundedUpToTenth(_ value: Double) -> Double {
        (value * Sex.tenthsPerUnit).rounded(.up) / Sex.tenthsPerUnit
    }

    /// k：女性的 FFMI 尺度是男性的幾倍。兩個對齊點之間的距離相除。
    private static let femaleSpan = Tables.femaleCeilingFFMI - Tables.femaleBaselineFFMI
    private static let maleSpan = Tables.maleCeilingFFMI - Tables.maleBaselineFFMI
    private static let femaleScale = femaleSpan / maleSpan
    /// 顯示到小數一位。
    private static let tenthsPerUnit: Double = 10
}

extension Move {
    /// 這門功法的五階門檻。女性另有一組（.vibe/女性版規則.md 第三節）。
    public func thresholds(for sex: Sex) -> [Double] {
        switch sex {
        case .male:
            return thresholds
        case .female:
            return femaleThresholds
        }
    }
}
