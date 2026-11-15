import XCTest

@testable import RencanCore

// 女性版（片 B5）。網頁版沒有女性表，沒有標準答案可以對，所以測試把算式寫出來：
//   k =（22 − 14.6）÷（25 − 16.7）≈ 0.8916
//   男性等值 = 16.7 +（女性 FFMI − 14.6）÷ k，再照原本的男性表判境界
// 規則與出處在 .vibe/女性版規則.md。測試用的女性身高一律 160。

private let scale = (22 - 14.6) / (25 - 16.7)
private let heightCm: Double = 160

private func weighing(_ kg: Double, bodyFat: Double) -> MeasurementEntry {
    MeasurementEntry(id: "a", date: "2026-03-01", weightKg: kg, bodyFatPercent: bodyFat)
}

/// 境界：女性 FFMI 換成男性等值再查表。
final class FemaleRealmTests: XCTestCase {
    private func label(_ ffmi: Double) -> String {
        Formulas.realmOf(ffmi: ffmi, sex: .female).label
    }

    func test女性身高160去脂46公斤的男性等值FFMI是21點85() {
        // FFMI = 46 ÷ 1.6² + 6.1 ×（1.8 − 1.6）= 19.18875
        let ffmi = Formulas.ffmi(leanMassKg: 46, heightCm: heightCm)
        XCTAssertEqual(ffmi, 46 / (1.6 * 1.6) + 6.1 * (1.8 - 1.6), accuracy: 1e-9)
        // 男性等值 = 16.7 +（19.18875 − 14.6）÷ k = 21.8468，落在元嬰 21–22.5 的中期
        let equivalent = Sex.female.maleEquivalentFFMI(ffmi)
        XCTAssertEqual(equivalent, 16.7 + (ffmi - 14.6) / scale, accuracy: 1e-9)
        XCTAssertEqual(equivalent, 21.8468, accuracy: 1e-4)
        XCTAssertEqual(label(ffmi), "元嬰中期")
    }

    func test男性的FFMI不換算() {
        XCTAssertEqual(Sex.male.maleEquivalentFFMI(20.32), 20.32)
        XCTAssertEqual(Sex.male.ownFFMI(fromMaleEquivalent: 20.5), 20.5)
    }

    func test女性換成男性等值再換回來是同一個數字() {
        let equivalent = Sex.female.maleEquivalentFFMI(17.8)
        XCTAssertEqual(Sex.female.ownFFMI(fromMaleEquivalent: equivalent), 17.8, accuracy: 1e-9)
    }

    // MARK: 七個境界各一條

    func test女性FFMI15是煉氣() {
        XCTAssertEqual(label(15), "煉氣中期")
    }

    func test女性FFMI16點5是築基() {
        XCTAssertEqual(label(16.5), "築基中期")
    }

    func test女性FFMI17點8是金丹() {
        XCTAssertEqual(label(17.8), "金丹中期")
    }

    func test女性FFMI19是元嬰() {
        XCTAssertEqual(label(19), "元嬰中期")
    }

    func test女性FFMI20點5是化神() {
        XCTAssertEqual(label(20.5), "化神中期")
    }

    func test女性FFMI21點8是大乘() {
        XCTAssertEqual(label(21.8), "大乘中期")
    }

    func test女性FFMI23是渡劫() {
        XCTAssertEqual(label(23), "渡劫中期")
    }

    // MARK: 邊界各一條（畫面上寫的下限）

    func test女性FFMI14點5剛好是煉氣() {
        XCTAssertEqual(label(14.5), "煉氣初期")
    }

    func test女性FFMI15點8剛好是築基() {
        XCTAssertEqual(label(15.8), "築基初期")
    }

    func test女性FFMI17點1剛好是金丹而17還在築基後期() {
        XCTAssertEqual(label(17.1), "金丹初期")
        XCTAssertEqual(label(17.0), "築基後期")
    }

    func test女性FFMI18點5剛好是元嬰() {
        XCTAssertEqual(label(18.5), "元嬰初期")
    }

    func test女性FFMI19點8剛好是化神() {
        XCTAssertEqual(label(19.8), "化神初期")
    }

    func test女性FFMI21點2剛好是大乘() {
        XCTAssertEqual(label(21.2), "大乘初期")
    }

    func test女性FFMI22點5剛好是渡劫() {
        XCTAssertEqual(label(22.5), "渡劫初期")
    }

    func test女性畫面上寫的境界門檻照規則檔那張表() {
        let expected = [14.5, 15.8, 17.1, 18.5, 19.8, 21.2, 22.5, 23.8]
        let bounds = Sex.female.displayedRealmBounds()
        XCTAssertEqual(bounds.count, expected.count)
        for (bound, answer) in zip(bounds, expected) {
            XCTAssertEqual(bound, answer, accuracy: 1e-9)
        }
    }

    func test男性畫面上寫的境界門檻就是原本那張表() {
        let expected = [16.5, 18, 19.5, 21, 22.5, 24, 25.5, 27]
        XCTAssertEqual(Sex.male.displayedRealmBounds(), expected)
    }

    func test女性FFMI達到畫面上寫的門檻就一定在那個境界() {
        let lowers = Sex.female.displayedRealmBounds().dropLast()
        for (index, bound) in lowers.enumerated() {
            let standing = Formulas.realmOf(ffmi: bound, sex: .female)
            XCTAssertEqual(standing.realmIndex, index, "門檻 \(bound)")
            XCTAssertEqual(standing.stageIndex, 0, "門檻 \(bound)")
        }
    }

    func test女性每一期的寬度是0點5乘k() throws {
        // 男性每期 0.5；女性 0.5 × k ≈ 0.4458
        let standing = Formulas.realmOf(ffmi: 17.8, sex: .female)
        let next = try XCTUnwrap(standing.nextFFMI)
        XCTAssertEqual(next - standing.fromFFMI, 0.5 * scale, accuracy: 1e-9)
    }

    func test女性還差幾公斤先算男性等值的門檻再換回女性() throws {
        // 去脂 46、身高 160 是元嬰中期；下一期（元嬰後期）的男性等值門檻是 22。
        // 換回女性 FFMI = 14.6 +（22 − 16.7）× k = 19.3253
        // 目標去脂體重 = leanFor(19.3253, 160) = 46.3496，減掉現在的 46，還差 0.3496
        let found = Formulas.nextStageGap(leanMassKg: 46, heightCm: heightCm, sex: .female)
        let gap = try XCTUnwrap(found)
        let femaleThreshold = 14.6 + (22 - 16.7) * scale
        let target = Formulas.leanFor(ffmi: femaleThreshold, heightCm: heightCm)
        XCTAssertEqual(gap.nextLabel, "元嬰後期")
        XCTAssertEqual(gap.leanNeededKg, target - 46, accuracy: 1e-9)
        XCTAssertEqual(gap.leanNeededKg, 0.3496, accuracy: 1e-4)
    }
}

/// 體脂門檻與功法門檻。
final class FemaleRulesTests: XCTestCase {
    private func judge(_ new: MeasurementEntry, sex: Sex) throws -> MeasurementJudgement {
        try Judgement.measurementOutcome(
            new: new, before: [], lifts: [], heightCm: heightCm, sex: sex
        )
    }

    private func move(_ key: MoveKey) throws -> Move {
        try XCTUnwrap(Tables.moves.first { $0.key == key })
    }

    /// 女性門檻跟規則檔寫的一樣，而且等於男性門檻乘上係數。
    private func checkThresholds(_ key: MoveKey, _ expected: [Double], factor: Double) throws {
        let found = try move(key)
        XCTAssertEqual(found.thresholds(for: .female), expected)
        for (female, male) in zip(expected, found.thresholds(for: .male)) {
            XCTAssertEqual(female, male * factor, accuracy: 1e-9)
        }
    }

    // MARK: 根基不穩

    func test女性體脂26穩() throws {
        let result = try judge(weighing(55, bodyFat: 26), sex: .female)
        XCTAssertEqual(result.outcome, .enteredPath)
        XCTAssertEqual(result.standing.label, "金丹初期")
    }

    func test女性體脂28根基不穩() throws {
        let result = try judge(weighing(55, bodyFat: 28), sex: .female)
        XCTAssertEqual(result.outcome, .unstable)
        XCTAssertEqual(result.standing.label, "築基後期")
    }

    func test女性體脂剛好27不算超過() throws {
        let result = try judge(weighing(55, bodyFat: 27), sex: .female)
        XCTAssertEqual(result.outcome, .enteredPath)
    }

    func test同樣體脂26男性是根基不穩() throws {
        let result = try judge(weighing(55, bodyFat: 26), sex: .male)
        XCTAssertEqual(result.outcome, .unstable)
    }

    func test女性顯示的FFMI是她真實的FFMI不換算() throws {
        // 55 公斤、體脂 26%：去脂 40.7，FFMI = 40.7 ÷ 1.6² + 6.1 × 0.2 = 17.1184
        let result = try judge(weighing(55, bodyFat: 26), sex: .female)
        XCTAssertEqual(result.ffmi, 40.7 / (1.6 * 1.6) + 6.1 * 0.2, accuracy: 1e-9)
    }

    func test女性的突破紀錄採計體脂27以下的量測男性不採計() throws {
        let measurements = [weighing(56, bodyFat: 25)]
        let female = try Formulas.breakthroughs(
            measurements: measurements, heightCm: heightCm, sex: .female
        )
        let male = try Formulas.breakthroughs(
            measurements: measurements, heightCm: heightCm, sex: .male
        )
        XCTAssertEqual(female.map(\.label), ["金丹中期"])
        XCTAssertEqual(male, [])
    }

    // MARK: 六門功法

    func test女性坐馬樁深蹲的門檻是男性的七成() throws {
        try checkThresholds(.squat, [0.525, 0.7, 0.875, 1.05, 1.4], factor: 0.7)
    }

    func test女性拔山式硬舉的門檻是男性的七成() throws {
        try checkThresholds(.dead, [0.7, 0.875, 1.05, 1.4, 1.75], factor: 0.7)
    }

    func test女性推山掌臥推的門檻是男性的六成() throws {
        try checkThresholds(.bench, [0.3, 0.45, 0.6, 0.75, 0.9], factor: 0.6)
    }

    func test女性托天式肩推的門檻是男性的六成() throws {
        try checkThresholds(.ohp, [0.21, 0.3, 0.39, 0.48, 0.6], factor: 0.6)
    }

    func test女性挽弓式划船的門檻是男性的六成() throws {
        try checkThresholds(.row, [0.3, 0.45, 0.6, 0.75, 0.9], factor: 0.6)
    }

    func test女性攀雲梯引體向上的門檻另訂不照乘() throws {
        let pull = try move(.pull)
        XCTAssertEqual(pull.thresholds(for: .female), [1.0, 1.1, 1.2, 1.33, 1.5])
    }

    func test女性自重做一下引體向上是入門男性還沒入門() throws {
        let lift = LiftEntry(id: "p", date: "2026-03-02", move: .pull, kg: 0, reps: 1, sets: 1)
        let found = Formulas.liftCalc(lift, measurements: [weighing(55, bodyFat: 26)])
        let calc = try XCTUnwrap(found)
        // 徒手做一下：估計 1RM 就是體重，比值剛好 1.0
        XCTAssertEqual(calc.ratio, 1.0)
        XCTAssertEqual(Formulas.moveLevel(move: calc.move, ratio: calc.ratio, sex: .female), 1)
        XCTAssertEqual(Formulas.moveLevel(move: calc.move, ratio: calc.ratio, sex: .male), 0)
    }

    func test女性臥推到體重的0點6倍是大成男性只算入門() throws {
        let bench = try move(.bench)
        XCTAssertEqual(Formulas.moveLevel(move: bench, ratio: 0.6, sex: .female), 3)
        XCTAssertEqual(Formulas.moveLevel(move: bench, ratio: 0.6, sex: .male), 1)
    }

    func test男性的功法門檻沒被女性版動到() {
        for move in Tables.moves {
            XCTAssertEqual(move.thresholds(for: .male), move.thresholds)
        }
    }

    func test女性記修煉的功法突破用女性門檻() throws {
        // 體重 55：臥推 26 公斤 5 下比值 0.55（女性小成），29.5 公斤 5 下比值 0.63（女性大成）
        let before = LiftEntry(
            id: "a", date: "2026-03-02", move: .bench, kg: 26, reps: 5, sets: 3, bodyweightKg: 55
        )
        let new = LiftEntry(
            id: "b", date: "2026-03-09", move: .bench, kg: 29.5, reps: 5, sets: 3,
            bodyweightKg: 55
        )
        let female = try Judgement.liftOutcome(
            new: new, before: [before], measurements: [], heightCm: heightCm, sex: .female
        )
        let male = try Judgement.liftOutcome(
            new: new, before: [before], measurements: [], heightCm: heightCm, sex: .male
        )
        XCTAssertEqual(female.outcome, .levelUp)
        XCTAssertEqual(female.level, 3)
        XCTAssertEqual(male.outcome, .personalBest)
        XCTAssertEqual(male.level, 1)
    }
}
