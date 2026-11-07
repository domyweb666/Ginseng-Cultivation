import Foundation

/// 跟網頁版 index.html L203–331 一字不改的表。
/// 這片（A2 骨架）先放一個門檻常數，REALMS、MOVES、RANKS、LV、STAGES 在片 B1 逐行搬過來。
///
/// 網頁版縮寫對照（搬表時照這張改成完整名）：
///   bf → bodyFatPercent、lean → leanMassKg、hcm → heightCm、f → ffmi、bw → bodyweightKg
public enum Tables {
    /// 體脂率門檻（%）：高於這個值境界顯示「根基不穩」，突破與宗門只採計穩固的（產品定稿）。
    public static let bodyFatStableThresholdPercent: Double = 20
}
