import XCTest

@testable import RencanCore

// 從健康 app 重建量測（片 E4）的合併規則。每條規則至少一條測試，規則寫在 HealthImport.swift 檔頭。
// 時間用「當天第幾毫秒」這種小數字就夠，比的只有先後。

private func sample(
    _ kind: HealthSampleKind, _ value: Double, on date: String, at takenAtMs: Int = 0,
    key: String? = nil
) -> HealthSample {
    HealthSample(
        kind: kind, date: date, value: value, takenAtMs: takenAtMs,
        key: key ?? "\(kind.rawValue)-\(date)-\(takenAtMs)"
    )
}

/// 一天完整的一組：體重加體脂率。
private func pair(_ kg: Double, _ bodyFat: Double, on date: String) -> [HealthSample] {
    [sample(.weight, kg, on: date), sample(.bodyFat, bodyFat, on: date)]
}

private func manual(on date: String, id: String = "manual") -> MeasurementEntry {
    MeasurementEntry(id: id, date: date, weightKg: 72, bodyFatPercent: 18)
}

final class HealthImportMergeTests: XCTestCase {
    func test沒有樣本就什麼都沒有() throws {
        let result = try HealthImport.merge(samples: [], existing: [])
        XCTAssertEqual(result.candidates, [])
        XCTAssertEqual(result.additions, [])
        XCTAssertEqual(result.outOfRangeSamples, 0)
        XCTAssertEqual(result.incompleteDays, 0)
        XCTAssertEqual(result.alreadyRecordedDays, 0)
    }

    func test同一天有體重和體脂率就成一筆() throws {
        let weight = sample(.weight, 70.4, on: "2026-03-05", at: 500, key: "W")
        let bodyFat = sample(.bodyFat, 14.2, on: "2026-03-05", at: 500, key: "F")
        let result = try HealthImport.merge(samples: [weight, bodyFat], existing: [])
        let expected = MeasurementEntry(
            id: "W", date: "2026-03-05", weightKg: 70.4, bodyFatPercent: 14.2, createdAtMs: 500
        )
        XCTAssertEqual(result.candidates, [expected])
        XCTAssertEqual(result.additions, [expected])
    }

    func test同一天體重量了兩次取比較晚的那次() throws {
        let morning = sample(.weight, 70.4, on: "2026-03-05", at: 100)
        let evening = sample(.weight, 71.1, on: "2026-03-05", at: 900)
        let bodyFat = sample(.bodyFat, 14.2, on: "2026-03-05", at: 100)
        let result = try HealthImport.merge(samples: [evening, morning, bodyFat], existing: [])
        XCTAssertEqual(result.candidates.map(\.weightKg), [71.1])
        XCTAssertEqual(result.candidates.first?.createdAtMs, 900)
    }

    func test同一天體脂率量了兩次也取比較晚的那次() throws {
        let weight = sample(.weight, 70.4, on: "2026-03-05", at: 100)
        let morning = sample(.bodyFat, 14.2, on: "2026-03-05", at: 100)
        let evening = sample(.bodyFat, 15.1, on: "2026-03-05", at: 900)
        let result = try HealthImport.merge(samples: [weight, morning, evening], existing: [])
        XCTAssertEqual(result.candidates.map(\.bodyFatPercent), [15.1])
    }

    func test同一個時間的兩筆取key比較大的順序不影響() throws {
        let first = sample(.weight, 70, on: "2026-03-05", at: 100, key: "A")
        let second = sample(.weight, 71, on: "2026-03-05", at: 100, key: "B")
        let bodyFat = sample(.bodyFat, 14.2, on: "2026-03-05")
        let forward = try HealthImport.merge(samples: [first, second, bodyFat], existing: [])
        let backward = try HealthImport.merge(samples: [bodyFat, second, first], existing: [])
        XCTAssertEqual(forward.candidates.map(\.id), ["B"])
        XCTAssertEqual(forward, backward)
    }

    func test只有體重沒有體脂率的那天不成一筆() throws {
        let samples = [sample(.weight, 70.4, on: "2026-03-05")] + pair(70, 14, on: "2026-03-06")
        let result = try HealthImport.merge(samples: samples, existing: [])
        XCTAssertEqual(result.candidates.map(\.date), ["2026-03-06"])
        XCTAssertEqual(result.incompleteDays, 1)
    }

    func test只有體脂率沒有體重的那天不成一筆() throws {
        let result = try HealthImport.merge(
            samples: [sample(.bodyFat, 14.2, on: "2026-03-05")], existing: []
        )
        XCTAssertEqual(result.candidates, [])
        XCTAssertEqual(result.incompleteDays, 1)
    }

    func test體重和體脂率在不同天不會湊成一筆() throws {
        let weight = sample(.weight, 70.4, on: "2026-03-05")
        let bodyFat = sample(.bodyFat, 14.2, on: "2026-03-06")
        let result = try HealthImport.merge(samples: [weight, bodyFat], existing: [])
        XCTAssertEqual(result.candidates, [])
        XCTAssertEqual(result.incompleteDays, 2)
    }

    func test去脂體重同一天有就帶沒有就空著() throws {
        let lean = sample(.leanMass, 60.4, on: "2026-03-05")
        let samples = pair(70.4, 14.2, on: "2026-03-05") + [lean] + pair(70, 14, on: "2026-03-06")
        let result = try HealthImport.merge(samples: samples, existing: [])
        XCTAssertEqual(result.candidates.map(\.leanMassKg), [60.4, nil])
    }

    func test去脂體重在別天不拿來湊() throws {
        let lean = sample(.leanMass, 60.4, on: "2026-03-04")
        let result = try HealthImport.merge(
            samples: pair(70.4, 14.2, on: "2026-03-05") + [lean], existing: []
        )
        XCTAssertEqual(result.candidates.map(\.leanMassKg), [nil])
        XCTAssertEqual(result.incompleteDays, 1)
    }

    func test整理出來的量測照日期由舊到新() throws {
        let samples = pair(70, 14, on: "2026-03-09") + pair(72, 16, on: "2025-12-31")
        let result = try HealthImport.merge(
            samples: samples + pair(71, 15, on: "2026-01-02"), existing: []
        )
        XCTAssertEqual(result.candidates.map(\.date), ["2025-12-31", "2026-01-02", "2026-03-09"])
    }

    func test日期字串壞掉就整批拒絕() {
        let broken = pair(70, 14, on: "2026-03-05") + pair(70, 14, on: "2026-02-30")
        XCTAssertThrowsError(try HealthImport.merge(samples: broken, existing: [])) { error in
            XCTAssertEqual(error as? RencanError, .invalidDate)
        }
    }
}

final class HealthImportExistingTests: XCTestCase {
    func test那一天已經有手打的量測就不動它() throws {
        let samples = pair(70.4, 14.2, on: "2026-03-05") + pair(70, 14, on: "2026-03-06")
        let result = try HealthImport.merge(samples: samples, existing: [manual(on: "2026-03-05")])
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.additions.map(\.date), ["2026-03-06"])
        XCTAssertEqual(result.alreadyRecordedDays, 1)
    }

    func test帶入過的再帶一次不會多一筆() throws {
        let samples = pair(70.4, 14.2, on: "2026-03-05") + pair(70, 14, on: "2026-03-06")
        let first = try HealthImport.merge(samples: samples, existing: [])
        let second = try HealthImport.merge(samples: samples, existing: first.additions)
        XCTAssertEqual(first.additions.count, 2)
        XCTAssertEqual(second.additions, [])
        XCTAssertEqual(second.alreadyRecordedDays, 2)
    }

    func test換時區後同一筆樣本落在前一天也不重複帶入() throws {
        let weight = sample(.weight, 70.4, on: "2026-03-04", at: 100, key: "W")
        let bodyFat = sample(.bodyFat, 14.2, on: "2026-03-04", at: 100, key: "F")
        let imported = MeasurementEntry(
            id: "W", date: "2026-03-05", weightKg: 70.4, bodyFatPercent: 14.2
        )
        let result = try HealthImport.merge(samples: [weight, bodyFat], existing: [imported])
        XCTAssertEqual(result.additions, [])
        XCTAssertEqual(result.alreadyRecordedDays, 1)
    }

    func test既有量測在別天不擋新的一天() throws {
        let result = try HealthImport.merge(
            samples: pair(70.4, 14.2, on: "2026-03-05"), existing: [manual(on: "2026-03-04")]
        )
        XCTAssertEqual(result.additions.map(\.date), ["2026-03-05"])
        XCTAssertEqual(result.alreadyRecordedDays, 0)
    }
}

final class HealthImportRangeTests: XCTestCase {
    func test體重30和200留下29點9和200點1丟掉() throws {
        let kept = pair(30, 14, on: "2026-03-01") + pair(200, 14, on: "2026-03-02")
        let dropped = pair(29.9, 14, on: "2026-03-03") + pair(200.1, 14, on: "2026-03-04")
        let result = try HealthImport.merge(samples: kept + dropped, existing: [])
        XCTAssertEqual(result.candidates.map(\.weightKg), [30, 200])
        XCTAssertEqual(result.outOfRangeSamples, 2)
        XCTAssertEqual(result.incompleteDays, 2)
    }

    func test體脂率3和60留下2點9和60點1丟掉() throws {
        let kept = pair(70, 3, on: "2026-03-01") + pair(70, 60, on: "2026-03-02")
        let dropped = pair(70, 2.9, on: "2026-03-03") + pair(70, 60.1, on: "2026-03-04")
        let result = try HealthImport.merge(samples: kept + dropped, existing: [])
        XCTAssertEqual(result.candidates.map(\.bodyFatPercent), [3, 60])
        XCTAssertEqual(result.outOfRangeSamples, 2)
    }

    func test去脂體重超出範圍只丟去脂那天照樣成一筆() throws {
        let low = pair(70, 14, on: "2026-03-01") + [sample(.leanMass, 19.9, on: "2026-03-01")]
        let high = pair(70, 14, on: "2026-03-02") + [sample(.leanMass, 150.1, on: "2026-03-02")]
        let edge = pair(70, 14, on: "2026-03-03") + [sample(.leanMass, 20, on: "2026-03-03")]
        let result = try HealthImport.merge(samples: low + high + edge, existing: [])
        XCTAssertEqual(result.candidates.map(\.leanMassKg), [nil, nil, 20])
        XCTAssertEqual(result.outOfRangeSamples, 2)
        XCTAssertEqual(result.incompleteDays, 0)
    }

    func test最晚那筆超出範圍就用同一天比較早的合格那筆() throws {
        let good = sample(.weight, 70.4, on: "2026-03-05", at: 100)
        let wild = sample(.weight, 704, on: "2026-03-05", at: 900)
        let bodyFat = sample(.bodyFat, 14.2, on: "2026-03-05")
        let result = try HealthImport.merge(samples: [good, wild, bodyFat], existing: [])
        XCTAssertEqual(result.candidates.map(\.weightKg), [70.4])
        XCTAssertEqual(result.outOfRangeSamples, 1)
    }

    func test不是數字的樣本當成超出範圍丟掉() throws {
        let samples = pair(.nan, 14, on: "2026-03-05") + pair(70, .infinity, on: "2026-03-06")
        let result = try HealthImport.merge(samples: samples, existing: [])
        XCTAssertEqual(result.candidates, [])
        XCTAssertEqual(result.outOfRangeSamples, 2)
    }

    func test健康app的比例0點142換成百分比是14點2() {
        XCTAssertEqual(HealthImport.percent(fromFraction: 0.142), 14.2)
        XCTAssertEqual(HealthImport.percent(fromFraction: 0.07), 7)
    }

    func test比例0點2和0點27換過來剛好是門檻20和27() {
        XCTAssertEqual(HealthImport.percent(fromFraction: 0.2), 20)
        XCTAssertEqual(HealthImport.percent(fromFraction: 0.27), 27)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 20, sex: .male), .wavering)
    }

    func test百分比14點2寫回健康app是比例0點142() {
        XCTAssertEqual(HealthImport.fraction(fromPercent: 14.2), 0.142, accuracy: 1e-12)
        let roundTrip = HealthImport.percent(fromFraction: HealthImport.fraction(fromPercent: 14.2))
        XCTAssertEqual(roundTrip, 14.2)
    }
}
