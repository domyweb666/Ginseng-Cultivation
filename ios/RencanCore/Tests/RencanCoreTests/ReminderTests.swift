import XCTest

@testable import RencanCore

/// 每月量測提醒的規則（片 I1）：日子只能選 1 到 28，時間固定早上 8 點。
final class ReminderTests: XCTestCase {
    func test可以選的日子是1到28() {
        XCTAssertEqual(Reminder.allowedDays.lowerBound, 1)
        XCTAssertEqual(Reminder.allowedDays.upperBound, 28)
    }

    func test1到28每一天都合法() {
        for day in 1...28 {
            XCTAssertTrue(Reminder.isValid(day: day), "每月 \(day) 日")
        }
    }

    func test不是每個月都有的29到31不給選() {
        XCTAssertFalse(Reminder.isValid(day: 29))
        XCTAssertFalse(Reminder.isValid(day: 30))
        XCTAssertFalse(Reminder.isValid(day: 31))
    }

    func test0和負數不合法() {
        XCTAssertFalse(Reminder.isValid(day: 0))
        XCTAssertFalse(Reminder.isValid(day: -1))
    }

    func test沒設定過是每月1日早上8點() {
        XCTAssertEqual(Reminder.defaultDay, 1)
        XCTAssertEqual(Reminder.hour, 8)
        XCTAssertEqual(Reminder.minute, 0)
        XCTAssertTrue(Reminder.isValid(day: Reminder.defaultDay))
    }

    func test選單選項的字() {
        XCTAssertEqual(Reminder.dayLabel(1), "每月 1 日")
        XCTAssertEqual(Reminder.dayLabel(28), "每月 28 日")
    }

    func test按鈕上的字跟畫布一樣時間補滿兩位() {
        XCTAssertEqual(Reminder.label(day: 1), "每月 1 日 08:00")
        XCTAssertEqual(Reminder.label(day: 15), "每月 15 日 08:00")
    }
}
