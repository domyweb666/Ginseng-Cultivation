import Foundation

// 小人蔘（片 K2，PRD S29）：app 的吉祥物，戴人蔘頭套的火柴人。這個檔把姿勢換成畫圖要用的點；
// 姿勢、六個動作、補間與頭套不會動的路徑在 MascotPoses.swift。原始定義是
// .uiux/小人蔘/頭套預覽.html 的 <script id="core">（RIG、renderChar、headSVG），數字不改，
// 只搬多米選的頭套款。標準答案由 .vibe/tools/mascot_golden.mjs 產生，MascotTests 逐項比對。
// 畫面端的用法：Mascot.pose(action:time:) 拿姿勢，再用 Mascot.skeleton(for:) 拿身體的點、
// Mascot.face(for:) 拿五官，照下面的順序用 Canvas 畫，不必再算角度。
// 畫的順序（後畫的蓋住先畫的）：影子、兩腿、身體、頭套（MascotHood 由上往下各項，再畫五官）、
// 兩臂、思考泡泡與 Z。線頭一律圓頭。
// 座標就是網頁版 SVG 的座標：x 往右、y 往下。整個角色落在 MascotRig 的 frame 那一塊裡，
// 畫面端把那一塊縮放到要的高度。頭套的座標另以脖子頂端為原點，要先平移、旋轉再畫。
// 跟網頁版不一樣的只有兩處：網頁版把座標四捨五入到小數一位（只為了 SVG 字串短），這裡不做；
// 顏色不放這裡，畫面端從設計代號取（網頁版的色碼看 headSVG）。

/// 六個動作，代號跟網頁版 ANIMS 的鍵同字。
public enum MascotAction: String, CaseIterable, Sendable {
    /// 揮手：第一次打開問身高。
    case wave
    /// 打瞌睡：超過 30 天沒量。
    case sleep
    /// 思考：從健康 app 讀資料。
    case think
    /// 抓頭：存檔失敗、健康 app 讀不到。
    case oops
    /// 聳肩：分析頁沒資料。
    case shrug
    /// 拜託：開每月提醒之前。
    case please
}

/// 嘴型，原始值跟網頁版的字串同字。
public enum MascotMouth: String, Sendable {
    case smile
    /// 小圓嘴，網頁版叫 'o'。
    case round = "o"
    case flat
    case wavy
}

/// 畫布上的一個點。
public struct MascotPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 路徑的一步，對應 SVG 的 M、L、Q、C、Z（都是絕對座標）。
public enum MascotPathStep: Equatable, Sendable {
    case move(MascotPoint)
    case line(MascotPoint)
    case quad(control: MascotPoint, end: MascotPoint)
    case curve(control1: MascotPoint, control2: MascotPoint, end: MascotPoint)
    case close
}

/// 一條描邊的線：路徑、線寬、不透明度。
public struct MascotStroke: Equatable, Sendable {
    public let steps: [MascotPathStep]
    public let width: Double
    public let opacity: Double

    public init(steps: [MascotPathStep], width: Double, opacity: Double = 1) {
        self.steps = steps
        self.width = width
        self.opacity = opacity
    }
}

/// 思考泡泡的一個圓點，或打瞌睡的一個 Z。
public struct MascotMark: Equatable, Sendable {
    /// 圓點的圓心；Z 是字的左下角（SVG 文字的基準點）。
    public let position: MascotPoint
    /// 圓點的半徑；Z 的字級。
    public let size: Double
    public let opacity: Double

    public init(position: MascotPoint, size: Double, opacity: Double) {
        self.position = position
        self.size = size
        self.opacity = opacity
    }
}

/// 一個長方形（眼睛用）：左上角與寬高。
public struct MascotRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 某個姿勢下身體各點的位置。
public struct MascotSkeleton: Equatable, Sendable {
    /// 腳下影子的中心（橢圓的兩個半徑與不透明度在 MascotRig）。
    public let shadowCenter: MascotPoint
    /// 左腿、右腿，各四個點：髖、膝、踝、腳尖。
    public let legs: [[MascotPoint]]
    /// 身體的兩個點：髖、脖子。
    public let torso: [MascotPoint]
    /// 左臂、右臂，各三個點：肩、肘、手。
    public let arms: [[MascotPoint]]
    /// 頭套的原點（脖子頂端）。MascotHood 與 MascotFace 的座標都以這裡為 0,0。
    public let headOrigin: MascotPoint
    /// 頭套繞原點轉幾度，正的是順時針（跟 SVG、SwiftUI 的 rotate 同方向）。
    public let headRotationDegrees: Double
    /// 思考泡泡的三個圓點；沒在思考時是空的。
    public let thoughtDots: [MascotMark]
    /// 打瞌睡飄出來的三個 Z；沒在睡時是空的。
    public let sleepLetters: [MascotMark]

    public init(
        shadowCenter: MascotPoint, legs: [[MascotPoint]], torso: [MascotPoint],
        arms: [[MascotPoint]], headOrigin: MascotPoint, headRotationDegrees: Double,
        thoughtDots: [MascotMark], sleepLetters: [MascotMark]
    ) {
        self.shadowCenter = shadowCenter
        self.legs = legs
        self.torso = torso
        self.arms = arms
        self.headOrigin = headOrigin
        self.headRotationDegrees = headRotationDegrees
        self.thoughtDots = thoughtDots
        self.sleepLetters = sleepLetters
    }
}

/// 某個姿勢下的五官，座標以頭套原點為 0,0。線寬與圓角在 MascotHood。
public struct MascotFace: Equatable, Sendable {
    /// 左眼、右眼。
    public let eyes: [MascotRect]
    /// 左眉、右眉，各是一條直線的兩個端點。
    public let brows: [[MascotPoint]]
    public let mouth: MascotMouth
    /// 嘴的中心；小圓嘴在這裡畫圓。
    public let mouthCenter: MascotPoint
    /// 嘴的路徑（描邊）；小圓嘴是空的。
    public let mouthPath: [MascotPathStep]
    /// 汗滴的路徑（填色）；沒冒汗時是空的。
    public let sweatPath: [MascotPathStep]
    public let sweatOpacity: Double

    public init(
        eyes: [MascotRect], brows: [[MascotPoint]], mouth: MascotMouth, mouthCenter: MascotPoint,
        mouthPath: [MascotPathStep], sweatPath: [MascotPathStep], sweatOpacity: Double
    ) {
        self.eyes = eyes
        self.brows = brows
        self.mouth = mouth
        self.mouthCenter = mouthCenter
        self.mouthPath = mouthPath
        self.sweatPath = sweatPath
        self.sweatOpacity = sweatOpacity
    }
}

/// 骨架的尺寸（網頁版的 RIG 與 renderChar 裡的線寬、影子），單位是 SVG 的一格。
public enum MascotRig {
    public static let hipX: Double = 160
    public static let hipY: Double = 260
    public static let groundY: Double = 380
    public static let thighLength: Double = 62
    public static let shinLength: Double = 62
    public static let torsoLength: Double = 78
    /// 肩膀比脖子頂端低多少；左右肩各離身體中線多少。
    public static let shoulderDrop: Double = 12
    public static let shoulderHalfWidth: Double = 6
    public static let upperArmLength: Double = 44
    public static let forearmLength: Double = 44
    /// 腳掌：從腳踝往外伸多長、腳尖比腳踝低多少。
    public static let footLength: Double = 12
    public static let footDrop: Double = 1
    /// 聳肩時肩膀移多少，脖子與頭只跟著移一半。
    public static let neckFollowsShoulder = 0.5
    /// 線寬：腿與身體、手臂。
    public static let bodyLineWidth: Double = 9
    public static let armLineWidth = 8.5
    /// 影子：比地面低多少、橢圓的兩個半徑、不透明度。
    public static let shadowDrop: Double = 7
    public static let shadowRadiusX: Double = 62
    public static let shadowRadiusY: Double = 8
    public static let shadowOpacity = 0.14
    /// 整個角色佔的那一塊（網頁版小尺寸用的 viewBox 62 8 196 388）。
    public static let frameX: Double = 62
    public static let frameY: Double = 8
    public static let frameWidth: Double = 196
    public static let frameHeight: Double = 388
}

public enum Mascot {
    /// 半圈是 180 度：角度換弧度用，也是「朝正上方」的角度。
    private static let halfTurnDegrees: Double = 180

    /// 身體的點（網頁版 renderChar 裡算的那些）。
    public static func skeleton(for pose: MascotPose) -> MascotSkeleton {
        let hip = MascotPoint(x: MascotRig.hipX, y: MascotRig.hipY)
        let upward = direction(halfTurnDegrees - pose.lean)
        let neck = offset(hip, upward, MascotRig.torsoLength)
        let chest = offset(hip, upward, MascotRig.torsoLength - MascotRig.shoulderDrop)
        let shoulderY = chest.y + pose.shoulderOffsetY
        let neckShift = pose.shoulderOffsetY * MascotRig.neckFollowsShoulder
        let leftShoulder = MascotPoint(x: chest.x - MascotRig.shoulderHalfWidth, y: shoulderY)
        let rightShoulder = MascotPoint(x: chest.x + MascotRig.shoulderHalfWidth, y: shoulderY)
        let leftLeg = leg(from: hip, hipAngle: pose.leftHip, kneeAngle: pose.leftKnee, side: -1)
        let rightLeg = leg(from: hip, hipAngle: pose.rightHip, kneeAngle: pose.rightKnee, side: 1)
        let leftArm = arm(from: leftShoulder, pose.leftShoulder, pose.leftElbow)
        let rightArm = arm(from: rightShoulder, pose.rightShoulder, pose.rightElbow)
        return MascotSkeleton(
            shadowCenter: MascotPoint(x: hip.x, y: MascotRig.groundY + MascotRig.shadowDrop),
            legs: [leftLeg, rightLeg],
            torso: [hip, MascotPoint(x: neck.x, y: neck.y + neckShift)],
            arms: [leftArm, rightArm],
            headOrigin: MascotPoint(x: neck.x, y: neck.y + pose.headOffsetY + neckShift),
            headRotationDegrees: pose.headTilt + pose.lean,
            thoughtDots: pose.showsThoughtBubble ? thoughtDots(above: neck, time: pose.time) : [],
            sleepLetters: pose.showsSleepMarks ? sleepLetters(above: neck, time: pose.time) : []
        )
    }

    /// 五官（網頁版 headSVG 裡會跟著姿勢動的部分）。
    public static func face(for pose: MascotPose) -> MascotFace {
        let mouthX = pose.lookX * MascotHood.gazeFollow
        let mouthY = MascotHood.mouthCenterY + pose.lookY * MascotHood.gazeFollow
        let mouthCenter = MascotPoint(x: mouthX, y: mouthY)
        let fall = (pose.time * sweatFallsPerSecond).truncatingRemainder(dividingBy: 1)
        return MascotFace(
            eyes: [eye(pose, side: -1), eye(pose, side: 1)],
            brows: [brow(pose, side: -1), brow(pose, side: 1)],
            mouth: pose.mouth,
            mouthCenter: mouthCenter,
            mouthPath: mouthPath(pose.mouth, center: mouthCenter),
            sweatPath: pose.showsSweatDrop ? sweatPath(fall: fall) : [],
            sweatOpacity: pose.showsSweatDrop ? 1 - fall * sweatFadeAmount : 0
        )
    }

    // MARK: 身體

    /// 網頁版的 dirv：角度換成方向，0 度朝正下方，正的往畫面右邊轉。
    private static func direction(_ degrees: Double) -> MascotPoint {
        let radians = degrees * Double.pi / halfTurnDegrees
        return MascotPoint(x: sin(radians), y: cos(radians))
    }

    private static func offset(
        _ point: MascotPoint, _ toward: MascotPoint, _ length: Double
    ) -> MascotPoint {
        MascotPoint(x: point.x + toward.x * length, y: point.y + toward.y * length)
    }

    private static func moved(_ point: MascotPoint, x: Double, y: Double) -> MascotPoint {
        MascotPoint(x: point.x + x, y: point.y + y)
    }

    /// 一條腿的四個點：髖、膝、踝、腳尖。side 是 -1（左）或 1（右），腳尖朝外。
    private static func leg(
        from hip: MascotPoint, hipAngle: Double, kneeAngle: Double, side: Double
    ) -> [MascotPoint] {
        let knee = offset(hip, direction(hipAngle), MascotRig.thighLength)
        let ankle = offset(knee, direction(hipAngle + kneeAngle), MascotRig.shinLength)
        let toe = moved(ankle, x: side * MascotRig.footLength, y: MascotRig.footDrop)
        return [hip, knee, ankle, toe]
    }

    /// 一條手臂的三個點：肩、肘、手。
    private static func arm(
        from shoulder: MascotPoint, _ shoulderAngle: Double, _ elbowAngle: Double
    ) -> [MascotPoint] {
        let elbow = offset(shoulder, direction(shoulderAngle), MascotRig.upperArmLength)
        let hand = offset(elbow, direction(shoulderAngle + elbowAngle), MascotRig.forearmLength)
        return [shoulder, elbow, hand]
    }

    // MARK: 泡泡、Z、汗滴（各自的小動畫，數字照網頁版）

    private static let thoughtDotOffsetsX: [Double] = [-62, -74, -90]
    private static let thoughtDotOffsetsY: [Double] = [-108, -124, -144]
    private static let thoughtDotRadii: [Double] = [4, 5.5, 7.5]
    /// 圓點的不透明度在 0.35 到 1 之間輪流閃，後一個比前一個慢 0.9 弧度。
    private static let thoughtDotBaseOpacity = 0.35
    private static let thoughtDotPulseOpacity = 0.65
    private static let thoughtDotPulseSpeed: Double = 3
    private static let thoughtDotPhaseLag = 0.9
    /// 三個 Z 輪流從頭的右上方飄出去：一邊飄一邊變大，頭尾淡、中間最清楚。
    private static let sleepLetterCount = 3
    private static let sleepLetterSpeed = 0.45
    private static let sleepLetterStartX: Double = 70
    private static let sleepLetterDriftX: Double = 30
    private static let sleepLetterStartY: Double = -116
    private static let sleepLetterRiseY: Double = 44
    private static let sleepLetterBaseSize: Double = 11
    private static let sleepLetterGrowth: Double = 12
    /// 汗滴每秒往下滑 0.9 輪，一輪滑 6 格、淡掉六成。
    private static let sweatFallsPerSecond = 0.9
    private static let sweatFallDistance: Double = 6
    private static let sweatFadeAmount = 0.6
    private static let sweatTop = MascotPoint(x: -25, y: -72)

    private static func thoughtDots(above neck: MascotPoint, time: Double) -> [MascotMark] {
        var dots: [MascotMark] = []
        for index in thoughtDotRadii.indices {
            let phase = time * thoughtDotPulseSpeed - Double(index) * thoughtDotPhaseLag
            let center = moved(neck, x: thoughtDotOffsetsX[index], y: thoughtDotOffsetsY[index])
            let radius = thoughtDotRadii[index]
            let opacity = thoughtDotBaseOpacity + thoughtDotPulseOpacity * max(0, sin(phase))
            dots.append(MascotMark(position: center, size: radius, opacity: opacity))
        }
        return dots
    }

    private static func sleepLetters(above neck: MascotPoint, time: Double) -> [MascotMark] {
        var letters: [MascotMark] = []
        for index in 0..<sleepLetterCount {
            let started = time * sleepLetterSpeed + Double(index) / Double(sleepLetterCount)
            let phase = started.truncatingRemainder(dividingBy: 1)
            let x = neck.x + sleepLetterStartX + phase * sleepLetterDriftX
            let y = neck.y + sleepLetterStartY - phase * sleepLetterRiseY
            let size = sleepLetterBaseSize + phase * sleepLetterGrowth
            let position = MascotPoint(x: x, y: y)
            let opacity = sin(Double.pi * phase)
            letters.append(MascotMark(position: position, size: size, opacity: opacity))
        }
        return letters
    }

    /// 汗滴：水滴形，從 sweatTop 往下滑。網頁版是 M q-4,7 0,9 q4,-2 0,-9 Z。
    private static func sweatPath(fall: Double) -> [MascotPathStep] {
        let top = moved(sweatTop, x: 0, y: fall * sweatFallDistance)
        let bottom = moved(top, x: 0, y: 9)
        let left = MascotPathStep.quad(control: moved(top, x: -4, y: 7), end: bottom)
        let right = MascotPathStep.quad(control: moved(top, x: 4, y: 7), end: top)
        return [.move(top), left, right, .close]
    }

    // MARK: 五官

    private static func eye(_ pose: MascotPose, side: Double) -> MascotRect {
        let centerX = side * MascotHood.eyeSpacing + pose.lookX
        let centerY = MascotHood.eyeCenterY + pose.lookY
        let width = MascotHood.eyeWidth
        let height = max(MascotHood.minimumEyeHeight, pose.eyeHeight)
        return MascotRect(
            x: centerX - width / 2, y: centerY - height / 2, width: width, height: height
        )
    }

    /// 眉毛的兩個端點：先內側、再外側。
    private static func brow(_ pose: MascotPose, side: Double) -> [MascotPoint] {
        let centerX = side * MascotHood.browSpacing + pose.lookX * MascotHood.gazeFollow
        let lifted = MascotHood.browCenterY + pose.browOffsetY
        let centerY = lifted + pose.lookY * MascotHood.gazeFollow
        let radians = pose.browAngle * Double.pi / halfTurnDegrees
        let reach = side * MascotHood.browHalfLength * cos(radians)
        let rise = MascotHood.browHalfLength * sin(radians)
        let inner = MascotPoint(x: centerX - reach, y: centerY + rise)
        return [inner, MascotPoint(x: centerX + reach, y: centerY - rise)]
    }

    /// 嘴的路徑；小圓嘴不是路徑，回空的，畫面端在 mouthCenter 畫圓。
    /// 式子裡的數字就是網頁版 headSVG 那幾條嘴的路徑本身。
    private static func mouthPath(_ mouth: MascotMouth, center: MascotPoint) -> [MascotPathStep] {
        switch mouth {
        case .smile:
            let start = moved(center, x: -6, y: -1)
            let control = moved(center, x: 0, y: 5)
            return [.move(start), .quad(control: control, end: moved(center, x: 6, y: -1))]
        case .wavy:
            // 網頁版是 q3.5,-4 7,0 t7,0：第二段的控制點是第一段控制點對著接點的鏡射。
            let dip = MascotPathStep.quad(control: moved(center, x: -3.5, y: -4), end: center)
            let bump = MascotPathStep.quad(
                control: moved(center, x: 3.5, y: 4), end: moved(center, x: 7, y: 0)
            )
            return [.move(moved(center, x: -7, y: 0)), dip, bump]
        case .flat:
            return [.move(moved(center, x: -5, y: 0)), .line(moved(center, x: 5, y: 0))]
        case .round:
            return []
        }
    }
}
