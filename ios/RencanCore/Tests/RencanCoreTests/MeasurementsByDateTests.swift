import XCTest

@testable import RencanCore

/// 量測排好一次再查體重（MeasurementsByDate），答案要跟每次重排的舊版 bwAt、liftCalc 一模一樣。
final class MeasurementsByDateTests: XCTestCase {
    private func weighing(
        _ kg: Double, on date: String, createdAtMs: Int = 0, id: String? = nil
    ) -> MeasurementEntry {
        MeasurementEntry(
            id: id ?? "\(date)-\(createdAtMs)-\(kg)", date: date, weightKg: kg,
            bodyFatPercent: 15, createdAtMs: createdAtMs
        )
    }

    /// 三月每一天，加上全部量測之前與之後的日子。
    private let queryDays: [String] = {
        var days = ["2025-12-31", "2026-02-28"]
        for day in 1...31 {
            days.append(String(format: "2026-03-%02d", day))
        }
        days.append(contentsOf: ["2026-04-01", "2027-01-01"])
        return days
    }()

    /// 對每一個查詢日，新舊兩版的體重都一樣。
    private func assertSameBodyweight(
        _ measurements: [MeasurementEntry], file: StaticString = #filePath, line: UInt = #line
    ) {
        let sorted = MeasurementsByDate(measurements)
        for day in queryDays {
            XCTAssertEqual(
                Formulas.bwAt(date: day, byDate: sorted),
                Formulas.bwAt(date: day, measurements: measurements), day, file: file, line: line
            )
        }
    }

    /// 打散順序、同一天好幾筆、建立時間有一位數也有兩位數、有幾筆體重是 0。
    private func scrambled() -> [MeasurementEntry] {
        (0..<60).map { index in
            let day = String(format: "2026-03-%02d", 3 + (index * 13) % 20)
            let kg = index % 11 == 0 ? 0 : 60 + Double(index % 7)
            return weighing(kg, on: day, createdAtMs: (index * 37) % 23, id: "m\(index)")
        }
    }

    func test打散的資料新舊版體重都一樣() {
        let all = scrambled()
        XCTAssertTrue(MeasurementsByDate(all).isDateAscending)
        assertSameBodyweight(all)
    }

    func test同一天多筆選排序後最後一筆() {
        // byDate 是把日期和建立時間接成字串比，"…10" 排在 "…9" 前面，所以選到的是 9 那筆。
        let nine = weighing(71, on: "2026-03-05", createdAtMs: 9)
        let ten = weighing(72, on: "2026-03-05", createdAtMs: 10)
        let all = [nine, ten]
        XCTAssertEqual(Formulas.bwAt(date: "2026-03-05", byDate: MeasurementsByDate(all)), 71)
        assertSameBodyweight(all)
        assertSameBodyweight([ten, nine])
    }

    func test同一天建立時間也一樣時照原本的先後() {
        let first = weighing(70, on: "2026-03-05", id: "a")
        let second = weighing(73, on: "2026-03-05", id: "b")
        XCTAssertEqual(
            Formulas.bwAt(date: "2026-03-05", byDate: MeasurementsByDate([first, second])), 73
        )
        assertSameBodyweight([first, second])
        assertSameBodyweight([second, first])
    }

    func test查的日子在全部量測之前就用最新的一筆() {
        let older = weighing(70, on: "2026-03-05")
        let newer = weighing(74, on: "2026-03-20")
        let sorted = MeasurementsByDate([newer, older])
        XCTAssertEqual(Formulas.bwAt(date: "2026-01-01", byDate: sorted), 74)
        assertSameBodyweight([newer, older])
    }

    func test查的日子在全部量測之後就用最後一筆() {
        let older = weighing(70, on: "2026-03-05")
        let newer = weighing(74, on: "2026-03-20")
        XCTAssertEqual(
            Formulas.bwAt(date: "2026-12-01", byDate: MeasurementsByDate([newer, older])), 74
        )
    }

    func test查的日子剛好有量測就用那天的() {
        let older = weighing(70, on: "2026-03-05")
        let newer = weighing(74, on: "2026-03-20")
        let sorted = MeasurementsByDate([newer, older])
        XCTAssertEqual(Formulas.bwAt(date: "2026-03-05", byDate: sorted), 70)
        XCTAssertEqual(Formulas.bwAt(date: "2026-03-20", byDate: sorted), 74)
        XCTAssertEqual(Formulas.bwAt(date: "2026-03-19", byDate: sorted), 70)
    }

    func test選到體重是0的那筆就是沒有體重() {
        let zero = weighing(0, on: "2026-03-05")
        let later = weighing(74, on: "2026-03-20")
        let sorted = MeasurementsByDate([later, zero])
        XCTAssertNil(Formulas.bwAt(date: "2026-03-10", byDate: sorted))
        XCTAssertEqual(Formulas.bwAt(date: "2026-03-25", byDate: sorted), 74)
        // 全部都在那天之後、最新的一筆是 0，也是沒有體重。
        XCTAssertNil(Formulas.bwAt(date: "2026-01-01", byDate: MeasurementsByDate([zero])))
        assertSameBodyweight([later, zero])
        assertSameBodyweight([zero])
    }

    func test沒有任何量測就沒有體重() {
        XCTAssertNil(Formulas.bwAt(date: "2026-03-05", byDate: MeasurementsByDate([])))
        assertSameBodyweight([])
    }

    func test日期壞掉排不出先後時退回逐筆找() {
        // "2026-03-0" 是 "2026-03-01" 的開頭：接上建立時間後排序跟日期先後對不上。
        let broken = weighing(70, on: "2026-03-0", createdAtMs: 5)
        let normal = weighing(74, on: "2026-03-01", createdAtMs: 0)
        let all = [broken, normal]
        XCTAssertFalse(MeasurementsByDate(all).isDateAscending)
        assertSameBodyweight(all)
        assertSameBodyweight(all + [weighing(66, on: "2026-03-15", createdAtMs: 1)])
    }

    func test修煉的計算新舊版一樣() {
        let all = scrambled()
        let sorted = MeasurementsByDate(all)
        let snapshots: [Double?] = [nil, 0, 80]
        for (index, day) in queryDays.enumerated() {
            let lift = LiftEntry(
                id: "l\(index)", date: day, move: index % 2 == 0 ? .squat : .pull,
                kg: 60, reps: 5, sets: 3, bodyweightKg: snapshots[index % snapshots.count]
            )
            XCTAssertEqual(
                Formulas.liftCalc(lift, byDate: sorted),
                Formulas.liftCalc(lift, measurements: all), day
            )
        }
    }

    func testDigest的體重與等級跟舊版一樣() throws {
        let all = scrambled()
        let digest = try Digest(
            measurements: all, lifts: [], heightCm: nil, sex: .male, today: "2026-03-31"
        )
        for (index, day) in queryDays.enumerated() {
            XCTAssertEqual(
                digest.bodyweight(on: day), Formulas.bwAt(date: day, measurements: all), day
            )
            let lift = LiftEntry(
                id: "l\(index)", date: day, move: .bench, kg: 50, reps: 5, sets: 3
            )
            let old = Formulas.liftCalc(lift, measurements: all).map { calc in
                Formulas.moveLevel(move: calc.move, ratio: calc.ratio, sex: .male)
            }
            XCTAssertEqual(digest.level(of: lift), old, day)
        }
    }
}
