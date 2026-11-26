import Foundation
import XCTest

@testable import RencanCore

// 量時間（2026-11-26 性能審查）：長期使用者的資料量下，算一份 Digest 要多久。
// 不設時間門檻，只印出來（檢查線紀錄裡搜「[perf]」），改前改後比數字。
// 資料：三年、3000 筆修煉（其中 500 筆沒帶體重快照）、200 筆量測。

private enum PerfData {
    static let liftCount = 3000
    static let liftsWithoutBodyweight = 500
    static let measurementCount = 200
    static let today = "2026-11-26"
    static let rounds = 5

    /// 從 2023-11-27 往後數 offset 天的日期字串。
    static func day(_ offset: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        let start = DateComponents(calendar: calendar, year: 2023, month: 11, day: 27).date
        let date = calendar.date(byAdding: .day, value: offset, to: start ?? Date()) ?? Date()
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }

    static func lifts() -> [LiftEntry] {
        let moves = MoveKey.allCases
        return (0..<liftCount).map { index in
            let move = moves[index % moves.count]
            let hasSnapshot = index >= liftsWithoutBodyweight
            return LiftEntry(
                id: "lift-\(index)", date: day(index * 1095 / liftCount), move: move,
                kg: 40 + Double(index % 60), reps: 5, sets: 3,
                bodyweightKg: hasSnapshot ? 72 : nil, createdAtMs: index
            )
        }
    }

    static func measurements() -> [MeasurementEntry] {
        (0..<measurementCount).map { index in
            MeasurementEntry(
                id: "m-\(index)", date: day(index * 1095 / measurementCount),
                weightKg: 72 + Double(index % 5) / 2, bodyFatPercent: 16 - Double(index % 4) / 2,
                createdAtMs: index
            )
        }
    }

    /// 跑 rounds 次取中位數，單位毫秒。
    static func medianMilliseconds(_ work: () throws -> Void) rethrows -> Double {
        let clock = ContinuousClock()
        var samples: [Double] = []
        for _ in 0..<rounds {
            let elapsed = try clock.measure(work)
            let parts = elapsed.components
            samples.append(Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15)
        }
        return samples.sorted()[rounds / 2]
    }
}

final class DigestPerformanceTests: XCTestCase {
    func test量一份Digest要多久() throws {
        let lifts = PerfData.lifts()
        let measurements = PerfData.measurements()
        var digest: Digest?
        let elapsed = try PerfData.medianMilliseconds {
            digest = try Digest(
                measurements: measurements, lifts: lifts, heightCm: 174, sex: .male,
                today: PerfData.today
            )
        }
        XCTAssertEqual(digest?.lifts.count, PerfData.liftCount)
        print(String(format: "[perf] Digest 3000 筆修煉、200 筆量測：%.1f ms", elapsed))
    }

    func test量全部都有體重快照時一份Digest要多久() throws {
        let lifts = PerfData.lifts().map { lift in
            LiftEntry(
                id: lift.id, date: lift.date, move: lift.move, kg: lift.kg, reps: lift.reps,
                sets: lift.sets, bodyweightKg: 72, createdAtMs: lift.createdAtMs
            )
        }
        let measurements = PerfData.measurements()
        let elapsed = try PerfData.medianMilliseconds {
            _ = try Digest(
                measurements: measurements, lifts: lifts, heightCm: 174, sex: .male,
                today: PerfData.today
            )
        }
        print(String(format: "[perf] Digest 全部有體重快照：%.1f ms", elapsed))
    }

    func test量小工具快照要多久() throws {
        let digest = try Digest(
            measurements: PerfData.measurements(), lifts: PerfData.lifts(), heightCm: 174,
            sex: .male, today: PerfData.today
        )
        let elapsed = try PerfData.medianMilliseconds {
            _ = try WidgetSnapshot(digest: digest, updatedAtMs: 0)
        }
        print(String(format: "[perf] 小工具快照（Digest 已算好）：%.1f ms", elapsed))
    }
}
