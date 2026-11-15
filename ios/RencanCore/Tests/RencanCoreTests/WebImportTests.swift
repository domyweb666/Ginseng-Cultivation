import XCTest

@testable import RencanCore

// 匯入前的比對（片 F3）：哪幾筆會新增、哪幾筆本機已經有、身高要不要改，
// 以及壞檔的那句中文說明。規則寫在 WebImport.swift 檔頭。

private func weighing(_ id: String, on date: String, createdAtMs: Int = 0) -> MeasurementEntry {
    MeasurementEntry(
        id: id, date: date, weightKg: 70, bodyFatPercent: 15, createdAtMs: createdAtMs
    )
}

private func squat(_ id: String, on date: String = "2026-03-02") -> LiftEntry {
    LiftEntry(id: id, date: date, move: .squat, kg: 100, reps: 5, sets: 3)
}

private func plan(
    fileMeasurements: [MeasurementEntry] = [], fileLifts: [LiftEntry] = [],
    fileHeightCm: Double? = nil, localMeasurements: [MeasurementEntry] = [],
    localLifts: [LiftEntry] = [], localHeightCm: Double? = 174
) -> WebImportPlan {
    let file = WebExport(measurements: fileMeasurements, lifts: fileLifts, heightCm: fileHeightCm)
    return WebImportPlan(
        file: file, localMeasurements: localMeasurements, localLifts: localLifts,
        localHeightCm: localHeightCm
    )
}

final class WebImportTests: XCTestCase {
    // MARK: 會新增哪幾筆

    func test本機是空的時候檔案裡的紀錄全部新增() {
        let first = weighing("2026-03-01", on: "2026-03-01")
        let second = weighing("2026-03-08", on: "2026-03-08")
        let result = plan(
            fileMeasurements: [first, second], fileLifts: [squat("l1"), squat("l2")]
        )
        XCTAssertEqual(result.measurements, [first, second])
        XCTAssertEqual(result.lifts, [squat("l1"), squat("l2")])
        XCTAssertEqual(result.measurementTotal, 2)
        XCTAssertEqual(result.liftTotal, 2)
        XCTAssertEqual(result.addCount, 4)
        XCTAssertEqual(result.alreadyHaveCount, 0)
        XCTAssertEqual(result.sameDayExtraCount, 0)
        XCTAssertTrue(result.hasChanges)
    }

    func test本機同一天已經有量測就跳過不蓋本機的() {
        let local = weighing("local-uuid", on: "2026-03-01")
        let incoming = weighing("2026-03-01", on: "2026-03-01")
        let other = weighing("2026-03-08", on: "2026-03-08")
        let result = plan(fileMeasurements: [incoming, other], localMeasurements: [local])
        XCTAssertEqual(result.measurements, [other])
        XCTAssertEqual(result.alreadyHaveCount, 1)
    }

    func test本機有同一個id的量測就跳過() {
        let local = weighing("same-id", on: "2026-03-01")
        let incoming = weighing("same-id", on: "2026-03-05")
        let result = plan(fileMeasurements: [incoming], localMeasurements: [local])
        XCTAssertEqual(result.measurements, [])
        XCTAssertEqual(result.alreadyHaveCount, 1)
        XCTAssertFalse(result.hasChanges)
    }

    func test本機有同一個id的修煉就跳過() {
        let result = plan(
            fileLifts: [squat("l1"), squat("l2"), squat("l3")], localLifts: [squat("l2")]
        )
        XCTAssertEqual(result.lifts, [squat("l1"), squat("l3")])
        XCTAssertEqual(result.alreadyHaveCount, 1)
    }

    func test同一天記兩筆不同id的修煉兩筆都新增() {
        let result = plan(fileLifts: [squat("l1"), squat("l2")], localLifts: [squat("l0")])
        XCTAssertEqual(result.lifts.count, 2)
        XCTAssertEqual(result.alreadyHaveCount, 0)
    }

    // MARK: 檔案裡同一天多筆量測

    func test檔案裡同一天多筆量測只留最晚建立的那筆() {
        let early = weighing("a", on: "2026-03-01", createdAtMs: 100)
        let late = weighing("b", on: "2026-03-01", createdAtMs: 900)
        let middle = weighing("c", on: "2026-03-01", createdAtMs: 500)
        let result = plan(fileMeasurements: [early, late, middle])
        XCTAssertEqual(result.measurements, [late])
        XCTAssertEqual(result.sameDayExtraCount, 2)
        XCTAssertEqual(result.alreadyHaveCount, 0)
    }

    func test同一天多筆建立時間一樣留檔案裡後面那筆() {
        let first = weighing("a", on: "2026-03-01")
        let second = weighing("b", on: "2026-03-01")
        let result = plan(fileMeasurements: [first, second])
        XCTAssertEqual(result.measurements, [second])
        XCTAssertEqual(result.sameDayExtraCount, 1)
    }

    func test本機已經有那一天時檔案裡同天的幾筆都算本機已經有() {
        let local = weighing("local-uuid", on: "2026-03-01")
        let first = weighing("a", on: "2026-03-01", createdAtMs: 100)
        let second = weighing("b", on: "2026-03-01", createdAtMs: 900)
        let result = plan(fileMeasurements: [first, second], localMeasurements: [local])
        XCTAssertEqual(result.measurements, [])
        XCTAssertEqual(result.alreadyHaveCount, 2)
        XCTAssertEqual(result.sameDayExtraCount, 0)
    }

    func test留下來的量測照檔案裡原本的順序() {
        let third = weighing("c", on: "2026-03-15")
        let first = weighing("a", on: "2026-03-01", createdAtMs: 100)
        let replaced = weighing("b", on: "2026-03-01", createdAtMs: 900)
        let result = plan(fileMeasurements: [third, first, replaced])
        XCTAssertEqual(result.measurements, [third, replaced])
    }

    func test新增加跳過加同天多出來的等於檔案裡的總筆數() {
        let local = weighing("local-uuid", on: "2026-03-01")
        let taken = weighing("2026-03-01", on: "2026-03-01")
        let early = weighing("a", on: "2026-03-08", createdAtMs: 100)
        let late = weighing("b", on: "2026-03-08", createdAtMs: 900)
        let result = plan(
            fileMeasurements: [taken, early, late], fileLifts: [squat("l1"), squat("l2")],
            localMeasurements: [local], localLifts: [squat("l1")]
        )
        let total = result.measurementTotal + result.liftTotal
        XCTAssertEqual(total, 5)
        XCTAssertEqual(result.addCount, 2)
        XCTAssertEqual(result.alreadyHaveCount, 2)
        XCTAssertEqual(result.sameDayExtraCount, 1)
        XCTAssertEqual(
            result.addCount + result.alreadyHaveCount + result.sameDayExtraCount, total
        )
    }

    // MARK: 身高

    func test檔案的身高跟本機不一樣就改成檔案的() {
        let result = plan(fileHeightCm: 180, localHeightCm: 174)
        XCTAssertEqual(result.heightCm, 180)
        XCTAssertTrue(result.hasChanges)
    }

    func test檔案的身高跟本機一樣就不動() {
        let result = plan(fileHeightCm: 174, localHeightCm: 174)
        XCTAssertNil(result.heightCm)
        XCTAssertFalse(result.hasChanges)
    }

    func test檔案沒有身高就不動本機的身高() {
        let result = plan(fileHeightCm: nil, localHeightCm: 174)
        XCTAssertNil(result.heightCm)
    }

    func test本機還沒有身高時帶檔案的身高() {
        let result = plan(fileHeightCm: 168, localHeightCm: nil)
        XCTAssertEqual(result.heightCm, 168)
    }

    // MARK: 整份來回

    func test匯出的檔案匯回同一支手機一筆都不新增() throws {
        let measurements = [weighing("m1", on: "2026-03-01"), weighing("m2", on: "2026-03-08")]
        let lifts = [squat("l1"), squat("l2", on: "2026-03-09")]
        let exported = WebExport(measurements: measurements, lifts: lifts, heightCm: 174)
        let file = try WebExport.decode(exported.encoded())
        let result = WebImportPlan(
            file: file, localMeasurements: measurements, localLifts: lifts, localHeightCm: 174
        )
        XCTAssertEqual(result.addCount, 0)
        XCTAssertEqual(result.alreadyHaveCount, 4)
        XCTAssertFalse(result.hasChanges)
    }

    func test全部刪除後把匯出的檔案匯回來一筆不少() throws {
        let measurements = [weighing("m1", on: "2026-03-01"), weighing("m2", on: "2026-03-08")]
        let lifts = [squat("l1"), squat("l2", on: "2026-03-09")]
        let exported = WebExport(measurements: measurements, lifts: lifts, heightCm: 174)
        let file = try WebExport.decode(exported.encoded())
        let result = WebImportPlan(
            file: file, localMeasurements: [], localLifts: [], localHeightCm: 174
        )
        XCTAssertEqual(result.measurements, measurements)
        XCTAssertEqual(result.lifts, lifts)
        XCTAssertNil(result.heightCm)
    }

    func test匯入檔的大小上限是5MB() {
        XCTAssertEqual(WebImportPlan.maximumFileBytes, 5 * 1024 * 1024)
    }

    // MARK: 壞檔的說明

    func test壞的是量測時說第幾筆量測與原因() {
        let problem = WebExportError(record: .measurement(3), reason: .weightOutOfRange)
        XCTAssertEqual(problem.message, "第 3 筆量測：體重超出範圍")
    }

    func test壞的是修煉時說第幾筆修煉與原因() {
        let problem = WebExportError(record: .lift(12), reason: .unknownMove)
        XCTAssertEqual(problem.message, "第 12 筆修煉：不認得的功法")
    }

    func test壞的是身高時說身高設定與原因() {
        let problem = WebExportError(record: .settings, reason: .heightOutOfRange)
        XCTAssertEqual(problem.message, "身高設定：身高超出範圍")
    }

    func test整份檔案不是JSON時只說原因() {
        let problem = WebExportError(record: .file, reason: .notJSON)
        XCTAssertEqual(problem.message, "檔案不是網頁版匯出的格式")
    }

    func test真的壞檔丟出來的錯誤換得成那句說明() {
        let bad = #"{"meas":[{"id":"m1","date":"2026-03-01","weight":500,"bf":15}],"lift":[]}"#
        XCTAssertThrowsError(try WebExport.decode(Data(bad.utf8))) { error in
            XCTAssertEqual((error as? WebExportError)?.message, "第 1 筆量測：體重超出範圍")
        }
    }
}
