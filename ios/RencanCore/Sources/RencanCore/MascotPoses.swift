import Foundation

// 小人蔘的姿勢（片 K2，PRD S29）：基準姿勢、六個動作、換動作的補間。
// 原始定義是 .uiux/小人蔘/頭套預覽.html 的 <script id="core">（basePose、ANIMS、poseAt、
// blend、ss），一行對一行搬過來，數字不改。標準答案由 .vibe/tools/mascot_golden.mjs 跑那段
// JS 產生（MascotFixture.swift），MascotTests 逐項比到小數第 6 位。
// 一個檔最多 400 行、這一片又只准開兩個檔，所以動作與嘴型的列舉放在 Mascot.swift，
// 頭套不會動的路徑表 MascotHood 放在這個檔的檔尾。
//
// 網頁版縮寫對照（規矩檔第 3 節）：
//   lS → leftShoulder、lE → leftElbow、rS → rightShoulder、rE → rightElbow、
//   lH → leftHip、lK → leftKnee、rH → rightHip、rK → rightKnee、
//   head → headTilt、hy → headOffsetY、sh → shoulderOffsetY、eyeH → eyeHeight、
//   brow → browAngle、browY → browOffsetY、bubble → thoughtBubble、zzz → sleepMarks、
//   sweat → sweatDrop、t → time、ss → smoothStep、嘴型 'o' → .round。
// 跟網頁版不一樣的只有這幾處：
//   1. 沒搬 rx、ry、tl、hs、squash、sx、happy 這七個欄位與嘴型 'open'。六個動作都沒動到
//      它們，永遠是基準值，畫出來沒有差別；mascot_golden.mjs 會檢查，網頁版哪天動到就報錯。
//   2. 換動作的 0.28 秒與慢進慢出，網頁版寫在畫面程式裡，這裡收成 transitionProgress。
//   3. 「減少動態效果」的靜態姿勢 restPose 是這裡新定的（網頁版只是停在第 0 秒）。
// 角度的單位是度：0 度朝正下方，正的往畫面右邊抬；手肘、膝蓋是相對上一節再轉多少。
// 六個動作函式裡的數字就是動作表本身，每個數字只出現在這一處，照網頁版原樣寫在式子裡。

/// 某一刻的姿勢。預設值就是基準姿勢（網頁版的 basePose）：站直、兩手收在胸前、微笑。
public struct MascotPose: Equatable, Sendable {
    public var leftShoulder: Double = -38
    public var leftElbow: Double = 143
    public var rightShoulder: Double = 38
    public var rightElbow: Double = -143
    public var leftHip: Double = -14
    public var leftKnee: Double = 0
    public var rightHip: Double = 14
    public var rightKnee: Double = 0
    /// 身體往右傾幾度。
    public var lean: Double = 0
    /// 頭再多歪幾度（加在 lean 上面）。
    public var headTilt: Double = 0
    /// 頭上下移多少，往下是正的。
    public var headOffsetY: Double = 0
    /// 肩膀上下移多少，往下是正的；頭跟身體頂端只跟著移一半。
    public var shoulderOffsetY: Double = 0
    public var eyeHeight: Double = 12
    public var lookX: Double = 0
    public var lookY: Double = 0
    /// 眉毛的角度，正的是外側往上揚，負的是八字眉。
    public var browAngle: Double = 2
    public var browOffsetY: Double = 0
    public var mouth: MascotMouth = .smile
    /// 三個開關照網頁版用 0 到 1 的數字，補間時才會跟著漸變；超過 0.5 才畫。
    public var thoughtBubble: Double = 0
    public var sleepMarks: Double = 0
    public var sweatDrop: Double = 0
    /// 這個動作開始後過了幾秒；泡泡、Z、汗滴自己的小動畫看這個時間。
    public var time: Double = 0

    /// 基準姿勢。
    public init() {}

    public var showsThoughtBubble: Bool { thoughtBubble > Mascot.markThreshold }
    public var showsSleepMarks: Bool { sleepMarks > Mascot.markThreshold }
    public var showsSweatDrop: Bool { sweatDrop > Mascot.markThreshold }
}

// MARK: 姿勢怎麼算

extension Mascot {
    /// 換動作時，從畫面上當下的姿勢補到新動作要花的秒數。
    public static let transitionSeconds = 0.28
    /// 基準姿勢。
    public static let basePose = MascotPose()
    /// 泡泡、Z、汗滴的開關超過這個值才畫。
    static let markThreshold = 0.5

    /// 某個動作開始後第 time 秒的姿勢（網頁版的 poseAt）。
    public static func pose(action: MascotAction, time: Double) -> MascotPose {
        var pose = actionPose(action, at: time)
        pose.time = time
        return pose
    }

    /// 系統開「減少動態效果」時停住用的靜態姿勢：每個動作最有代表性的那一刻。
    /// 聳肩在第 0 秒手還垂著，看不出是聳肩，所以停在肩膀抬到最高的時候；其他動作停在第 0 秒。
    public static func restPose(action: MascotAction) -> MascotPose {
        pose(action: action, time: action == .shrug ? shrugHoldTime : 0)
    }

    /// 兩個姿勢之間的補間（網頁版的 blend）：數字照 progress 的比例走，嘴型過了一半才換，
    /// 時間直接用目標姿勢的。progress 要先過 transitionProgress，動起來才是慢進慢出。
    public static func blend(
        from start: MascotPose, to target: MascotPose, progress: Double
    ) -> MascotPose {
        var pose = target
        pose.leftShoulder = mix(start.leftShoulder, target.leftShoulder, progress)
        pose.leftElbow = mix(start.leftElbow, target.leftElbow, progress)
        pose.rightShoulder = mix(start.rightShoulder, target.rightShoulder, progress)
        pose.rightElbow = mix(start.rightElbow, target.rightElbow, progress)
        pose.leftHip = mix(start.leftHip, target.leftHip, progress)
        pose.leftKnee = mix(start.leftKnee, target.leftKnee, progress)
        pose.rightHip = mix(start.rightHip, target.rightHip, progress)
        pose.rightKnee = mix(start.rightKnee, target.rightKnee, progress)
        pose.lean = mix(start.lean, target.lean, progress)
        pose.headTilt = mix(start.headTilt, target.headTilt, progress)
        pose.headOffsetY = mix(start.headOffsetY, target.headOffsetY, progress)
        pose.shoulderOffsetY = mix(start.shoulderOffsetY, target.shoulderOffsetY, progress)
        pose.eyeHeight = mix(start.eyeHeight, target.eyeHeight, progress)
        pose.lookX = mix(start.lookX, target.lookX, progress)
        pose.lookY = mix(start.lookY, target.lookY, progress)
        pose.browAngle = mix(start.browAngle, target.browAngle, progress)
        pose.browOffsetY = mix(start.browOffsetY, target.browOffsetY, progress)
        pose.thoughtBubble = mix(start.thoughtBubble, target.thoughtBubble, progress)
        pose.sleepMarks = mix(start.sleepMarks, target.sleepMarks, progress)
        pose.sweatDrop = mix(start.sweatDrop, target.sweatDrop, progress)
        pose.mouth = progress < mouthSwitchProgress ? start.mouth : target.mouth
        return pose
    }

    /// 換動作後過了 elapsedSeconds 秒，補間該走到哪（0 到 1，慢進慢出）。
    /// 回 1 就是補完了，之後直接用新動作的姿勢。
    public static func transitionProgress(elapsedSeconds: Double) -> Double {
        smoothStep(0, transitionSeconds, elapsedSeconds)
    }

    private static func mix(_ start: Double, _ target: Double, _ progress: Double) -> Double {
        start + (target - start) * progress
    }

    /// 網頁版的 ss：value 在 lower 到 upper 之間走了幾成（夾在 0 到 1），再套慢進慢出的
    /// 標準式子 3k² − 2k³。
    private static func smoothStep(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
        let ratio = max(0, min(1, (value - lower) / (upper - lower)))
        return ratio * ratio * (3 - 2 * ratio)
    }
}

// MARK: 六個動作（網頁版的 ANIMS）

extension Mascot {
    /// 手自然垂下時的肩膀與手肘角度（左手是負的）；揮手、抓頭的左手與聳肩的起點共用。
    private static let loweredShoulder: Double = 16
    private static let loweredElbow: Double = 6
    /// 聳肩一輪 2.4 秒：0 到 0.3 秒抬起來，停到 1.5 秒，1.9 秒放完，剩下的時間休息。
    private static let shrugCycleSeconds = 2.4
    private static let shrugRaisedBy = 0.3
    private static let shrugLowerFrom = 1.5
    private static let shrugLoweredBy = 1.9
    /// 聳肩抬過四成，嘴從微笑換成波浪嘴。
    private static let shrugWavyMouthAbove = 0.4
    /// 聳肩停在最高點的中間那一刻，靜態姿勢用。
    private static let shrugHoldTime = 0.9
    private static let mouthSwitchProgress = 0.5

    private static func actionPose(_ action: MascotAction, at time: Double) -> MascotPose {
        switch action {
        case .wave:
            return wavePose(at: time)
        case .sleep:
            return sleepPose(at: time)
        case .think:
            return thinkPose(at: time)
        case .oops:
            return oopsPose(at: time)
        case .shrug:
            return shrugPose(at: time)
        case .please:
            return pleasePose(at: time)
        }
    }

    /// 揮手：右手舉高、前臂來回擺，頭跟著輕輕點。
    private static func wavePose(at time: Double) -> MascotPose {
        var pose = MascotPose()
        pose.rightShoulder = 110
        pose.rightElbow = 40 + 22 * sin(time * 9)
        pose.leftShoulder = -loweredShoulder
        pose.leftElbow = -loweredElbow
        pose.headTilt = 5 + 2 * sin(time * 4.5)
        pose.lean = 2
        pose.browAngle = 5
        pose.browOffsetY = -1
        pose.headOffsetY = -sin(time * 4.5)
        return pose
    }

    /// 打瞌睡：頭垂著慢慢點，眼睛瞇成一條線，冒 Z。
    private static func sleepPose(at time: Double) -> MascotPose {
        let nod = sin(time * 1.4)
        var pose = MascotPose()
        pose.headTilt = 13 + 3 * nod
        pose.lean = 3 + 0.8 * nod
        pose.headOffsetY = 1
        pose.eyeHeight = 1.5
        pose.browAngle = 0
        pose.browOffsetY = 2
        pose.mouth = .round
        pose.sleepMarks = 1
        pose.shoulderOffsetY = -nod
        return pose
    }

    /// 思考：右手托下巴，眼睛往左上看，冒思考泡泡。
    private static func thinkPose(at time: Double) -> MascotPose {
        var pose = MascotPose()
        pose.rightShoulder = 42
        pose.rightElbow = 165
        pose.leftShoulder = -30
        pose.leftElbow = 120
        pose.headTilt = -8 + 1.5 * sin(time * 1.6)
        pose.lean = -1.5
        pose.lookX = -2
        pose.lookY = -3
        pose.browAngle = 3
        pose.browOffsetY = -2
        pose.thoughtBubble = 1
        pose.mouth = .flat
        return pose
    }

    /// 抓頭：右手舉到頭邊快速抓，八字眉，冒汗。
    private static func oopsPose(at time: Double) -> MascotPose {
        var pose = MascotPose()
        pose.rightShoulder = 112
        pose.rightElbow = 45 + 7 * sin(time * 12)
        pose.leftShoulder = -loweredShoulder
        pose.leftElbow = -loweredElbow
        pose.headTilt = 9
        pose.lean = 2
        pose.browAngle = -12
        pose.browOffsetY = -1
        pose.lookY = 3
        pose.lookX = -1
        pose.mouth = .wavy
        pose.sweatDrop = 1
        return pose
    }

    /// 聳肩：兩手攤開、肩膀抬起來停一下再放下，一輪 2.4 秒。
    private static func shrugPose(at time: Double) -> MascotPose {
        let cycle = time.truncatingRemainder(dividingBy: shrugCycleSeconds)
        let raising = smoothStep(0, shrugRaisedBy, cycle)
        let lowering = smoothStep(shrugLowerFrom, shrugLoweredBy, cycle)
        let lift = raising * (1 - lowering)
        var pose = MascotPose()
        pose.shoulderOffsetY = -6 * lift
        pose.leftShoulder = -loweredShoulder - 14 * lift
        pose.leftElbow = -loweredElbow - 82 * lift
        pose.rightShoulder = loweredShoulder + 14 * lift
        pose.rightElbow = loweredElbow + 82 * lift
        pose.headTilt = 8 * lift
        pose.browAngle = 2 - 12 * lift
        pose.browOffsetY = -3 * lift
        pose.mouth = lift > shrugWavyMouthAbove ? .wavy : .smile
        pose.lookY = -lift
        return pose
    }

    /// 拜託：兩手合在胸前，整個人上下小跳，八字眉、眼睛睜大。
    private static func pleasePose(at time: Double) -> MascotPose {
        let bounce = sin(time * 7)
        var pose = MascotPose()
        pose.leftShoulder = -50
        pose.leftElbow = 167
        pose.rightShoulder = 50
        pose.rightElbow = -167
        pose.shoulderOffsetY = -2 - 1.5 * bounce
        pose.headOffsetY = -1.5 * bounce
        pose.headTilt = 7 + 1.5 * bounce
        pose.lean = 1
        pose.browAngle = -15
        pose.browOffsetY = -2
        pose.eyeHeight = 13
        pose.lookY = -1.5
        pose.mouth = .round
        return pose
    }
}

// MARK: 頭套不會動的部分

/// 人蔘頭套不會動的部分與五官的尺寸（網頁版 headSVG）。座標以脖子頂端為原點，往上是負的。
/// 畫的順序照下面由上往下：鬚根、梗、葉、葉脈、紅果、主體、反光、環紋、白臉外圈、白臉，最後五官。
public enum MascotHood {
    /// 兩側的鬚根，畫在主體後面。
    public static let whiskers = [whiskerLeft, whiskerRight, whiskerUpper]
    /// 頂端的梗。
    public static let stem = MascotStroke(steps: [.move(stemBase), .line(stemTip)], width: 5)
    /// 兩片葉子（填色）與上面的葉脈。
    public static let leaves = [leafLeft, leafRight]
    public static let leafVeins = [veinLeft, veinRight]
    /// 五顆紅果的圓心。每顆的左上方（x、y 各偏 berryShineOffset）有一個白色小亮點。
    public static let berryCenters = points([-9, -142, 9, -142, 0, -137, -5, -151, 5, -151])
    public static let berryRadius = 5.4
    public static let berryShineOffset = -1.6
    public static let berryShineRadius = 1.4
    public static let berryShineOpacity = 0.7
    /// 人蔘主體：梨形加頂端的蘆頭，填色再描邊。
    public static let body = closedCurves(bodyUpper + bodyLower)
    public static let bodyOutlineWidth: Double = 3
    /// 主體左上的白色反光。
    public static let bodyShine = stroke(5, 0.55, [-33, -58, -31, -70, -26, -79, -20, -86])
    /// 蘆頭的三道環紋。
    public static let rings = [ringTop, ringMiddle, ringLower]
    /// 白臉：先畫外圈（半徑 faceRimRadius 的實心圓），再畫白臉（填色加描邊）。
    public static let faceCenter = MascotPoint(x: 0, y: -46)
    public static let faceRimRadius: Double = 33
    public static let faceRadius: Double = 30
    public static let faceOutlineWidth: Double = 3

    // 五官的尺寸。眼睛是圓角長方形，圓角半徑是寬的一半；眼睛比寬還矮時（打瞌睡），
    // 上下方向的圓角只到高的一半（SVG 的規則）。位置由 Mascot.face(for:) 算。
    public static let eyeSpacing: Double = 11
    public static let eyeCenterY: Double = -48
    public static let eyeWidth = 4.6
    public static let minimumEyeHeight = 1.5
    public static let browSpacing: Double = 12
    public static let browCenterY: Double = -61
    public static let browHalfLength: Double = 8
    public static let browLineWidth = 3.4
    public static let mouthCenterY: Double = -30
    public static let mouthLineWidth: Double = 3
    /// 小圓嘴：在嘴的中心畫一個空心圓。
    public static let mouthRoundRadius = 2.6
    public static let mouthRoundLineWidth = 2.6
    /// 眉毛和嘴跟著視線移動的比例（眼睛是整個跟著移）。
    public static let gazeFollow = 0.5

    // 下面的數字是 headSVG 那幾條路徑的座標，一個不改。
    private static let whiskerLeft = stroke(3.2, 1, [-43, -20, -55, -18, -61, -8, -57, 3])
    private static let whiskerRight = stroke(3.2, 1, [43, -20, 55, -18, 61, -8, 57, 3])
    private static let whiskerUpper = stroke(2.6, 1, [-45, -38, -56, -41, -63, -35, -65, -27])
    private static let stemBase = MascotPoint(x: 0, y: -116)
    private static let stemTip = MascotPoint(x: 0, y: -137)
    private static let leafLeftTop: [Double] = [-2, -126, -14, -149, -42, -153, -60, -139]
    private static let leafLeft = closedCurves(leafLeftTop + [-44, -124, -20, -118, -2, -126])
    private static let leafRightTop: [Double] = [2, -126, 14, -149, 42, -153, 60, -139]
    private static let leafRight = closedCurves(leafRightTop + [44, -124, 20, -118, 2, -126])
    private static let veinLeft = stroke(1.6, 0.55, [-8, -129, -24, -137, -40, -140, -53, -139])
    private static let veinRight = stroke(1.6, 0.55, [8, -129, 24, -137, 40, -140, 53, -139])
    // 主體一圈七段曲線，從左邊中間出發順時針走：左側往上、蘆頭左、頂、右、右側往下、底部兩段。
    private static let bodyLeftSide: [Double] = [-46, -34, -46, -64, -32, -84, -15, -97]
    private static let bodyCrownLeft: [Double] = [-20, -101, -20, -112, -12, -117]
    private static let bodyCrownTop: [Double] = [-6, -120, 6, -120, 12, -117]
    private static let bodyCrownRight: [Double] = [20, -112, 20, -101, 15, -97]
    private static let bodyRightSide: [Double] = [32, -84, 46, -64, 46, -34]
    private static let bodyBottom: [Double] = [46, -10, 28, 6, 0, 6, -28, 6, -46, -10, -46, -34]
    private static let bodyUpper = bodyLeftSide + bodyCrownLeft + bodyCrownTop + bodyCrownRight
    private static let bodyLower = bodyRightSide + bodyBottom
    private static let ringTop = ring(2.4, 0.85, [-16, -108, 0, -103, 16, -108])
    private static let ringMiddle = ring(2.4, 0.85, [-14, -97, 0, -92, 14, -97])
    private static let ringLower = ring(2.2, 0.6, [-27, -85, 0, -78, 27, -85])
    private static let ringPointCount = 3

    /// 一串數字兩個兩個配成點。
    private static func points(_ numbers: [Double]) -> [MascotPoint] {
        stride(from: 0, to: numbers.count - 1, by: 2).map {
            MascotPoint(x: numbers[$0], y: numbers[$0 + 1])
        }
    }

    /// 起點加一段段三次曲線（SVG 的 M 加 C），每段是兩個控制點加終點。
    private static func curves(_ numbers: [Double]) -> [MascotPathStep] {
        let all = points(numbers)
        guard let start = all.first else { return [] }
        var steps = [MascotPathStep.move(start)]
        for index in stride(from: 1, to: all.count - 2, by: 3) {
            let end = all[index + 2]
            steps.append(.curve(control1: all[index], control2: all[index + 1], end: end))
        }
        return steps
    }

    private static func closedCurves(_ numbers: [Double]) -> [MascotPathStep] {
        curves(numbers) + [.close]
    }

    /// 一條三次曲線的描邊：線寬、不透明度、座標。
    private static func stroke(
        _ width: Double, _ opacity: Double, _ numbers: [Double]
    ) -> MascotStroke {
        MascotStroke(steps: curves(numbers), width: width, opacity: opacity)
    }

    /// 一條二次曲線的描邊（SVG 的 M 加 Q）：起點、控制點、終點。
    private static func ring(
        _ width: Double, _ opacity: Double, _ numbers: [Double]
    ) -> MascotStroke {
        let all = points(numbers)
        guard all.count == ringPointCount else { return MascotStroke(steps: [], width: width) }
        let steps = [MascotPathStep.move(all[0]), .quad(control: all[1], end: all[2])]
        return MascotStroke(steps: steps, width: width, opacity: opacity)
    }
}
