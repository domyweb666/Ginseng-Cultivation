import XCTest

/// 量時間（2026-11-26 性能審查）：塞三年 3000 筆修煉（-rencanSeed heavy），量幾個常做的動作要多久。
/// 不設門檻，只記下來：印在紀錄裡（搜「[perf]」），也寫進截圖資料夾的 perf.txt，改前改後比數字。
/// XCUITest 每個動作前會等 app 閒下來，所以量到的時間包含主執行緒忙著重算的那段。
final class PerfUITests: RencanUITestCase {
    private var lines: [String] = []

    func test三千筆紀錄量開app回前景切頁按住與打字() {
        let launchSeconds = seconds {
            launch(["-rencanSeed", "heavy"])
            seeStele(timeout: 120)
        }
        note("開 app 到看見境界碑", launchSeconds)
        measureForeground()
        measureGongSegment()
        measureLiftFormHold()
        measureHeightHold()
        measureDaoNameTyping()
        writeReport()
    }

    // MARK: 各個動作

    /// 回主畫面再切回來三次，取中位數。
    private func measureForeground() {
        var samples: [Double] = []
        for _ in 0..<3 {
            XCUIDevice.shared.press(.home)
            _ = waitUntil(timeout: 10) { app.state == .runningBackground }
            samples.append(seconds {
                app.activate()
                seeStele(timeout: 60)
            })
        }
        note("回前景到看見境界碑（三次中位數）", samples.sorted()[1])
    }

    private func measureGongSegment() {
        openTab("分析")
        let elapsed = seconds {
            tapVisibleButton("功法", timeout: 60)
            seeText("功法雷達", timeout: 60)
        }
        note("分析頁點「功法」到看見雷達", elapsed)
        openTab("境界")
        seeStele(timeout: 60)
    }

    /// 按住「次數加一」1.5 秒，看走到幾。主執行緒越忙，走得越少。
    private func measureLiftFormHold() {
        let elapsed = seconds {
            tapVisibleButton("記一筆修煉", timeout: 60)
            require(app.buttons["記下"], "記一筆表單的「記下」按鈕", timeout: 60)
        }
        note("點「記一筆修煉」到表單出現", elapsed)
        app.buttons["次數加一"].press(forDuration: 1.5)
        let reps = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "次數 "))
        let count = Int(reps.firstMatch.label.dropFirst(3)) ?? 0
        lines.append("[perf] 按住「次數加一」1.5 秒走到：\(count)")
        shot("量時間-按住次數")
        tapButton("取消")
        seeStele(timeout: 60)
    }

    /// 設定頁按住「身高加一公分」1.5 秒，看走了幾公分、按完多久畫面才閒下來。
    private func measureHeightHold() {
        openTab("設定")
        seeText("身體", timeout: 60)
        let plus = app.buttons["身高加一公分"].firstMatch
        let elapsed = seconds {
            plus.press(forDuration: 1.5)
            _ = app.staticTexts.firstMatch.exists
        }
        let query = app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES %@", "1[0-9]{2}[^0-9]*公分")
        )
        let text = requireVisible(query, "身高的數字", timeout: 60).label
        let height = Int(text.prefix(3)) ?? 0
        lines.append("[perf] 按住「身高加一公分」1.5 秒走了：\(height - 174) 公分")
        note("按住身高 1.5 秒到畫面閒下來", elapsed)
        shot("量時間-按住身高")
        openTab("境界")
        seeStele(timeout: 60)
    }

    /// 修煉卡頁打八個英文字的道號。每打一個字都會重畫卡片。
    private func measureDaoNameTyping() {
        let open = app.buttons.matching(identifier: "share-card-open")
        requireVisible(open, "頁首的分享圖示", timeout: 60).tap()
        let field = requireVisible(
            app.textFields.matching(identifier: "share-card-dao-name"), "道號那一欄", timeout: 60
        )
        field.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        let elapsed = seconds { field.typeText("DomyDomy") }
        note("修煉卡打八個字的道號", elapsed)
        shot("量時間-打道號")
    }

    // MARK: 記錄

    private func seconds(_ work: () -> Void) -> Double {
        let start = Date()
        work()
        return Date().timeIntervalSince(start)
    }

    private func note(_ what: String, _ elapsed: Double) {
        lines.append(String(format: "[perf] %@：%.2f 秒", what, elapsed))
    }

    private func writeReport() {
        let text = lines.joined(separator: "\n")
        print(text)
        let attachment = XCTAttachment(string: text)
        attachment.name = "perf"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["RENCAN_SCREENSHOT_DIR"], !dir.isEmpty
        else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("perf.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("perf.txt 寫不進 \(dir)：\(error)")
        }
    }
}
