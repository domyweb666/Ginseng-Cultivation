import XCTest

@testable import RencanCore

/// 小人蔘的姿勢與畫圖點位，要跟預覽頁（.uiux/小人蔘/頭套預覽.html）那段 JS 算出來的一樣，
/// 小數比到第 6 位。標準答案在 MascotFixture.swift，由 .vibe/tools/mascot_golden.mjs 產生。
final class MascotTests: XCTestCase {
    private let tolerance = 1e-6
    /// 姿勢的 20 個數字各叫什麼，比對失敗時訊息裡看得出是哪一個。
    private let poseFields = MascotTests.limbFields + MascotTests.headFields
    private static let armFields = ["左肩", "左肘", "右肩", "右肘"]
    private static let legFields = ["左髖", "左膝", "右髖", "右膝"]
    private static let limbFields = armFields + legFields + ["前傾", "歪頭", "頭上下", "肩上下"]
    private static let faceFields = ["眼高", "視線x", "視線y", "眉角度", "眉上下"]
    private static let headFields = faceFields + ["思考泡泡", "Z", "汗"]

    // MARK: 姿勢

    func test小人蔘的六個動作代號跟預覽頁一樣() {
        let names = ["wave", "sleep", "think", "oops", "shrug", "please"]
        XCTAssertEqual(MascotAction.allCases.map(\.rawValue), names)
    }

    func test基準姿勢跟預覽頁一樣() throws {
        let record = try XCTUnwrap(records(MascotFixture.basePose, words: 1).first)
        XCTAssertEqual(MascotPose(), Mascot.basePose)
        XCTAssertEqual(Mascot.basePose.mouth.rawValue, record.word(0))
        XCTAssertEqual(Mascot.basePose.time, 0)
        check(poseNumbers(Mascot.basePose), record.numbers, "基準姿勢", names: poseFields)
    }

    func test揮手的姿勢跟預覽頁一樣() throws {
        try checkPoses(of: .wave, count: 4)
    }

    func test打瞌睡的姿勢跟預覽頁一樣() throws {
        try checkPoses(of: .sleep, count: 4)
    }

    func test思考的姿勢跟預覽頁一樣() throws {
        try checkPoses(of: .think, count: 4)
    }

    func test抓頭的姿勢跟預覽頁一樣() throws {
        try checkPoses(of: .oops, count: 4)
    }

    func test聳肩的姿勢跟預覽頁一樣() throws {
        try checkPoses(of: .shrug, count: 7)
    }

    func test拜託的姿勢跟預覽頁一樣() throws {
        try checkPoses(of: .please, count: 4)
    }

    // MARK: 換動作的補間

    func test換動作的補間跟預覽頁一樣() throws {
        let all = try records(MascotFixture.blends, words: 3)
        XCTAssertEqual(all.count, 6)
        for record in all {
            let note = "補間 \(record.label)"
            let from = try XCTUnwrap(MascotAction(rawValue: record.word(0)), note)
            let target = try XCTUnwrap(MascotAction(rawValue: record.word(1)), note)
            XCTAssertEqual(record.numbers.count, 23, note)
            guard record.numbers.count == 23 else { continue }
            let start = Mascot.pose(action: from, time: record.numbers[0])
            let end = Mascot.pose(action: target, time: record.numbers[1])
            let pose = Mascot.blend(from: start, to: end, progress: record.numbers[2])
            XCTAssertEqual(pose.mouth.rawValue, record.word(2), note)
            XCTAssertEqual(pose.time, record.numbers[1], note)
            check(poseNumbers(pose), Array(record.numbers.dropFirst(3)), note, names: poseFields)
        }
    }

    func test補間走不到一半嘴型不換走到一半才換() {
        let smiling = Mascot.pose(action: .wave, time: 0)
        let dozing = Mascot.pose(action: .sleep, time: 0)
        XCTAssertEqual(Mascot.blend(from: smiling, to: dozing, progress: 0.49).mouth, .smile)
        XCTAssertEqual(Mascot.blend(from: smiling, to: dozing, progress: 0.5).mouth, .round)
    }

    func test補間走完就是新動作的姿勢() {
        let start = Mascot.pose(action: .oops, time: 0.3)
        let target = Mascot.pose(action: .please, time: 0.1)
        let done = Mascot.blend(from: start, to: target, progress: 1)
        XCTAssertEqual(done.mouth, target.mouth)
        XCTAssertEqual(done.time, target.time)
        check(poseNumbers(done), poseNumbers(target), "補間走完", names: poseFields)
    }

    func test換動作的補間是0點28秒() {
        XCTAssertEqual(Mascot.transitionSeconds, 0.28)
    }

    func test補間進度慢進慢出跟預覽頁一樣() throws {
        let all = try records(MascotFixture.transitions, words: 0)
        XCTAssertEqual(all.count, 8)
        for record in all {
            let elapsed = try XCTUnwrap(record.numbers.first)
            let expected = try XCTUnwrap(record.numbers.last)
            let progress = Mascot.transitionProgress(elapsedSeconds: elapsed)
            XCTAssertEqual(progress, expected, accuracy: tolerance, "過了 \(elapsed) 秒")
        }
    }

    func test減少動態效果的靜態姿勢每個動作都看得出來() {
        for action in MascotAction.allCases where action != .shrug {
            let still = Mascot.restPose(action: action)
            XCTAssertEqual(still, Mascot.pose(action: action, time: 0), action.rawValue)
        }
        // 聳肩在第 0 秒手還垂著，靜態姿勢要停在肩膀抬到最高、兩手攤開的時候。
        let shrug = Mascot.restPose(action: .shrug)
        XCTAssertEqual(shrug.shoulderOffsetY, -6, accuracy: tolerance)
        XCTAssertEqual(shrug.leftElbow, -88, accuracy: tolerance)
        XCTAssertEqual(shrug.rightElbow, 88, accuracy: tolerance)
        XCTAssertEqual(shrug.mouth, .wavy)
    }

    // MARK: 畫圖的點位

    func test骨架尺寸跟預覽頁一樣() throws {
        let legs = [MascotRig.thighLength, MascotRig.shinLength, MascotRig.torsoLength]
        let shoulders = [MascotRig.shoulderDrop, MascotRig.shoulderHalfWidth]
        let arms = [MascotRig.upperArmLength, MascotRig.forearmLength]
        let rig = [MascotRig.hipX, MascotRig.hipY, MascotRig.groundY] + legs + shoulders + arms
        check(rig, try firstNumbers(MascotFixture.rig), "骨架尺寸")
    }

    func test身體各點的座標跟預覽頁一樣() throws {
        try checkBlock(MascotFixture.figures, count: 7, "身體") { pose in
            figureNumbers(Mascot.skeleton(for: pose))
        }
    }

    func test五官的座標跟預覽頁一樣() throws {
        try checkBlock(MascotFixture.faces, count: 7, "五官") { pose in
            let face = Mascot.face(for: pose)
            let eyes = face.eyes.flatMap { [$0.x, $0.y, $0.width, $0.height] }
            return eyes + face.brows.flatMap { pointNumbers($0) }
        }
    }

    func test嘴的路徑跟預覽頁一樣() throws {
        let all = try records(MascotFixture.mouths, words: 3)
        XCTAssertEqual(all.count, 7)
        for record in all {
            let note = "嘴 \(record.label)"
            let action = try XCTUnwrap(MascotAction(rawValue: record.word(0)), note)
            let time = try XCTUnwrap(record.numbers.first, note)
            let face = Mascot.face(for: Mascot.pose(action: action, time: time))
            let expected = Array(record.numbers.dropFirst())
            XCTAssertEqual(face.mouth.rawValue, record.word(1), note)
            if face.mouth == .round {
                XCTAssertTrue(face.mouthPath.isEmpty, note)
                check([face.mouthCenter.x, face.mouthCenter.y], expected, note)
            } else {
                XCTAssertEqual(stepLetters(face.mouthPath), record.word(2), note)
                check(stepNumbers(face.mouthPath), expected, note)
            }
        }
    }

    func test思考泡泡跟預覽頁一樣() throws {
        try checkBlock(MascotFixture.thoughtDots, count: 1, "思考泡泡") { pose in
            markNumbers(Mascot.skeleton(for: pose).thoughtDots)
        }
    }

    func test打瞌睡的Z跟預覽頁一樣() throws {
        try checkBlock(MascotFixture.sleepLetters, count: 1, "打瞌睡的 Z") { pose in
            markNumbers(Mascot.skeleton(for: pose).sleepLetters)
        }
    }

    func test抓頭的汗滴跟預覽頁一樣() throws {
        try checkBlock(MascotFixture.sweats, count: 1, "汗滴") { pose in
            let face = Mascot.face(for: pose)
            return stepNumbers(face.sweatPath) + [face.sweatOpacity]
        }
    }

    func test沒在思考沒在睡沒冒汗時不畫泡泡Z汗滴() {
        let pose = Mascot.pose(action: .wave, time: 1)
        let skeleton = Mascot.skeleton(for: pose)
        let face = Mascot.face(for: pose)
        XCTAssertTrue(skeleton.thoughtDots.isEmpty)
        XCTAssertTrue(skeleton.sleepLetters.isEmpty)
        XCTAssertTrue(face.sweatPath.isEmpty)
        XCTAssertEqual(face.sweatOpacity, 0)
    }

    // MARK: 頭套

    func test頭套不會動的路徑跟預覽頁一樣() throws {
        let all = try records(MascotFixture.hoodPaths, words: 2)
        let strokes = hoodStrokes()
        XCTAssertEqual(strokes.count, 13)
        XCTAssertEqual(all.count, strokes.count)
        for (record, stroke) in zip(all, strokes) {
            let note = "頭套 \(record.word(0))"
            let actual = [stroke.width, stroke.opacity] + stepNumbers(stroke.steps)
            XCTAssertEqual(stepLetters(stroke.steps), record.word(1), note)
            check(actual, record.numbers, note)
        }
    }

    func test頭套的紅果與白臉尺寸跟預覽頁一樣() throws {
        let berries = pointNumbers(MascotHood.berryCenters)
        check(berries, try firstNumbers(MascotFixture.berries), "紅果的圓心")
        let berry = [MascotHood.berryRadius, MascotHood.berryShineOffset]
        let shine = [MascotHood.berryShineRadius, MascotHood.berryShineOpacity]
        let rims = [MascotHood.faceCenter.y, MascotHood.faceRimRadius, MascotHood.faceRadius]
        let sizes = berry + shine + rims + [MascotHood.faceOutlineWidth]
        check(sizes, try firstNumbers(MascotFixture.hoodSizes), "紅果與白臉的尺寸")
        XCTAssertEqual(MascotHood.faceCenter.x, 0)
    }

    // MARK: 比對

    /// 兩串數字要一樣長，每一個都差不到容許值。
    private func check(
        _ actual: [Double], _ expected: [Double], _ note: String, names: [String] = []
    ) {
        XCTAssertEqual(actual.count, expected.count, "\(note)：數字的個數")
        for (index, pair) in zip(actual, expected).enumerated() {
            let name = index < names.count ? names[index] : "第 \(index + 1) 個數字"
            XCTAssertEqual(pair.0, pair.1, accuracy: tolerance, "\(note)：\(name)")
        }
    }

    /// 某個動作在標準答案裡的每個時間點都算一次，姿勢要一樣。
    private func checkPoses(of action: MascotAction, count: Int) throws {
        let all = try records(MascotFixture.poses, words: 2)
        let mine = all.filter { $0.word(0) == action.rawValue }
        XCTAssertEqual(mine.count, count, "\(action.rawValue)：取樣的筆數")
        for record in mine {
            let time = try XCTUnwrap(record.numbers.first, action.rawValue)
            let note = "\(action.rawValue) 第 \(time) 秒"
            let pose = Mascot.pose(action: action, time: time)
            XCTAssertEqual(pose.mouth.rawValue, record.word(1), note)
            XCTAssertEqual(pose.time, time, note)
            check(poseNumbers(pose), Array(record.numbers.dropFirst()), note, names: poseFields)
        }
    }

    /// 把一塊標準答案逐筆比過：每筆開頭是動作與時間，後面的數字要等於 actual 算出來的。
    private func checkBlock(
        _ text: String, count: Int, _ what: String, actual: (MascotPose) -> [Double]
    ) throws {
        let all = try records(text, words: 1)
        XCTAssertEqual(all.count, count, "\(what)：取樣的筆數")
        for record in all {
            let action = try XCTUnwrap(MascotAction(rawValue: record.word(0)), what)
            let time = try XCTUnwrap(record.numbers.first, what)
            let note = "\(what) \(action.rawValue) 第 \(time) 秒"
            let pose = Mascot.pose(action: action, time: time)
            check(actual(pose), Array(record.numbers.dropFirst()), note)
        }
    }

    private func firstNumbers(_ text: String) throws -> [Double] {
        try XCTUnwrap(records(text, words: 0).first).numbers
    }

    /// 把一塊標準答案拆成一筆一筆：用直線 | 分開，每筆前面 words 個字、後面全是數字。
    private func records(_ text: String, words: Int) throws -> [MascotRecord] {
        var result: [MascotRecord] = []
        for chunk in text.split(separator: "|") {
            let tokens = chunk.split(whereSeparator: \.isWhitespace).map { String($0) }
            guard !tokens.isEmpty else { continue }
            var numbers: [Double] = []
            for token in tokens.dropFirst(words) {
                let number = try XCTUnwrap(Double(token), "標準答案裡有不是數字的字：\(token)")
                numbers.append(number)
            }
            result.append(MascotRecord(words: Array(tokens.prefix(words)), numbers: numbers))
        }
        return result
    }
}

/// 標準答案的一筆紀錄：前面幾個字，後面一串數字。
private struct MascotRecord {
    let words: [String]
    let numbers: [Double]

    var label: String { words.joined(separator: " ") }

    /// 第幾個字；沒有就回空字串，讓比對失敗而不是當掉。
    func word(_ index: Int) -> String {
        index < words.count ? words[index] : ""
    }
}

// MARK: 把算出來的東西攤平成一串數字（順序跟 MascotFixture 各塊的說明一樣）

private func poseNumbers(_ pose: MascotPose) -> [Double] {
    let arms = [pose.leftShoulder, pose.leftElbow, pose.rightShoulder, pose.rightElbow]
    let legs = [pose.leftHip, pose.leftKnee, pose.rightHip, pose.rightKnee]
    let body = [pose.lean, pose.headTilt, pose.headOffsetY, pose.shoulderOffsetY]
    let face = [pose.eyeHeight, pose.lookX, pose.lookY, pose.browAngle, pose.browOffsetY]
    let marks = [pose.thoughtBubble, pose.sleepMarks, pose.sweatDrop]
    return arms + legs + body + face + marks
}

private func pointNumbers(_ points: [MascotPoint]) -> [Double] {
    points.flatMap { [$0.x, $0.y] }
}

private func markNumbers(_ marks: [MascotMark]) -> [Double] {
    marks.flatMap { [$0.position.x, $0.position.y, $0.size, $0.opacity] }
}

/// 左腿、右腿、身體、左臂、右臂的點，再接頭套原點、頭套轉幾度、影子中心。
private func figureNumbers(_ skeleton: MascotSkeleton) -> [Double] {
    let limbs = skeleton.legs + [skeleton.torso] + skeleton.arms
    let head = [skeleton.headOrigin.x, skeleton.headOrigin.y, skeleton.headRotationDegrees]
    let shadow = [skeleton.shadowCenter.x, skeleton.shadowCenter.y]
    return limbs.flatMap { pointNumbers($0) } + head + shadow
}

private func stepPoints(_ step: MascotPathStep) -> [MascotPoint] {
    switch step {
    case .move(let point), .line(let point):
        return [point]
    case .quad(let control, let end):
        return [control, end]
    case .curve(let control1, let control2, let end):
        return [control1, control2, end]
    case .close:
        return []
    }
}

private func stepNumbers(_ steps: [MascotPathStep]) -> [Double] {
    steps.flatMap { pointNumbers(stepPoints($0)) }
}

/// 路徑的指令字母，跟 SVG 一樣：M 起點、L 直線、Q 二次曲線、C 三次曲線、Z 封口。
private func stepLetters(_ steps: [MascotPathStep]) -> String {
    var letters = ""
    for step in steps {
        switch step {
        case .move:
            letters += "M"
        case .line:
            letters += "L"
        case .quad:
            letters += "Q"
        case .curve:
            letters += "C"
        case .close:
            letters += "Z"
        }
    }
    return letters
}

/// 頭套的路徑照畫的順序排成一串；葉子只填色，線寬記 0；主體的線寬是外框的線寬。
private func hoodStrokes() -> [MascotStroke] {
    let leaves = MascotHood.leaves.map { MascotStroke(steps: $0, width: 0) }
    let body = MascotStroke(steps: MascotHood.body, width: MascotHood.bodyOutlineWidth)
    let upper = MascotHood.whiskers + [MascotHood.stem] + leaves + MascotHood.leafVeins
    return upper + [body, MascotHood.bodyShine] + MascotHood.rings
}
