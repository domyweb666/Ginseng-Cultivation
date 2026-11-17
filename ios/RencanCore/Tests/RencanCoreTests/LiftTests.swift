import XCTest

@testable import RencanCore

/// 功法等級與修煉天數。答案都是拿網頁版 index.html 的原版程式算出來的。
final class LiftTests: XCTestCase {
    private func weighing(_ kg: Double, on date: String) -> MeasurementEntry {
        MeasurementEntry(id: date, date: date, weightKg: kg, bodyFatPercent: 15)
    }

    /// 一筆體重 70 公斤的量測，日期早於所有測試用的修煉。
    private func weighing70() -> [MeasurementEntry] {
        [weighing(70, on: "2026-01-01")]
    }

    private func lift(
        _ move: MoveKey, kg: Double, reps: Int, date: String = "2026-03-09", id: String = "x"
    ) -> LiftEntry {
        LiftEntry(id: id, date: date, move: move, kg: kg, reps: reps, sets: 3)
    }

    /// 體重 70 公斤時，這一組算出來是哪一階。
    private func levelName(_ move: MoveKey, kg: Double, reps: Int) throws -> String {
        let entry = lift(move, kg: kg, reps: reps)
        let calc = try XCTUnwrap(Formulas.liftCalc(entry, measurements: weighing70()))
        return Tables.levelNames[Formulas.moveLevel(move: calc.move, ratio: calc.ratio)]
    }

    /// 五筆修煉，分在四天；深蹲三筆、臥推一筆、引體向上一筆。
    private func fiveLifts() -> [LiftEntry] {
        let first = lift(.squat, kg: 100, reps: 5, date: "2026-03-09", id: "a")
        let second = lift(.bench, kg: 60, reps: 5, date: "2026-03-09", id: "b")
        let third = lift(.squat, kg: 105, reps: 5, date: "2026-03-10", id: "c")
        let fourth = lift(.squat, kg: 110, reps: 1, date: "2026-03-01", id: "d")
        let fifth = lift(.pull, kg: 0, reps: 8, date: "2026-03-08", id: "e")
        return [first, second, third, fourth, fifth]
    }

    private func weighing70Point4() -> [MeasurementEntry] {
        [weighing(70.4, on: "2026-03-05")]
    }

    // MARK: 六門功法

    func test體重70深蹲100公斤5下是坐馬樁圓滿() throws {
        XCTAssertEqual(try levelName(.squat, kg: 100, reps: 5), "圓滿")
    }

    func test體重70硬舉120公斤3下是拔山式大成() throws {
        XCTAssertEqual(try levelName(.dead, kg: 120, reps: 3), "大成")
    }

    func test體重70臥推60公斤8下是推山掌大成() throws {
        XCTAssertEqual(try levelName(.bench, kg: 60, reps: 8), "大成")
    }

    func test體重70肩推30公斤5下是托天式小成() throws {
        XCTAssertEqual(try levelName(.ohp, kg: 30, reps: 5), "小成")
    }

    func test體重70划船70公斤1下是挽弓式大成() throws {
        XCTAssertEqual(try levelName(.row, kg: 70, reps: 1), "大成")
    }

    func test體重70引體向上徒手8下是攀雲梯小成() throws {
        XCTAssertEqual(try levelName(.pull, kg: 0, reps: 8), "小成")
    }

    func test體重70引體向上加重10公斤5下是攀雲梯大成() throws {
        XCTAssertEqual(try levelName(.pull, kg: 10, reps: 5), "大成")
    }

    func test體重70深蹲40公斤1下還沒入門() throws {
        XCTAssertEqual(try levelName(.squat, kg: 40, reps: 1), "未入門")
    }

    func test深蹲100公斤5下的估計1RM是116點67比值1點67() throws {
        let entry = lift(.squat, kg: 100, reps: 5)
        let calc = try XCTUnwrap(Formulas.liftCalc(entry, measurements: weighing70()))
        XCTAssertEqual(calc.estimatedOneRepMaxKg, 116.66666666666667, accuracy: 1e-9)
        XCTAssertEqual(calc.ratio, 1.6666666666666667, accuracy: 1e-9)
        XCTAssertEqual(calc.bodyweightKg, 70)
    }

    func test引體向上的負重是體重加上加重() throws {
        let entry = lift(.pull, kg: 10, reps: 5)
        let calc = try XCTUnwrap(Formulas.liftCalc(entry, measurements: weighing70()))
        XCTAssertEqual(calc.estimatedOneRepMaxKg, 93.33333333333334, accuracy: 1e-9)
        XCTAssertEqual(calc.ratio, 1.3333333333333335, accuracy: 1e-9)
    }

    func test只做一下的估計1RM就是那個重量() {
        XCTAssertEqual(Formulas.e1rm(loadKg: 110, reps: 1), 110)
    }

    // MARK: 體重從哪來

    func test沒有任何量測時功法不算等級() {
        let entry = lift(.squat, kg: 100, reps: 5)
        XCTAssertNil(Formulas.liftCalc(entry, measurements: []))
        XCTAssertTrue(Formulas.bestByMove(lifts: [entry], measurements: []).isEmpty)
    }

    func test記修煉時有體重快照就用快照() throws {
        let entry = LiftEntry(
            id: "s", date: "2026-03-09", move: .squat, kg: 100, reps: 5, sets: 3,
            bodyweightKg: 80
        )
        let calc = try XCTUnwrap(Formulas.liftCalc(entry, measurements: weighing70()))
        XCTAssertEqual(calc.bodyweightKg, 80)
        XCTAssertEqual(calc.ratio, 1.4583333333333335, accuracy: 1e-9)
    }

    func test體重用當天以前最近的一筆量測() {
        let older = weighing(72, on: "2026-01-05")
        let newer = weighing(70.4, on: "2026-03-05")
        let future = weighing(75, on: "2026-06-05")
        let all = [future, older, newer]
        XCTAssertEqual(Formulas.bwAt(date: "2026-03-09", measurements: all), 70.4)
    }

    func test量測都在那天之後就用最新的一筆() {
        let newer = weighing(70.4, on: "2026-03-05")
        let future = weighing(75, on: "2026-06-05")
        XCTAssertEqual(Formulas.bwAt(date: "2025-01-01", measurements: [future, newer]), 75)
    }

    // MARK: 最佳紀錄與天數

    func test每門功法留比值最高的那一筆() throws {
        let best = Formulas.bestByMove(lifts: fiveLifts(), measurements: weighing70Point4())
        XCTAssertEqual(best.count, 3)
        let squat = try XCTUnwrap(best[.squat])
        XCTAssertEqual(squat.lift.id, "c")
        XCTAssertEqual(squat.estimatedOneRepMaxKg, 122.50000000000001, accuracy: 1e-9)
        XCTAssertEqual(squat.ratio, 1.7400568181818183, accuracy: 1e-9)
        let bench = try XCTUnwrap(best[.bench])
        XCTAssertEqual(bench.ratio, 0.9943181818181818, accuracy: 1e-9)
        let pull = try XCTUnwrap(best[.pull])
        XCTAssertEqual(pull.estimatedOneRepMaxKg, 89.17333333333333, accuracy: 1e-9)
        XCTAssertEqual(pull.ratio, 1.2666666666666666, accuracy: 1e-9)
    }

    func test同一天記兩筆只算一天修煉() {
        XCTAssertEqual(Formulas.trainDays(lifts: fiveLifts()), 4)
    }

    func test星期三看本週修煉天數從星期一算起() throws {
        XCTAssertEqual(try Formulas.weekCount(lifts: fiveLifts(), today: "2026-03-11"), 2)
    }

    func test星期一當天本週從今天算起() throws {
        XCTAssertEqual(try Formulas.weekCount(lifts: fiveLifts(), today: "2026-03-16"), 0)
    }

    func test星期日還算在星期一開始的那一週() throws {
        XCTAssertEqual(try Formulas.weekCount(lifts: fiveLifts(), today: "2026-03-15"), 2)
        XCTAssertEqual(try Formulas.weekCount(lifts: fiveLifts(), today: "2026-03-08"), 3)
    }

    // MARK: 雷達圖分數（網頁版沒有這個，答案是照門檻手算的）

    private func tableMove(_ key: MoveKey) throws -> Move {
        try XCTUnwrap(Tables.moves.first { $0.key == key })
    }

    func test雷達分數在兩個門檻中間是幾點五() throws {
        // 男性深蹲：入門 0.75、小成 1.0，中間 0.875 是 1.5 分
        let squat = try tableMove(.squat)
        XCTAssertEqual(
            Formulas.moveScore(move: squat, ratio: 0.875, sex: .male), 1.5, accuracy: 1e-9
        )
        // 大成 1.5、圓滿 2.0，中間 1.75 是 4.5 分
        XCTAssertEqual(
            Formulas.moveScore(move: squat, ratio: 1.75, sex: .male), 4.5, accuracy: 1e-9
        )
    }

    func test雷達分數未入門從零起算() throws {
        let squat = try tableMove(.squat)
        XCTAssertEqual(
            Formulas.moveScore(move: squat, ratio: 0.375, sex: .male), 0.5, accuracy: 1e-9
        )
        XCTAssertEqual(Formulas.moveScore(move: squat, ratio: 0, sex: .male), 0)
    }

    func test雷達分數到化境封頂五分() throws {
        let squat = try tableMove(.squat)
        XCTAssertEqual(Formulas.moveScore(move: squat, ratio: 2.0, sex: .male), 5)
        XCTAssertEqual(Formulas.moveScore(move: squat, ratio: 3.2, sex: .male), 5)
    }

    func test雷達分數女性用女性門檻() throws {
        // 女性臥推：入門 0.3，0.15 是 0.5 分；剛好 0.45（小成）是 2 分
        let bench = try tableMove(.bench)
        XCTAssertEqual(
            Formulas.moveScore(move: bench, ratio: 0.15, sex: .female), 0.5, accuracy: 1e-9
        )
        XCTAssertEqual(
            Formulas.moveScore(move: bench, ratio: 0.45, sex: .female), 2, accuracy: 1e-9
        )
    }

    func test雷達分數的整數部分就是等級() throws {
        for move in Tables.moves {
            for ratio in stride(from: 0.05, through: 3.0, by: 0.05) {
                let score = Formulas.moveScore(move: move, ratio: ratio, sex: .male)
                let level = Formulas.moveLevel(move: move, ratio: ratio, sex: .male)
                XCTAssertEqual(Int(score.rounded(.down)), level, "\(move.name) 比值 \(ratio)")
            }
        }
    }
}
