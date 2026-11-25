import XCTest

@testable import RencanCore

// Siri 回的那一句話（組塊 H，PRD S17、S18）。每一種情況一條，整句比對。
// 記修煉：身高 174 的男性，體重 70 公斤、體脂 18%（跟 JudgementTests 同一筆）。
// 問境界：體重 70.4、體脂 14.2% 是金丹中期（跟 DigestTests 同一筆）。

private let heightCm: Double = 174

private func weighing(
    _ kg: Double, bodyFat: Double, on date: String, leanMassKg: Double? = nil
) -> MeasurementEntry {
    MeasurementEntry(
        id: date, date: date, weightKg: kg, bodyFatPercent: bodyFat, leanMassKg: leanMassKg
    )
}

private func lift(
    _ move: MoveKey, kg: Double, reps: Int = 5, sets: Int = 1, on date: String = "2026-01-20"
) -> LiftEntry {
    LiftEntry(id: date + move.rawValue, date: date, move: move, kg: kg, reps: reps, sets: sets)
}

/// 一月份連續幾天，每天深蹲 60 公斤 5 下（體重 70 時是小成）。
private func squatDays(_ count: Int) -> [LiftEntry] {
    (1...count).map { day in
        lift(.squat, kg: 60, on: day < 10 ? "2026-01-0\(day)" : "2026-01-\(day)")
    }
}

private struct OtherError: Error {}

/// 記修煉（片 H1）。判定用 Judgement 真的算一次，跟 app 存檔時走同一條路。
final class SiriLogReplyTests: XCTestCase {
    private let body = [weighing(70, bodyFat: 18, on: "2025-12-01")]

    private func reply(
        _ new: LiftEntry, before: [LiftEntry], measurements: [MeasurementEntry]
    ) throws -> String {
        let judgement = try Judgement.liftOutcome(
            new: new, before: before, measurements: measurements, heightCm: heightCm, sex: .male
        )
        let move = try XCTUnwrap(Tables.moves.first { $0.key == new.move })
        return SiriReply.logged(judgement, move: move, kg: new.kg, reps: new.reps, sets: new.sets)
    }

    func test修煉加1回記了什麼估計1RM與這一組的等級() throws {
        let text = try reply(lift(.squat, kg: 60), before: squatDays(3), measurements: body)
        XCTAssertEqual(text, "已記下坐馬樁 60 公斤 5 下，修煉 +1。估計 1RM 70 公斤，這一組算小成。")
    }

    func test講了3組回覆裡帶組數沒講就不提() throws {
        let three = lift(.squat, kg: 60, sets: 3)
        let text = try reply(three, before: squatDays(3), measurements: body)
        XCTAssertEqual(
            text, "已記下坐馬樁 60 公斤 5 下 3 組，修煉 +1。估計 1RM 70 公斤，這一組算小成。"
        )
    }

    func test功法突破回升到哪一階() throws {
        let text = try reply(lift(.squat, kg: 80), before: squatDays(3), measurements: body)
        XCTAssertEqual(text, "已記下坐馬樁 80 公斤 5 下，功法突破。估計 1RM 93 公斤，升到大成。")
    }

    func test功法精進而且重量有小數照樣唸出來() throws {
        let text = try reply(lift(.squat, kg: 62.5), before: squatDays(3), measurements: body)
        XCTAssertEqual(
            text, "已記下坐馬樁 62.5 公斤 5 下，功法精進。估計 1RM 73 公斤，這一組算小成。"
        )
    }

    func test這門功法第一次記回開練了() throws {
        let text = try reply(lift(.bench, kg: 40), before: squatDays(3), measurements: body)
        XCTAssertEqual(
            text, "已記下推山掌 40 公斤 5 下，這門功法開練了。估計 1RM 47 公斤，這一組算入門。"
        )
    }

    func test宗門晉升回新的身分() throws {
        let text = try reply(lift(.squat, kg: 60), before: squatDays(7), measurements: body)
        XCTAssertEqual(
            text, "已記下坐馬樁 60 公斤 5 下，宗門晉升為外門弟子。估計 1RM 70 公斤，這一組算小成。"
        )
    }

    func test宗門晉升同時突破也講升到哪一階() throws {
        let text = try reply(lift(.squat, kg: 80), before: squatDays(7), measurements: body)
        XCTAssertEqual(
            text, "已記下坐馬樁 80 公斤 5 下，宗門晉升為外門弟子。估計 1RM 93 公斤，升到大成。"
        )
    }

    func test沒量過體重只回修煉加1與一句提醒() throws {
        let text = try reply(lift(.squat, kg: 60), before: squatDays(3), measurements: [])
        XCTAssertEqual(text, "已記下坐馬樁 60 公斤 5 下，修煉 +1。量過體重才算得出等級。")
    }

    func test第一筆修煉回引氣入體() throws {
        let text = try reply(lift(.squat, kg: 60), before: [], measurements: body)
        XCTAssertEqual(text, "已記下坐馬樁 60 公斤 5 下，引氣入體。估計 1RM 70 公斤，這一組算小成。")
    }

    func test沒量過體重的第一筆回引氣入體與一句提醒() throws {
        let text = try reply(lift(.squat, kg: 60), before: [], measurements: [])
        XCTAssertEqual(text, "已記下坐馬樁 60 公斤 5 下，引氣入體。量過體重才算得出等級。")
    }

    func test隔21天回出關() throws {
        let back = lift(.squat, kg: 60, on: "2026-01-24")
        let text = try reply(back, before: squatDays(3), measurements: body)
        XCTAssertEqual(text, "已記下坐馬樁 60 公斤 5 下，出關。估計 1RM 70 公斤，這一組算小成。")
    }

    func test出關同時功法突破只講突破() throws {
        let back = lift(.squat, kg: 80, on: "2026-01-24")
        let text = try reply(back, before: squatDays(3), measurements: body)
        XCTAssertEqual(text, "已記下坐馬樁 80 公斤 5 下，功法突破。估計 1RM 93 公斤，升到大成。")
    }

    func test沒量過體重破紀錄回功法精進與一句提醒() throws {
        let text = try reply(lift(.squat, kg: 62.5), before: squatDays(3), measurements: [])
        XCTAssertEqual(text, "已記下坐馬樁 62.5 公斤 5 下，功法精進。量過體重才算得出等級。")
    }

    func test引體向上徒手寫自重回幾倍體重() throws {
        let pull = lift(.pull, kg: 0, reps: 8)
        let text = try reply(pull, before: squatDays(3), measurements: body)
        XCTAssertEqual(
            text, "已記下攀雲梯自重 8 下，這門功法開練了。相當於 1.27 倍體重的拉力，這一組算小成。"
        )
    }

    func test引體向上加重寫自重加幾公斤() throws {
        let pull = lift(.pull, kg: 5, reps: 8)
        let text = try reply(pull, before: squatDays(3), measurements: body)
        let tail = "相當於 1.36 倍體重的拉力，這一組算大成。"
        XCTAssertEqual(text, "已記下攀雲梯自重加 5 公斤 8 下，這門功法開練了。" + tail)
    }

    func test還沒到入門門檻回這一組算未入門() throws {
        let text = try reply(lift(.squat, kg: 40), before: squatDays(3), measurements: body)
        XCTAssertEqual(
            text, "已記下坐馬樁 40 公斤 5 下，修煉 +1。估計 1RM 47 公斤，這一組算未入門。"
        )
    }

    func test次數超出範圍回沒記下與原因不說已記下() {
        let text = SiriReply.logFailure(RencanError.repsOutOfRange)
        XCTAssertEqual(text, "這筆沒記下：次數超出範圍。")
        XCTAssertFalse(text.contains("已記下"))
    }

    func test存檔失敗或不認得的錯誤回沒存成功() {
        let expected = "這筆沒記下：沒存成功，請再試一次。"
        XCTAssertEqual(SiriReply.logFailure(RencanError.saveFailed), expected)
        XCTAssertEqual(SiriReply.logFailure(OtherError()), expected)
    }

    func test記修煉時還沒填身高性別請他先打開app() {
        let text = SiriReply.logFailure(RencanError.profileMissing)
        XCTAssertEqual(text, "還沒填身高和性別，先打開人蔘修煉填一下。")
    }

    func test每一種錯誤的回覆都不夾阿拉伯數字() {
        let digits: ClosedRange<Character> = "0"..."9"
        for error in RencanError.allCases {
            let text = SiriReply.logFailure(error)
            XCTAssertFalse(text.contains(where: { digits.contains($0) }), text)
        }
    }
}

/// 問境界（片 H2）。數字從 Digest 拿，跟境界碑同一份。
final class SiriRealmReplyTests: XCTestCase {
    private func reply(
        _ measurements: [MeasurementEntry], sex: Sex? = .male, heightCm: Double? = 174
    ) throws -> String {
        let digest = try Digest(
            measurements: measurements, lifts: [], heightCm: heightCm, sex: sex,
            today: "2026-03-11"
        )
        return SiriReply.realmStatus(digest)
    }

    func test金丹中期回境界FFMI與還差幾公斤肌肉() throws {
        let text = try reply([weighing(70.4, bodyFat: 14.2, on: "2026-03-05")])
        XCTAssertEqual(text, "金丹中期，FFMI 20.33，距金丹後期還差 0.5 公斤肌肉。")
    }

    func test下一期跨大境界時講新境界的名字() throws {
        let text = try reply([weighing(73, bodyFat: 15, on: "2026-03-05")])
        XCTAssertEqual(text, "金丹後期，FFMI 20.87，距元嬰初期還差 0.4 公斤肌肉。")
    }

    func testFFMI照最新一筆而境界不降差距看平均() throws {
        // 前一筆是金丹後期；兩次去脂平均 61.2266，到元嬰初期的 62.4351 還差 1.2
        let older = weighing(73, bodyFat: 15, on: "2026-01-05")
        let newer = weighing(70.4, bodyFat: 14.2, on: "2026-03-05")
        let text = try reply([newer, older])
        XCTAssertEqual(text, "金丹後期，FFMI 20.33，距元嬰初期還差 1.2 公斤肌肉。")
    }

    func test還沒量過回尚未入道() throws {
        XCTAssertEqual(try reply([]), "尚未入道，先量一次體組成。")
    }

    func test還沒填身高或性別請他先打開app() throws {
        let measurements = [weighing(70.4, bodyFat: 14.2, on: "2026-03-05")]
        let expected = "還沒填身高和性別，先打開人蔘修煉填一下。"
        XCTAssertEqual(try reply(measurements, heightCm: nil), expected)
        XCTAssertEqual(try reply(measurements, sex: nil), expected)
    }

    func test體脂24回根基不穩與要降到20以下() throws {
        let text = try reply([weighing(80, bodyFat: 24, on: "2026-03-05")])
        XCTAssertEqual(text, "金丹中期，FFMI 20.46。根基不穩，體脂降到 20% 以下境界才生效。")
    }

    func test突破過的人體脂超標回才能再突破境界照舊() throws {
        let older = weighing(70.4, bodyFat: 14.2, on: "2026-02-05")
        let text = try reply([older, weighing(80, bodyFat: 24, on: "2026-03-05")])
        XCTAssertEqual(text, "金丹中期，FFMI 20.46。根基不穩，體脂降到 20% 以下才能再突破。")
    }

    func test渡劫後期回已是最高的一期() throws {
        let top = weighing(90, bodyFat: 11, on: "2026-03-05", leanMassKg: 80)
        XCTAssertEqual(try reply([top]), "渡劫後期，FFMI 26.80，已是最高的一期。")
    }

    func test女性用女性的境界與還差幾公斤() throws {
        let measurement = weighing(60, bodyFat: 23, on: "2026-03-05", leanMassKg: 46)
        let text = try reply([measurement], sex: .female, heightCm: 160)
        XCTAssertEqual(text, "元嬰中期，FFMI 19.23，距元嬰後期還差 0.2 公斤肌肉。")
    }

    func test女性體脂28回根基不穩與要降到27以下() throws {
        let measurement = weighing(60, bodyFat: 28, on: "2026-03-05", leanMassKg: 46)
        let text = try reply([measurement], sex: .female, heightCm: 160)
        XCTAssertEqual(text, "元嬰中期，FFMI 19.23。根基不穩，體脂降到 27% 以下境界才生效。")
    }

    func test資料壞掉時回讀不出來與原因() {
        let broken = SiriReply.realmFailure(RencanError.invalidDate)
        XCTAssertEqual(broken, "資料讀不出來：日期格式不對。")
        let unknown = SiriReply.realmFailure(OtherError())
        XCTAssertEqual(unknown, "資料讀不出來，先打開人蔘修煉看一下。")
    }
}
