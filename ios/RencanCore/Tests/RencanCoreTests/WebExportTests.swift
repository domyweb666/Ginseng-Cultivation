import XCTest

@testable import RencanCore

// 網頁版匯出檔讀得進來，壞檔擋在門口（片 B4）。
// 好檔用的就是黃金集那十組假資料；壞檔在這裡現寫，每種壞法一條。

private let goodMeasurement = #"{"id":"m1","date":"2026-03-01","weight":70,"bf":15,"t":1}"#
private let goodLift =
    #"{"id":"l1","date":"2026-03-02","move":"squat","kg":100,"reps":5,"sets":3,"bw":null,"t":2}"#

/// 拼一份匯出檔。沒給的部分是空的或正常值。
private func exportFile(meas: String = "", lift: String = "", height: String = "174") -> Data {
    Data(#"{"meas":[\#(meas)],"lift":[\#(lift)],"cfg":{"height":\#(height)}}"#.utf8)
}

/// 把好的那筆量測換掉一個欄位的值。
private func measurement(replacing old: String, with new: String) -> String {
    goodMeasurement.replacingOccurrences(of: old, with: new)
}

private func liftRecord(replacing old: String, with new: String) -> String {
    goodLift.replacingOccurrences(of: old, with: new)
}

final class WebExportTests: XCTestCase {
    private func assertRejected(_ data: Data, _ record: WebExportRecord, _ reason: RencanError) {
        XCTAssertThrowsError(try WebExport.decode(data)) { error in
            let expected = WebExportError(record: record, reason: reason)
            XCTAssertEqual(error as? WebExportError, expected)
        }
    }

    // MARK: 好檔

    func test網頁版匯出檔讀得進來() throws {
        let found = Bundle.module.url(
            forResource: "web-export", withExtension: "json", subdirectory: "Fixtures"
        )
        let data = try Data(contentsOf: try XCTUnwrap(found))
        let golden = try JSONDecoder().decode(GoldenFile.self, from: data)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(root["groups"] as? [[String: Any]])
        XCTAssertEqual(groups.count, golden.groups.count)
        for (raw, group) in zip(groups, golden.groups) {
            let export = try XCTUnwrap(raw["export"], group.name)
            let decoded = try WebExport.decode(JSONSerialization.data(withJSONObject: export))
            XCTAssertEqual(decoded.measurements, group.measurements, group.name)
            XCTAssertEqual(decoded.lifts, group.lifts, group.name)
            XCTAssertEqual(decoded.heightCm, group.heightCm, group.name)
        }
    }

    func test匯出再讀回來一筆不少一字不差() throws {
        let original = try WebExport.decode(exportFile(meas: goodMeasurement, lift: goodLift))
        let again = try WebExport.decode(original.encoded())
        XCTAssertEqual(again, original)
        XCTAssertEqual(again.measurements.count, 1)
        XCTAssertEqual(again.lifts.count, 1)
        XCTAssertEqual(again.heightCm, 174)
    }

    func test檔案裡沒有身高就是沒有不補預設值() throws {
        let decoded = try WebExport.decode(Data(#"{"meas":[],"lift":[]}"#.utf8))
        XCTAssertNil(decoded.heightCm)
    }

    // MARK: 壞檔

    func test不是JSON的檔案整份拒絕() {
        assertRejected(Data("這不是匯出檔".utf8), .file, .notJSON)
    }

    func test日期格式錯整份拒絕() {
        let bad = measurement(replacing: #""date":"2026-03-01""#, with: #""date":"2026/03/01""#)
        assertRejected(exportFile(meas: bad), .measurement(1), .invalidDate)
    }

    func test體重超出範圍整份拒絕() {
        let bad = measurement(replacing: #""weight":70"#, with: #""weight":250"#)
        assertRejected(exportFile(meas: bad), .measurement(1), .weightOutOfRange)
    }

    func test體脂超出範圍整份拒絕() {
        let bad = measurement(replacing: #""bf":15"#, with: #""bf":70"#)
        assertRejected(exportFile(meas: bad), .measurement(1), .bodyFatOutOfRange)
    }

    func test去脂體重超出範圍整份拒絕() {
        let bad = measurement(replacing: #""bf":15"#, with: #""bf":15,"lean":10"#)
        assertRejected(exportFile(meas: bad), .measurement(1), .leanMassOutOfRange)
    }

    func test身高超出範圍整份拒絕() {
        assertRejected(exportFile(height: "300"), .settings, .heightOutOfRange)
    }

    func test不認得的功法整份拒絕() {
        let bad = liftRecord(replacing: #""move":"squat""#, with: #""move":"curl""#)
        assertRejected(exportFile(lift: bad), .lift(1), .unknownMove)
    }

    func test少了必要欄位整份拒絕() {
        let bad = measurement(replacing: #""weight":70,"#, with: "")
        assertRejected(exportFile(meas: bad), .measurement(1), .missingField)
    }

    func test連量測那一欄都沒有整份拒絕() {
        assertRejected(Data(#"{"lift":[]}"#.utf8), .file, .missingField)
    }

    func test同一個id出現兩次整份拒絕() {
        let twice = goodMeasurement + "," + goodMeasurement
        assertRejected(exportFile(meas: twice), .measurement(2), .duplicateID)
    }

    func test次數超出範圍整份拒絕() {
        let bad = liftRecord(replacing: #""reps":5"#, with: #""reps":51"#)
        assertRejected(exportFile(lift: bad), .lift(1), .repsOutOfRange)
    }

    func test組數超出範圍整份拒絕() {
        let bad = liftRecord(replacing: #""sets":3"#, with: #""sets":0"#)
        assertRejected(exportFile(lift: bad), .lift(1), .setsOutOfRange)
    }

    func test重量是負的整份拒絕() {
        let bad = liftRecord(replacing: #""kg":100"#, with: #""kg":-5"#)
        assertRejected(exportFile(lift: bad), .lift(1), .negativeLoad)
    }

    func test數字欄位寫成文字整份拒絕() {
        let bad = measurement(replacing: #""weight":70"#, with: #""weight":"七十""#)
        assertRejected(exportFile(meas: bad), .measurement(1), .wrongFieldType)
    }

    func test壞的是第二筆修煉就說第二筆() {
        let bad = liftRecord(replacing: #""id":"l1""#, with: #""id":"l2""#)
            .replacingOccurrences(of: #""reps":5"#, with: #""reps":99"#)
        assertRejected(exportFile(lift: goodLift + "," + bad), .lift(2), .repsOutOfRange)
    }

    // MARK: 原因與範圍

    func test每一種原因都有一句中文而且不夾數字() {
        for reason in RencanError.allCases {
            XCTAssertFalse(reason.message.isEmpty, "\(reason)")
            let hasDigit = reason.message.contains { $0.isASCII && $0.isNumber }
            XCTAssertFalse(hasDigit, "\(reason)")
        }
    }

    func test體重30和200剛好在範圍內29點9和200點1不行() throws {
        func entry(_ weightKg: Double) -> MeasurementEntry {
            MeasurementEntry(id: "a", date: "2026-03-01", weightKg: weightKg, bodyFatPercent: 15)
        }
        XCTAssertNoThrow(try Validation.check(entry(30)))
        XCTAssertNoThrow(try Validation.check(entry(200)))
        XCTAssertThrowsError(try Validation.check(entry(29.9)))
        XCTAssertThrowsError(try Validation.check(entry(200.1)))
    }

    func test體脂3和60剛好在範圍內2點9和60點1不行() throws {
        func entry(_ bodyFat: Double) -> MeasurementEntry {
            MeasurementEntry(id: "a", date: "2026-03-01", weightKg: 70, bodyFatPercent: bodyFat)
        }
        XCTAssertNoThrow(try Validation.check(entry(3)))
        XCTAssertNoThrow(try Validation.check(entry(60)))
        XCTAssertThrowsError(try Validation.check(entry(2.9)))
        XCTAssertThrowsError(try Validation.check(entry(60.1)))
    }

    func test身高120和230剛好在範圍內119和231不行() {
        XCTAssertNoThrow(try Validation.check(heightCm: 120))
        XCTAssertNoThrow(try Validation.check(heightCm: 230))
        XCTAssertThrowsError(try Validation.check(heightCm: 119))
        XCTAssertThrowsError(try Validation.check(heightCm: 231))
    }

    func test次數1到50組數1到20重量可以是0() throws {
        func entry(reps: Int, sets: Int) -> LiftEntry {
            LiftEntry(id: "a", date: "2026-03-01", move: .pull, kg: 0, reps: reps, sets: sets)
        }
        XCTAssertNoThrow(try Validation.check(entry(reps: 1, sets: 1)))
        XCTAssertNoThrow(try Validation.check(entry(reps: 50, sets: 20)))
        XCTAssertThrowsError(try Validation.check(entry(reps: 0, sets: 1)))
        XCTAssertThrowsError(try Validation.check(entry(reps: 1, sets: 21)))
    }
}
