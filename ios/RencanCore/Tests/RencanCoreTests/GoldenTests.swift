import XCTest

@testable import RencanCore

/// 黃金集：同一份假資料，iOS 版算出來的要跟網頁版原版程式一樣（小數比到第 6 位）。
/// 宗門身分不在這裡比：2026-11-17 起 app 的宗門境界門檻跟網頁版不一樣，答案在 SectTests。
/// 假資料與答案在 Fixtures/web-export.json，由 .vibe/tools/golden_build.mjs 跑網頁版
/// index.html 的原版程式產生，不准手改。每一組在測什麼，看那個檔裡每組的 name。
final class GoldenTests: XCTestCase {
    private let tolerance = 1e-6

    func test體脂穩固門檻是百分之二十() {
        XCTAssertEqual(Tables.bodyFatStableThresholdPercent, 20)
    }

    // MARK: 十組假資料

    func test黃金集一共有10組假資料() throws {
        XCTAssertEqual(try loadFile().groups.count, 10)
    }

    func test黃金集第1組跟網頁版一樣() throws {
        try checkGroup(1)
    }

    func test黃金集第2組跟網頁版一樣() throws {
        try checkGroup(2)
    }

    func test黃金集第3組跟網頁版一樣() throws {
        try checkGroup(3)
    }

    func test黃金集第4組跟網頁版一樣() throws {
        try checkGroup(4)
    }

    func test黃金集第5組跟網頁版一樣() throws {
        try checkGroup(5)
    }

    func test黃金集第6組跟網頁版一樣() throws {
        try checkGroup(6)
    }

    func test黃金集第7組跟網頁版一樣() throws {
        try checkGroup(7)
    }

    func test黃金集第8組跟網頁版一樣() throws {
        try checkGroup(8)
    }

    func test黃金集第9組跟網頁版一樣() throws {
        try checkGroup(9)
    }

    func test黃金集第10組跟網頁版一樣() throws {
        try checkGroup(10)
    }

    // MARK: 四張對照表

    func test黃金集FFMI從15到28每0點1一格的境界跟網頁版一樣() throws {
        let ladder = try loadFile().ladder
        XCTAssertEqual(ladder.count, 131)
        for step in ladder {
            let note = "FFMI \(step.ffmi)"
            let standing = Formulas.realmOf(ffmi: step.ffmi)
            XCTAssertEqual(standing.label, step.label, note)
            XCTAssertEqual(standing.fromFFMI, step.fromFFMI, accuracy: tolerance, note)
            checkOptional(standing.nextFFMI, step.nextFFMI, note)
        }
    }

    func test黃金集天數寫成人話跟網頁版一樣() throws {
        let durations = try loadFile().durations
        XCTAssertEqual(durations.count, 21)
        for duration in durations {
            XCTAssertEqual(Formulas.durTxt(days: duration.days), duration.text)
        }
    }

    func test黃金集兩個日期差幾天跟網頁版一樣() throws {
        let gaps = try loadFile().dayGaps
        XCTAssertEqual(gaps.count, 6)
        for gap in gaps {
            let note = "\(gap.from) 到 \(gap.until)"
            XCTAssertEqual(try Formulas.daysBetween(gap.from, gap.until), gap.days, note)
        }
    }

    // MARK: 讀檔與比對

    private func loadFile() throws -> GoldenFile {
        let found = Bundle.module.url(
            forResource: "web-export", withExtension: "json", subdirectory: "Fixtures"
        )
        let url = try XCTUnwrap(found, "找不到黃金集檔案 Fixtures/web-export.json")
        return try JSONDecoder().decode(GoldenFile.self, from: Data(contentsOf: url))
    }

    private func checkGroup(_ number: Int) throws {
        let file = try loadFile()
        let found = file.groups.dropFirst(number - 1).first
        let group = try XCTUnwrap(found, "黃金集沒有第 \(number) 組")
        XCTAssertEqual(group.lifts.count, group.export.lift.count, "\(group.name)：有不認得的功法")
        checkStandings(group)
        try checkBreakthroughs(group)
        try checkCounts(group, today: file.today)
        try checkLifts(group)
    }

    private func checkStandings(_ group: GoldenGroup) {
        let sorted = Formulas.byDate(group.measurements)
        let answers = group.expected.measurements
        XCTAssertEqual(sorted.map(\.date), answers.map(\.date), "\(group.name)：量測順序")
        for (measurement, answer) in zip(sorted, answers) {
            let note = "\(group.name)：\(answer.date) 的量測"
            let lean = Formulas.leanOf(measurement)
            let ffmi = Formulas.ffmi(leanMassKg: lean, heightCm: group.heightCm)
            let standing = Formulas.realmOf(ffmi: ffmi)
            XCTAssertEqual(lean, answer.lean, accuracy: tolerance, note)
            XCTAssertEqual(ffmi, answer.ffmi, accuracy: tolerance, note)
            XCTAssertEqual(standing.label, answer.label, note)
            XCTAssertEqual(standing.realmIndex, answer.realmIndex, note)
            XCTAssertEqual(standing.stageIndex, answer.stageIndex, note)
            XCTAssertEqual(standing.fromFFMI, answer.fromFFMI, accuracy: tolerance, note)
            checkOptional(standing.nextFFMI, answer.nextFFMI, note)
            let gap = Formulas.nextStageGap(leanMassKg: lean, heightCm: group.heightCm)
            XCTAssertEqual(gap?.nextLabel, answer.nextLabel, note)
            checkOptional(gap?.leanNeededKg, answer.leanNeeded, note)
        }
    }

    private func checkBreakthroughs(_ group: GoldenGroup) throws {
        let note = "\(group.name)：突破紀錄"
        let records = try Formulas.breakthroughs(
            measurements: group.measurements, heightCm: group.heightCm
        )
        let answers = group.expected.breakthroughs
        XCTAssertEqual(records.map(\.date), answers.map(\.date), note)
        XCTAssertEqual(records.map(\.stageRank), answers.map(\.stageRank), note)
        XCTAssertEqual(records.map(\.label), answers.map(\.label), note)
        XCTAssertEqual(records.map(\.isFirst), answers.map(\.first), note)
        XCTAssertEqual(records.map(\.daysSincePrevious), answers.map(\.days), note)
    }

    private func checkCounts(_ group: GoldenGroup, today: String) throws {
        let note = "\(group.name)：天數與最高境界"
        let days = Formulas.trainDays(lifts: group.lifts)
        let week = try Formulas.weekCount(lifts: group.lifts, today: today)
        let top = try Formulas.realmMax(measurements: group.measurements, heightCm: group.heightCm)
        XCTAssertEqual(days, group.expected.trainDays, note)
        XCTAssertEqual(week, group.expected.weekCount, note)
        XCTAssertEqual(top, group.expected.realmMax, note)
    }

    private func checkLifts(_ group: GoldenGroup) throws {
        for (lift, answer) in zip(group.lifts, group.expected.lifts) {
            let note = "\(group.name)：\(lift.date) 的修煉"
            let found = Formulas.liftCalc(lift, measurements: group.measurements)
            checkCalc(try XCTUnwrap(found, note), answer, note)
        }
        let best = Formulas.bestByMove(lifts: group.lifts, measurements: group.measurements)
        XCTAssertEqual(best.count, group.expected.best.count, "\(group.name)：有紀錄的功法數")
        for answer in group.expected.best {
            let note = "\(group.name)：最佳紀錄 \(answer.move ?? "")"
            let key = try XCTUnwrap(MoveKey(rawValue: answer.move ?? ""), note)
            checkCalc(try XCTUnwrap(best[key], note), answer, note)
        }
    }

    private func checkCalc(_ calc: LiftCalc, _ answer: GoldenLiftAnswer, _ note: String) {
        XCTAssertEqual(calc.lift.id, answer.id, note)
        XCTAssertEqual(calc.estimatedOneRepMaxKg, answer.e1rm, accuracy: tolerance, note)
        XCTAssertEqual(calc.ratio, answer.ratio, accuracy: tolerance, note)
        XCTAssertEqual(calc.bodyweightKg, answer.bodyweight, accuracy: tolerance, note)
        XCTAssertEqual(Formulas.moveLevel(move: calc.move, ratio: calc.ratio), answer.level, note)
    }

    /// 兩個可能沒有的小數：要嘛都沒有，要嘛差不到容許值。
    private func checkOptional(_ actual: Double?, _ expected: Double?, _ note: String) {
        guard let actual, let expected else {
            XCTAssertEqual(actual, expected, note)
            return
        }
        XCTAssertEqual(actual, expected, accuracy: tolerance, note)
    }
}
