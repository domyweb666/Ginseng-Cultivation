import XCTest

@testable import RencanCore

// 小工具的快照（組塊 G，PRD S19、S20）。假資料跟 SiriReplyTests、DigestTests 同一組：
// 身高 174 的男性，體重 70.4、體脂 14.2% 是金丹中期，距金丹後期還差 0.5 公斤肌肉。
// 今天固定 2026-03-11（星期三），那一週的星期一是 2026-03-09。

private func weighing(
    _ kg: Double, bodyFat: Double, on date: String, leanMassKg: Double? = nil
) -> MeasurementEntry {
    MeasurementEntry(
        id: date, date: date, weightKg: kg, bodyFatPercent: bodyFat, leanMassKg: leanMassKg
    )
}

private func squat(on date: String, tag: String = "") -> LiftEntry {
    LiftEntry(id: date + tag, date: date, move: .squat, kg: 60, reps: 5, sets: 1)
}

final class WidgetSnapshotTests: XCTestCase {
    private let today = "2026-03-11"

    private func snapshot(
        measurements: [MeasurementEntry] = [], lifts: [LiftEntry] = [],
        heightCm: Double? = 174, sex: Sex? = .male
    ) throws -> WidgetSnapshot {
        let digest = try Digest(
            measurements: measurements, lifts: lifts, heightCm: heightCm, sex: sex, today: today
        )
        return try WidgetSnapshot(digest: digest, updatedAtMs: 1_000)
    }

    // MARK: 境界

    func test金丹中期抄出境界期別與還差幾公斤() throws {
        let made = try snapshot(measurements: [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")])
        XCTAssertEqual(made.realmName, "金丹")
        XCTAssertEqual(made.stageName, "中期")
        XCTAssertEqual(made.realmText, "金丹中期")
        XCTAssertFalse(made.isUnstable)
        XCTAssertEqual(made.detailText, "距金丹後期還差 0.5 公斤肌肉")
        XCTAssertEqual(made.detailLines, ["距金丹後期", "還差 0.5 公斤肌肉"])
        XCTAssertEqual(made.updatedAtMs, 1_000)
    }

    func test跟Siri講的是同一個境界與同一個差距() throws {
        let measurements = [weighing(73, bodyFat: 15, on: "2026-03-05")]
        let digest = try Digest(
            measurements: measurements, lifts: [], heightCm: 174, sex: .male, today: today
        )
        let made = try WidgetSnapshot(digest: digest, updatedAtMs: 0)
        XCTAssertEqual(made.realmText, digest.stele?.standing.label)
        XCTAssertEqual(made.kgToNext, digest.stele?.gap?.leanNeededKg)
        XCTAssertEqual(made.detailText, "距元嬰初期還差 0.4 公斤肌肉")
    }

    func test還沒量過是尚未入道() throws {
        let made = try snapshot()
        XCTAssertNil(made.realmName)
        XCTAssertNil(made.stageName)
        XCTAssertEqual(made.realmText, "尚未入道")
        XCTAssertEqual(made.detailText, "先量一次體組成")
    }

    func test沒填身高或性別也是尚未入道() throws {
        let measurements = [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")]
        let noHeight = try snapshot(measurements: measurements, heightCm: nil)
        let noSex = try snapshot(measurements: measurements, sex: nil)
        XCTAssertEqual(noHeight.realmText, "尚未入道")
        XCTAssertEqual(noSex.realmText, "尚未入道")
    }

    func test體脂24是根基不穩() throws {
        let made = try snapshot(measurements: [weighing(80, bodyFat: 24, on: "2026-03-05")])
        XCTAssertEqual(made.realmText, "金丹中期")
        XCTAssertTrue(made.isUnstable)
        XCTAssertEqual(made.detailText, "根基不穩，體脂降下來才生效")
        XCTAssertEqual(made.detailLines, ["根基不穩", "體脂降下來才生效"])
    }

    func test渡劫後期沒有下一期() throws {
        let top = weighing(90, bodyFat: 11, on: "2026-03-05", leanMassKg: 80)
        let made = try snapshot(measurements: [top])
        XCTAssertEqual(made.realmText, "渡劫後期")
        XCTAssertNil(made.nextLabel)
        XCTAssertNil(made.kgToNext)
        XCTAssertEqual(made.detailText, "已是最高的一期")
    }

    // MARK: 本週天數

    func test只帶這一週的日期同一天記兩筆算一天() throws {
        let lastWeek = [squat(on: "2026-03-08")]
        let monday = [squat(on: "2026-03-09"), squat(on: "2026-03-09", tag: "b")]
        let made = try snapshot(lifts: lastWeek + monday + [squat(on: "2026-03-11")])
        XCTAssertEqual(made.weekDays, ["2026-03-09", "2026-03-11"])
        XCTAssertEqual(try made.weekCount(today: today), 2)
    }

    func test快照的本週天數跟境界頁那一格一樣() throws {
        let lifts = [squat(on: "2026-03-02"), squat(on: "2026-03-10"), squat(on: "2026-03-11")]
        let digest = try Digest(
            measurements: [], lifts: lifts, heightCm: 174, sex: .male, today: today
        )
        let made = try WidgetSnapshot(digest: digest, updatedAtMs: 0)
        XCTAssertEqual(try made.weekCount(today: today), digest.weekCount)
    }

    func test同一週裡過幾天再看天數不變() throws {
        let made = try snapshot(lifts: [squat(on: "2026-03-09"), squat(on: "2026-03-11")])
        XCTAssertEqual(try made.weekCount(today: "2026-03-15"), 2)
    }

    func test跨到下一週沒打開app天數歸零() throws {
        let made = try snapshot(lifts: [squat(on: "2026-03-09"), squat(on: "2026-03-11")])
        XCTAssertEqual(try made.weekCount(today: "2026-03-16"), 0)
    }

    func test沒有修煉是0天() throws {
        XCTAssertEqual(try snapshot().weekCount(today: today), 0)
    }

    func test今天的日期壞掉會丟錯不會當成0天() throws {
        let made = try snapshot(lifts: [squat(on: "2026-03-09")])
        XCTAssertThrowsError(try made.weekCount(today: "2026/03/11")) { error in
            XCTAssertEqual(error as? RencanError, .invalidDate)
        }
    }

    // MARK: 存與讀

    func test存下去再讀回來一模一樣() throws {
        let lifts = [squat(on: "2026-03-09"), squat(on: "2026-03-11")]
        let made = try snapshot(
            measurements: [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")], lifts: lifts
        )
        XCTAssertEqual(try WidgetSnapshot.decode(made.encoded()), made)
    }

    func test快照裡沒有體重體脂與FFMI() throws {
        let made = try snapshot(measurements: [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")])
        let text = try XCTUnwrap(String(data: made.encoded(), encoding: .utf8))
        XCTAssertFalse(text.contains("70.4"))
        XCTAssertFalse(text.contains("14.2"))
        XCTAssertFalse(text.contains("20.3"))
    }

    func test讀不懂的內容會丟錯() {
        XCTAssertThrowsError(try WidgetSnapshot.decode(Data("不是快照".utf8)))
    }

    func test沒有快照時用的那一份是尚未入道0天() throws {
        XCTAssertEqual(WidgetSnapshot.empty.realmText, "尚未入道")
        XCTAssertEqual(try WidgetSnapshot.empty.weekCount(today: today), 0)
    }

    func testAppGroup代號跟entitlements寫的一樣() {
        XCTAssertEqual(WidgetSnapshot.appGroupID, "group.org.domyweb.rencan")
    }
}
