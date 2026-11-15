import Foundation

/// 規則引擎往上丟的錯誤。訊息是給使用者看的中文，不夾數值（規矩檔第 4 節）。
public enum RencanError: Error, Equatable {
    /// 日期不是「yyyy-MM-dd」，或那一天不存在。
    case invalidDate

    public var message: String {
        switch self {
        case .invalidDate:
            return "日期格式不對"
        }
    }
}
