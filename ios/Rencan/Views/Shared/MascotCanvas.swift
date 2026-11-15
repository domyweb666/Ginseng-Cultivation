import RencanCore
import SwiftUI

/// 這個檔自己的常數。骨架長度、線寬、頭套的路徑都在 RencanCore 的 MascotRig、MascotHood，
/// 這裡只放畫面端才有的。
private enum Metrics {
    /// 粗細的下限（pt）。線寬照角色高度等比例縮，高 56 pt 時白臉的框、眉毛、嘴只剩 0.4 pt 上下，
    /// 不到一個實體像素，會被抹成一圈淡影。0.6 pt 在 2x 螢幕是 1.2 像素、3x 是 1.8 像素，
    /// 一定蓋得滿一個像素；再粗（0.75 pt）眉尾會黏到臉框。
    static let minimumThickness: CGFloat = 0.6
    /// 主體漸層的亮點與半徑（頭套座標）。預覽頁的漸層是主體外框的左 36%、上 34%、半徑 80%，
    /// 主體外框是 x −46 到 46、y −120 到 6。預覽頁的漸層是橢圓，這裡用圓，半徑取寬高各八成的平均。
    static let rootGlowCenter = MascotPoint(x: -13, y: -77)
    static let rootGlowRadius: Double = 87
    /// 打瞌睡的 Z：寬、高、筆畫粗細各是字級的幾成（照系統粗體字的比例）。
    static let letterWidth: Double = 0.62
    static let letterHeight: Double = 0.72
    static let letterLineWidth: Double = 0.16
}

/// 把某一刻的姿勢畫成圖（片 K2）。點位全部由 RencanCore 算好，這裡只照順序畫：
/// 影子、兩腿、身體、頭套與五官、兩臂、思考泡泡與 Z。後畫的蓋住先畫的，跟預覽頁的 SVG 同順序。
struct MascotCanvas: View {
    let pose: MascotPose

    var body: some View {
        Canvas { context, size in
            let palette = MascotPalette()
            let figure = MascotLayer(context: context, mapping: .fitting(size), palette: palette)
            let skeleton = Mascot.skeleton(for: pose)
            figure.drawLegsAndTorso(skeleton)
            figure.headLayer(skeleton).drawHood(face: Mascot.face(for: pose))
            figure.drawArmsAndMarks(skeleton)
        }
    }

    /// 高度定了，寬度照角色外框的比例算。
    static func width(forHeight height: CGFloat) -> CGFloat {
        height * CGFloat(MascotRig.frameWidth / MascotRig.frameHeight)
    }
}

/// 各部位用哪個設計代號。身體線條、泡泡與 Z、影子在預覽頁剛好就是 strong、accent、shadow，
/// 深淺色跟著系統切。頭套在預覽頁不分深淺色都是同一組色，所以用色票裡 mascot 開頭的固定色
/// （深淺同值，色碼抄頭套預覽頁），不用會跟著深色模式翻的代號，白臉才不會變黑臉。
struct MascotPalette {
    let limb = Color.rencan.strong
    let mark = Color.rencan.accent
    let shadow = Color.rencan.shadow
    /// 五官與白臉的框。onBright 深淺色同一個值，不必固定。
    let ink = Color.rencan.onBright
    /// 主體漸層的外緣。bright 深淺色同一個值，不必固定。
    let rootEdge = Color.rencan.bright
    // 頭套不分深淺色都是同一組顏色（照頭套預覽頁），用色票裡深淺同值的那幾個。
    let rootGlow = Color.rencan.mascotGlow
    /// 鬚根、主體的框、環紋、白臉外圈。
    let rim = Color.rencan.mascotRim
    /// 梗與葉。
    let leaf = Color.rencan.mascotLeaf
    let vein = Color.rencan.mascotVein
    let berry = Color.rencan.mascotBerry
    /// 白臉、紅果的亮點、主體的反光。
    let white = Color.rencan.mascotWhite
    let sweat = Color.rencan.mascotSweat
}

/// 角色座標（預覽頁 SVG 的一格）換成畫布上的點：乘一個 scale、加一個 offset。
struct MascotMapping {
    let scale: CGFloat
    let offset: CGPoint

    /// 把 MascotRig 的角色外框等比例放進畫布、置中（跟 SVG viewBox 的預設行為一樣）。
    static func fitting(_ size: CGSize) -> MascotMapping {
        let frameWidth = CGFloat(MascotRig.frameWidth)
        let frameHeight = CGFloat(MascotRig.frameHeight)
        let scale = min(size.width / frameWidth, size.height / frameHeight)
        let left = (size.width - frameWidth * scale) / 2 - CGFloat(MascotRig.frameX) * scale
        let top = (size.height - frameHeight * scale) / 2 - CGFloat(MascotRig.frameY) * scale
        return MascotMapping(scale: scale, offset: CGPoint(x: left, y: top))
    }

    func spot(_ point: MascotPoint) -> CGPoint {
        CGPoint(x: offset.x + CGFloat(point.x) * scale, y: offset.y + CGFloat(point.y) * scale)
    }

    func length(_ value: Double) -> CGFloat {
        CGFloat(value) * scale
    }

    /// 線寬與眼睛的粗細：照比例縮，但不低於下限。
    func thickness(_ value: Double) -> CGFloat {
        max(Metrics.minimumThickness, length(value))
    }

    /// 路徑表（SVG 的 M、L、Q、C、Z）轉成 SwiftUI 的 Path。
    func path(_ steps: [MascotPathStep]) -> Path {
        var path = Path()
        for step in steps {
            switch step {
            case .move(let point):
                path.move(to: spot(point))
            case .line(let point):
                path.addLine(to: spot(point))
            case .quad(let control, let end):
                path.addQuadCurve(to: spot(end), control: spot(control))
            case .curve(let control1, let control2, let end):
                path.addCurve(to: spot(end), control1: spot(control1), control2: spot(control2))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }

    /// 橢圓；兩個半徑一樣就是圓。
    func oval(center: MascotPoint, radiusX: Double, radiusY: Double) -> Path {
        let middle = spot(center)
        let reachX = length(radiusX)
        let reachY = length(radiusY)
        let corner = CGPoint(x: middle.x - reachX, y: middle.y - reachY)
        let box = CGRect(origin: corner, size: CGSize(width: reachX * 2, height: reachY * 2))
        return Path(ellipseIn: box)
    }
}

/// 一層畫布：畫在哪、座標怎麼換、用什麼顏色。整個角色一層；頭套另一層，先平移旋轉過。
struct MascotLayer {
    let context: GraphicsContext
    let mapping: MascotMapping
    let palette: MascotPalette

    /// 描一條線。線頭與轉角都是圓的（預覽頁每條線都是圓頭）。
    func stroke(_ line: MascotStroke, _ color: Color) {
        strokePath(mapping.path(line.steps), color.opacity(line.opacity), width: line.width)
    }

    func strokePath(_ path: Path, _ color: Color, width: Double) {
        let style = StrokeStyle(
            lineWidth: mapping.thickness(width), lineCap: .round, lineJoin: .round
        )
        context.stroke(path, with: .color(color), style: style)
    }

    /// 把幾個點連成折線來描（腿、身體、手臂、眉毛）。
    func strokeLine(through points: [MascotPoint], _ color: Color, width: Double) {
        guard let first = points.first else { return }
        var steps = [MascotPathStep.move(first)]
        steps += points.dropFirst().map { MascotPathStep.line($0) }
        stroke(MascotStroke(steps: steps, width: width), color)
    }

    func fill(_ steps: [MascotPathStep], _ color: Color) {
        context.fill(mapping.path(steps), with: .color(color))
    }

    func fillCircle(_ center: MascotPoint, radius: Double, _ color: Color) {
        let circle = mapping.oval(center: center, radiusX: radius, radiusY: radius)
        context.fill(circle, with: .color(color))
    }
}

// MARK: 身體

extension MascotLayer {
    /// 影子、兩腿、身體。
    func drawLegsAndTorso(_ skeleton: MascotSkeleton) {
        let shadow = mapping.oval(
            center: skeleton.shadowCenter, radiusX: MascotRig.shadowRadiusX,
            radiusY: MascotRig.shadowRadiusY
        )
        context.fill(shadow, with: .color(palette.shadow.opacity(MascotRig.shadowOpacity)))
        for limb in skeleton.legs + [skeleton.torso] {
            strokeLine(through: limb, palette.limb, width: MascotRig.bodyLineWidth)
        }
    }

    /// 兩臂（蓋在頭套上面）、思考泡泡、打瞌睡的 Z。
    func drawArmsAndMarks(_ skeleton: MascotSkeleton) {
        for arm in skeleton.arms {
            strokeLine(through: arm, palette.limb, width: MascotRig.armLineWidth)
        }
        for dot in skeleton.thoughtDots {
            fillCircle(dot.position, radius: dot.size, palette.mark.opacity(dot.opacity))
        }
        for letter in skeleton.sleepLetters {
            stroke(sleepLetter(letter), palette.mark)
        }
    }

    /// Z 用三筆畫出來，不用文字：字體只准從 RencanType 取，那裡沒有這種跟著角色縮放的字。
    /// mark 的 position 是字的左下角（SVG 文字的基準點），size 是字級。
    private func sleepLetter(_ mark: MascotMark) -> MascotStroke {
        let lineWidth = mark.size * Metrics.letterLineWidth
        let left = mark.position.x + lineWidth / 2
        let right = mark.position.x + mark.size * Metrics.letterWidth - lineWidth / 2
        let bottom = mark.position.y - lineWidth / 2
        let top = mark.position.y - mark.size * Metrics.letterHeight + lineWidth / 2
        let upperLeft = MascotPathStep.move(MascotPoint(x: left, y: top))
        let upperRight = MascotPathStep.line(MascotPoint(x: right, y: top))
        let lowerLeft = MascotPathStep.line(MascotPoint(x: left, y: bottom))
        let lowerRight = MascotPathStep.line(MascotPoint(x: right, y: bottom))
        let steps = [upperLeft, upperRight, lowerLeft, lowerRight]
        return MascotStroke(steps: steps, width: lineWidth, opacity: mark.opacity)
    }
}

// MARK: 頭套

extension MascotLayer {
    /// 頭套那一層：原點移到脖子頂端、照頭的角度轉，之後直接用 MascotHood、MascotFace 的座標畫。
    func headLayer(_ skeleton: MascotSkeleton) -> MascotLayer {
        var turned = context
        let origin = mapping.spot(skeleton.headOrigin)
        turned.translateBy(x: origin.x, y: origin.y)
        turned.rotate(by: .degrees(skeleton.headRotationDegrees))
        let local = MascotMapping(scale: mapping.scale, offset: .zero)
        return MascotLayer(context: turned, mapping: local, palette: palette)
    }

    /// 照 MascotHood 由上往下的順序畫，最後畫五官。
    func drawHood(face: MascotFace) {
        drawCrown()
        drawRoot()
        drawFacePlate()
        drawFeatures(face)
    }

    /// 鬚根、梗、葉、葉脈、紅果。
    private func drawCrown() {
        for whisker in MascotHood.whiskers {
            stroke(whisker, palette.rim)
        }
        stroke(MascotHood.stem, palette.leaf)
        for leaf in MascotHood.leaves {
            fill(leaf, palette.leaf)
        }
        for vein in MascotHood.leafVeins {
            stroke(vein, palette.vein)
        }
        let shineColor = palette.white.opacity(MascotHood.berryShineOpacity)
        for center in MascotHood.berryCenters {
            let shift = MascotHood.berryShineOffset
            let shine = MascotPoint(x: center.x + shift, y: center.y + shift)
            fillCircle(center, radius: MascotHood.berryRadius, palette.berry)
            fillCircle(shine, radius: MascotHood.berryShineRadius, shineColor)
        }
    }

    /// 主體（漸層填色加描邊）、反光、環紋。
    private func drawRoot() {
        let outline = mapping.path(MascotHood.body)
        let gradient = Gradient(colors: [palette.rootGlow, palette.rootEdge])
        let shading = GraphicsContext.Shading.radialGradient(
            gradient, center: mapping.spot(Metrics.rootGlowCenter), startRadius: 0,
            endRadius: mapping.length(Metrics.rootGlowRadius)
        )
        context.fill(outline, with: shading)
        strokePath(outline, palette.rim, width: MascotHood.bodyOutlineWidth)
        stroke(MascotHood.bodyShine, palette.white)
        for ring in MascotHood.rings {
            stroke(ring, palette.rim)
        }
    }

    /// 白臉：先畫外圈，再畫白臉與它的框。
    private func drawFacePlate() {
        let center = MascotHood.faceCenter
        let radius = MascotHood.faceRadius
        fillCircle(center, radius: MascotHood.faceRimRadius, palette.rim)
        fillCircle(center, radius: radius, palette.white)
        let outline = mapping.oval(center: center, radiusX: radius, radiusY: radius)
        strokePath(outline, palette.ink, width: MascotHood.faceOutlineWidth)
    }

    /// 眼睛、眉毛、嘴、汗滴。
    private func drawFeatures(_ face: MascotFace) {
        for eye in face.eyes {
            context.fill(eyePath(eye), with: .color(palette.ink))
        }
        for brow in face.brows {
            strokeLine(through: brow, palette.ink, width: MascotHood.browLineWidth)
        }
        if face.mouth == .round {
            let radius = MascotHood.mouthRoundRadius
            let ring = mapping.oval(center: face.mouthCenter, radiusX: radius, radiusY: radius)
            strokePath(ring, palette.ink, width: MascotHood.mouthRoundLineWidth)
        } else {
            let mouth = MascotStroke(steps: face.mouthPath, width: MascotHood.mouthLineWidth)
            stroke(mouth, palette.ink)
        }
        fill(face.sweatPath, palette.sweat.opacity(face.sweatOpacity))
    }

    /// 眼睛是圓角長方形，圓角半徑是寬的一半；比寬還矮時（打瞌睡）照 SVG 的規則就是一個橢圓。
    /// 寬高都守粗細的下限，不然高 56 pt 時瞇起來的眼睛薄到看不見。
    private func eyePath(_ eye: MascotRect) -> Path {
        let width = mapping.thickness(eye.width)
        let height = mapping.thickness(eye.height)
        let center = mapping.spot(MascotPoint(x: eye.x + eye.width / 2, y: eye.y + eye.height / 2))
        let corner = CGPoint(x: center.x - width / 2, y: center.y - height / 2)
        let box = CGRect(origin: corner, size: CGSize(width: width, height: height))
        guard height > width else { return Path(ellipseIn: box) }
        return Path(roundedRect: box, cornerRadius: width / 2)
    }
}
