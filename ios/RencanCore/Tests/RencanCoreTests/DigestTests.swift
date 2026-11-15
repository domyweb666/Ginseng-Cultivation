import XCTest

@testable import RencanCore

// 畫面摘要（Digest）：境界頁、分析頁、小工具、Siri 顯示的數字都從這裡拿。
// 身高 174 的男性。體重 70.4、體脂 14.2% 是金丹中期（跟 FormulasTests 同一筆）。

private func weighing(_ kg: Double, bodyFat: Double, on date: String) -> MeasurementEntry {
    MeasurementEntry(id: date, date: date, weightKg: kg, bodyFatPercent: bodyFat)
}

private func lift(
    _ move: MoveKey, kg: Double, reps: Int, on date: String, id: String
) -> LiftEntry {
    LiftEntry(id: id, date: date, move: move, kg: kg, reps: reps, sets: 3)
}

/// 五筆修煉，分在四天；深蹲三筆、臥推一筆、引體向上一筆（跟 LiftTests 同一組）。
private func fiveLifts() -> [LiftEntry] {
    let first = lift(.squat, kg: 100, reps: 5, on: "2026-03-09", id: "a")
    let second = lift(.bench, kg: 60, reps: 5, on: "2026-03-09", id: "b")
    let third = lift(.squat, kg: 105, reps: 5, on: "2026-03-10", id: "c")
    let fourth = lift(.squat, kg: 110, reps: 1, on: "2026-03-01", id: "d")
    let fifth = lift(.pull, kg: 0, reps: 8, on: "2026-03-08", id: "e")
    return [first, second, third, fourth, fifth]
}

private func digest(
    _ measurements: [MeasurementEntry], _ lifts: [LiftEntry] = [], sex: Sex? = .male,
    heightCm: Double? = 174, today: String = "2026-03-11"
) throws -> Digest {
    try Digest(
        measurements: measurements, lifts: lifts, heightCm: heightCm, sex: sex, today: today
    )
}

final class DigestSteleTests: XCTestCase {
    func test境界碑的境界FFMI還差幾公斤與進度一次算好() throws {
        let result = try digest([weighing(70.4, bodyFat: 14.2, on: "2026-03-05")])
        let stele = try XCTUnwrap(result.stele)
        XCTAssertEqual(stele.standing.label, "金丹中期")
        XCTAssertEqual(stele.ffmi, 20.316852160126835, accuracy: 1e-9)
        XCTAssertEqual(stele.leanMassKg, 60.4032, accuracy: 1e-9)
        XCTAssertEqual(stele.gap?.nextLabel, "金丹後期")
        XCTAssertEqual(try XCTUnwrap(stele.gap).leanNeededKg, 0.5544984, accuracy: 1e-6)
        // 金丹中期從 20.0 到 20.5；20.3169 走了 63.37%
        XCTAssertEqual(stele.stagePercent, 63.3704, accuracy: 1e-3)
        XCTAssertEqual(stele.gate, .stable)
        XCTAssertTrue(stele.isStable)
    }

    func test境界碑用的是日期最新的那一筆量測() throws {
        let older = weighing(72, bodyFat: 18, on: "2026-01-05")
        let newer = weighing(70.4, bodyFat: 14.2, on: "2026-03-05")
        let result = try digest([newer, older])
        XCTAssertEqual(result.stele?.measurement.date, "2026-03-05")
    }

    func test體脂24的境界碑照樣有境界但標根基不穩還差4個百分點() throws {
        let result = try digest([weighing(80, bodyFat: 24, on: "2026-03-05")])
        let stele = try XCTUnwrap(result.stele)
        XCTAssertEqual(stele.standing.label, "金丹中期")
        XCTAssertEqual(stele.gate, .unstable(overBy: 4))
        XCTAssertFalse(stele.isStable)
        XCTAssertEqual(result.breakthroughs, [])
    }

    func test男性體脂19是根基浮動9是偏低15是穩固() {
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 19, sex: .male), .wavering)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 9, sex: .male), .low)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 15, sex: .male), .stable)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 20, sex: .male), .wavering)
    }

    func test女性體脂26是根基浮動16是偏低22是穩固28是不穩() {
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 26, sex: .female), .wavering)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 16, sex: .female), .low)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 22, sex: .female), .stable)
        XCTAssertEqual(Formulas.bodyFatGate(bodyFatPercent: 28, sex: .female), .unstable(overBy: 1))
    }

    func test還沒填身高或還沒選性別時沒有境界碑() throws {
        let measurements = [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")]
        XCTAssertNil(try digest(measurements, heightCm: nil).stele)
        XCTAssertNil(try digest(measurements, sex: nil).stele)
        XCTAssertEqual(try digest(measurements, sex: nil).sect.title, "雜役弟子")
    }

    func test還沒量過時沒有境界碑宗門是雜役弟子() throws {
        let result = try digest([])
        XCTAssertNil(result.stele)
        XCTAssertEqual(result.sect.title, "雜役弟子")
        XCTAssertEqual(result.ffmiHistory, [])
    }

    func testFFMI低於煉氣下限時進度條最少畫2() {
        let standing = Formulas.realmOf(ffmi: 15, sex: .male)
        XCTAssertEqual(Formulas.stageProgressPercent(ffmi: 15, standing: standing), 2)
    }

    func test渡劫後期的進度條是滿的() {
        let standing = Formulas.realmOf(ffmi: 26.8, sex: .male)
        XCTAssertEqual(Formulas.stageProgressPercent(ffmi: 26.8, standing: standing), 100)
    }

    func test女性的境界碑用女性門檻算進度與還差幾公斤() throws {
        // 身高 160、去脂 46 的女性是元嬰中期（FemaleTests 有算式）
        let measurement = MeasurementEntry(
            id: "a", date: "2026-03-05", weightKg: 60, bodyFatPercent: 23, leanMassKg: 46
        )
        let result = try digest([measurement], sex: .female, heightCm: 160)
        let stele = try XCTUnwrap(result.stele)
        XCTAssertEqual(stele.standing.label, "元嬰中期")
        XCTAssertEqual(stele.ffmi, 19.18875, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(stele.gap).leanNeededKg, 0.3496, accuracy: 1e-4)
        XCTAssertEqual(stele.gate, .stable)
    }

    func test突破紀錄帶著那次量測的FFMI而且走勢圖每筆量測一點() throws {
        let first = weighing(71, bodyFat: 18, on: "2026-02-05")
        let second = weighing(70.4, bodyFat: 14.2, on: "2026-03-05")
        let result = try digest([second, first])
        XCTAssertEqual(result.breakthroughs.map(\.label), ["金丹初期", "金丹中期"])
        XCTAssertEqual(result.breakthroughs[1].ffmi, 20.316852160126835, accuracy: 1e-9)
        XCTAssertEqual(result.ffmiHistory.map(\.date), ["2026-02-05", "2026-03-05"])
        XCTAssertEqual(result.ffmiHistory[0].ffmi, 19.595752939622145, accuracy: 1e-9)
    }

    func test日期壞掉時整份摘要丟錯誤不會安靜算錯() {
        let bad = lift(.squat, kg: 100, reps: 5, on: "2026/03/09", id: "x")
        XCTAssertThrowsError(try digest([], [bad])) { error in
            XCTAssertEqual(error as? RencanError, .invalidDate)
        }
    }
}

final class DigestMoveTests: XCTestCase {
    private let body = [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")]

    private func card(_ key: MoveKey, in result: Digest) throws -> MoveCard {
        try XCTUnwrap(result.moveCards.first { $0.move.key == key })
    }

    func test六門功法各一張卡照表的順序() throws {
        let result = try digest(body, fiveLifts())
        let keys: [MoveKey] = [.squat, .dead, .bench, .ohp, .row, .pull]
        XCTAssertEqual(result.moveCards.map(\.move.key), keys)
    }

    func test深蹲卡是比值最高那筆的等級與下一階還差幾公斤() throws {
        let squat = try card(.squat, in: try digest(body, fiveLifts()))
        XCTAssertEqual(squat.best?.lift.id, "c")
        XCTAssertEqual(squat.levelName, "圓滿")
        XCTAssertEqual(squat.nextLevelName, "化境")
        // 化境要 2.0 倍體重：2.0 × 70.4 − 122.5 = 18.3，無條件進位 19
        XCTAssertEqual(squat.kgToNextLevel, 19)
    }

    func test功法卡的走勢照日期排每筆一個估計1RM() throws {
        let squat = try card(.squat, in: try digest(body, fiveLifts()))
        XCTAssertEqual(squat.history.count, 3)
        XCTAssertEqual(squat.history[0], 110, accuracy: 1e-9)
        XCTAssertEqual(squat.history[1], 116.66666666666667, accuracy: 1e-9)
        XCTAssertEqual(squat.history[2], 122.50000000000001, accuracy: 1e-9)
    }

    func test差不到1公斤也寫再加1公斤() throws {
        // 臥推估計 1RM 70、體重 70.4：大成要 1.0 倍，還差 0.4，寫成 1
        let bench = try card(.bench, in: try digest(body, fiveLifts()))
        XCTAssertEqual(bench.levelName, "小成")
        XCTAssertEqual(bench.kgToNextLevel, 1)
    }

    func test沒記過的功法卡是未入門沒有最佳紀錄() throws {
        let dead = try card(.dead, in: try digest(body, fiveLifts()))
        XCTAssertFalse(dead.hasRecords)
        XCTAssertNil(dead.best)
        XCTAssertEqual(dead.levelName, "未入門")
        XCTAssertNil(dead.kgToNextLevel)
        XCTAssertEqual(dead.history, [])
    }

    func test有紀錄但沒量過體重的功法卡不算等級() throws {
        let squat = try card(.squat, in: try digest([], fiveLifts()))
        XCTAssertTrue(squat.hasRecords)
        XCTAssertNil(squat.best)
        XCTAssertEqual(squat.level, 0)
    }

    func test練到大成以上的功法有幾門() throws {
        XCTAssertEqual(try digest(body, fiveLifts()).accomplishedCount, 1)
    }

    func test這個月修煉幾天只算跟今天同一個月的() throws {
        XCTAssertEqual(try digest(body, fiveLifts()).monthCount, 4)
        XCTAssertEqual(try digest(body, fiveLifts(), today: "2026-04-02").monthCount, 0)
    }

    func test累計與本週天數跟公式算的一樣() throws {
        let result = try digest(body, fiveLifts())
        XCTAssertEqual(result.trainDays, 4)
        XCTAssertEqual(result.weekCount, 2)
    }

    func test每一筆修煉自己的等級() throws {
        let result = try digest(body, fiveLifts())
        XCTAssertEqual(result.level(of: fiveLifts()[0]), 4)
        XCTAssertEqual(result.level(of: fiveLifts()[1]), 2)
        XCTAssertNil(try digest([], fiveLifts()).level(of: fiveLifts()[0]))
    }

    func test記一筆的預覽體重72深蹲90公斤5下是大成再加3公斤升圓滿() throws {
        let squat = try XCTUnwrap(Tables.moves.first { $0.key == .squat })
        let found = Digest.preview(move: squat, kg: 90, reps: 5, bodyweightKg: 72, sex: .male)
        let preview = try XCTUnwrap(found)
        XCTAssertEqual(preview.estimatedOneRepMaxKg, 105, accuracy: 1e-9)
        XCTAssertEqual(preview.ratio, 1.4583333333333333, accuracy: 1e-9)
        XCTAssertEqual(preview.levelName, "大成")
        XCTAssertEqual(preview.nextLevelName, "圓滿")
        XCTAssertEqual(preview.kgToNextLevel, 3)
    }

    func test記一筆的預覽體重72引體向上徒手8下是小成再加5公斤升大成() throws {
        let pull = try XCTUnwrap(Tables.moves.first { $0.key == .pull })
        let found = Digest.preview(move: pull, kg: 0, reps: 8, bodyweightKg: 72, sex: .male)
        let preview = try XCTUnwrap(found)
        XCTAssertEqual(preview.estimatedOneRepMaxKg, 91.2, accuracy: 1e-9)
        XCTAssertEqual(preview.levelName, "小成")
        XCTAssertEqual(preview.kgToNextLevel, 5)
    }

    func test沒有體重時記一筆沒有預覽() throws {
        let squat = try XCTUnwrap(Tables.moves.first { $0.key == .squat })
        XCTAssertNil(Digest.preview(move: squat, kg: 90, reps: 5, bodyweightKg: 0, sex: .male))
    }

    func test離譜的重量不會讓還差幾公斤當掉() throws {
        let squat = try XCTUnwrap(Tables.moves.first { $0.key == .squat })
        let found = Digest.preview(move: squat, kg: 1e300, reps: 5, bodyweightKg: 72, sex: .male)
        XCTAssertNil(try XCTUnwrap(found).kgToNextLevel)
    }
}
