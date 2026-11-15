import Foundation

/// 規則引擎往上丟的錯誤。訊息是給使用者看的中文，不夾數值（規矩檔第 4 節）。
public enum RencanError: Error, Equatable, CaseIterable {
    /// 日期不是「yyyy-MM-dd」，或那一天不存在。
    case invalidDate
    case weightOutOfRange
    case bodyFatOutOfRange
    case leanMassOutOfRange
    case heightOutOfRange
    case repsOutOfRange
    case setsOutOfRange
    case negativeLoad
    case unknownMove
    case missingField
    case wrongFieldType
    case duplicateID
    case notJSON
    /// 還沒填身高、還沒選性別，算不出境界。
    case profileMissing
    /// 同一天已經有一筆量測，要先問使用者要不要蓋掉。
    case sameDayMeasurement
    /// 寫進資料庫失敗。
    case saveFailed

    public var message: String {
        switch self {
        case .invalidDate:
            return "日期格式不對"
        case .weightOutOfRange:
            return "體重超出範圍"
        case .bodyFatOutOfRange:
            return "體脂超出範圍"
        case .leanMassOutOfRange:
            return "去脂體重超出範圍"
        case .heightOutOfRange:
            return "身高超出範圍"
        case .repsOutOfRange:
            return "次數超出範圍"
        case .setsOutOfRange:
            return "組數超出範圍"
        case .negativeLoad:
            return "重量不得為負"
        case .unknownMove:
            return "不認得的功法"
        case .missingField:
            return "少了必要欄位"
        case .wrongFieldType:
            return "欄位的格式不對"
        case .duplicateID:
            return "同一筆紀錄出現兩次"
        case .notJSON:
            return "檔案不是網頁版匯出的格式"
        case .profileMissing:
            return "先填身高和性別"
        case .sameDayMeasurement:
            return "這一天已經有一筆量測"
        case .saveFailed:
            return "沒存成功，請再試一次"
        }
    }

    /// 任何錯誤要給使用者看的那句話。不是規則引擎自己的錯誤就說沒存成功，不把系統訊息原樣丟出去。
    public static func message(for error: Error) -> String {
        (error as? RencanError)?.message ?? RencanError.saveFailed.message
    }
}
