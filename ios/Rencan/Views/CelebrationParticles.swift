import SwiftUI

/// 粒子的數值，照網頁版 index.html 的 burst。網頁版一幀動一次，所以速度、重力都是「每幀」的量。
private enum Metrics {
    /// 網頁版用 requestAnimationFrame，一秒 60 幀；經過的秒數乘這個換成幀數
    static let framesPerSecond: Double = 60
    /// 噴發點在畫面高度的幾成（左右在正中）
    static let originY: Double = 0.42
    /// 初速（每幀幾點）：最小值與亂數範圍
    static let minSpeed: Double = 2
    static let speedRange: Double = 7
    /// 一開始往上多推的速度
    static let lift: Double = 2.5
    /// 每幀往下加的速度
    static let gravity: Double = 0.13
    /// 每幀水平速度剩幾成
    static let drag: Double = 0.985
    /// 每幀淡掉多少，淡到 0 就消失（大約 1.5 秒）
    static let fadePerFrame: Double = 0.011
    /// 半徑：最小值與亂數範圍
    static let minRadius: Double = 1.5
    static let radiusRange: Double = 3
    /// 每幾顆有一顆用第二色
    static let secondColorEvery = 3
    /// 粒子數超過這個數（大境界突破），隔幾幀再補一波半數的
    static let secondWaveOver = 150
    static let secondWaveDelay: Double = 24
    /// 種子固定：每次慶祝飛散的樣子都一樣，出問題時重現得出來
    static let seed: UInt64 = 20_261_115
    /// SplitMix64 演算法的常數
    static let mixStep: UInt64 = 0x9E37_79B9_7F4A_7C15
    static let mixFirst: UInt64 = 0xBF58_476D_1CE4_E5B9
    static let mixSecond: UInt64 = 0x94D0_49BB_1331_11EB
    static let mixShiftFirst: UInt64 = 30
    static let mixShiftSecond: UInt64 = 27
    static let mixShiftLast: UInt64 = 31
}

/// 帶種子的小型亂數產生器（SplitMix64）。同一個種子每次吐出同一串數字。
struct CelebrationRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= Metrics.mixStep
        var mixed = state
        mixed = (mixed ^ (mixed >> Metrics.mixShiftFirst)) &* Metrics.mixFirst
        mixed = (mixed ^ (mixed >> Metrics.mixShiftSecond)) &* Metrics.mixSecond
        return mixed ^ (mixed >> Metrics.mixShiftLast)
    }
}

/// 某一幀要畫的一個圓點。
struct CelebrationDot {
    let rect: CGRect
    let opacity: Double
}

/// 一顆粒子出生時抽好的數值。之後每一幀的位置都由這些算出來，不再抽亂數。
struct CelebrationParticle {
    /// 初速（每幀幾點）
    let velocityX: Double
    let velocityY: Double
    let radius: Double
    /// 網頁版每三顆有一顆翠色，這裡照做（色票的 sparkJade）
    let usesSecondColor: Bool
    /// 等幾幀才噴出來（第二波用）
    let delay: Double

    /// 第幾幀的位置與透明度；還沒噴出來或已經淡完回 nil。
    func dot(frame: Double, in size: CGSize) -> CelebrationDot? {
        let age = frame - delay
        let life = 1 - Metrics.fadePerFrame * age
        guard age >= 0, life > 0 else { return nil }
        // 網頁版每幀 x += vx、vx *= drag，累加起來是等比級數
        let travel = (1 - pow(Metrics.drag, age)) / (1 - Metrics.drag)
        // 網頁版每幀 y += vy、vy += gravity，累加起來是等差級數
        let fall = Metrics.gravity * age * (age - 1) / 2
        let x = Double(size.width) / 2 + velocityX * travel
        let y = Double(size.height) * Metrics.originY + velocityY * age + fall
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        return CelebrationDot(rect: rect, opacity: life)
    }
}

/// 一次慶祝的整批粒子，加上開始噴的時間。
struct CelebrationBurst {
    let particles: [CelebrationParticle]
    let start: Date

    /// count 給 Celebration.particleCount。
    init(count: Int, start: Date) {
        var random = CelebrationRandom(seed: Metrics.seed)
        var batch = Self.wave(count: count, delay: 0, random: &random)
        if count > Metrics.secondWaveOver {
            let extra = Int((Double(count) / 2).rounded())
            batch += Self.wave(count: extra, delay: Metrics.secondWaveDelay, random: &random)
        }
        particles = batch
        self.start = start
    }

    /// 最後一顆淡完是開始後幾秒：最晚噴的那波加上一顆粒子的壽命。
    var duration: Double {
        let lastDelay = particles.map(\.delay).max() ?? 0
        return (lastDelay + 1 / Metrics.fadePerFrame) / Metrics.framesPerSecond
    }

    /// 一波粒子：方向繞一圈平均抽，速度與大小在範圍內抽。
    private static func wave(
        count: Int, delay: Double, random: inout CelebrationRandom
    ) -> [CelebrationParticle] {
        var batch: [CelebrationParticle] = []
        for index in 0..<max(0, count) {
            let angle = unit(&random) * 2 * Double.pi
            let speed = Metrics.minSpeed + unit(&random) * Metrics.speedRange
            let radius = Metrics.minRadius + unit(&random) * Metrics.radiusRange
            let particle = CelebrationParticle(
                velocityX: cos(angle) * speed, velocityY: sin(angle) * speed - Metrics.lift,
                radius: radius, usesSecondColor: index % Metrics.secondColorEvery == 0,
                delay: delay
            )
            batch.append(particle)
        }
        return batch
    }

    /// 0 到 1 之間的亂數。
    private static func unit(_ random: inout CelebrationRandom) -> Double {
        Double.random(in: 0..<1, using: &random)
    }
}

/// 把一批粒子畫出來。位置只跟「過了多久」有關，每一幀重算，不存狀態。
/// 最後一顆淡完（約 1.9 秒）就把整塊拿掉，不再每幀重畫到慶祝關掉（2026-11-26 性能審查）。
struct CelebrationParticlesView: View {
    let burst: CelebrationBurst
    /// 粒子全部淡完了
    @State private var isFinished = false

    var body: some View {
        Group {
            if !isFinished {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(burst.start)
                    let frame = elapsed * Metrics.framesPerSecond
                    Canvas { context, size in
                        for particle in burst.particles {
                            guard let dot = particle.dot(frame: frame, in: size) else { continue }
                            context.opacity = dot.opacity
                            context.fill(
                                Path(ellipseIn: dot.rect), with: .color(color(of: particle))
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: burst.start) {
            isFinished = false
            let remaining = burst.duration - Date().timeIntervalSince(burst.start)
            guard await Task.pause(seconds: max(0, remaining)) else { return }
            isFinished = true
        }
    }

    private func color(of particle: CelebrationParticle) -> Color {
        particle.usesSecondColor ? Color.rencan.sparkJade : Color.rencan.bright
    }
}
