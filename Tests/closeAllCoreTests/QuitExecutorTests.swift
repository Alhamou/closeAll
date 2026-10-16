import XCTest
@testable import closeAllCore

@MainActor
final class QuitExecutorTests: XCTestCase {
    func testForceQuitCallsOnlyPlannedTargetsInOrder() {
        let apps = [
            runningApp("Finder", bundle: "com.apple.finder", pid: 1),
            runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
            runningApp("Dock", bundle: "com.apple.dock", pid: 2, policy: .accessory),
            runningApp("closeAll", bundle: "app.closeall.closeall", pid: 99),
        ]
        var seen: [Int32] = []
        let result = QuitExecutor.forceQuit(apps: apps, exclusions: exclusions()) { app in
            seen.append(app.processIdentifier)
            return true
        }
        XCTAssertEqual(seen, [5, 6])
        XCTAssertEqual(result, QuitResult(started: [5, 6], failed: []))
    }

    func testForceQuitRecordsFailuresAndContinues() {
        let apps = [
            runningApp("Mail", bundle: "com.apple.mail", pid: 4),
            runningApp("Notes", bundle: "com.apple.Notes", pid: 7),
        ]
        let result = QuitExecutor.forceQuit(apps: apps, exclusions: exclusions()) { app in
            app.processIdentifier != 4
        }
        XCTAssertEqual(result.started, [7])
        XCTAssertEqual(result.failed, [4])
    }

    func testForceQuitDoesNothingForAnEmptyPlan() {
        var calls = 0
        let result = QuitExecutor.forceQuit(apps: [], exclusions: exclusions()) { _ in
            calls += 1
            return true
        }
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(result, QuitResult(started: [], failed: []))
    }

    func testKeptAppsAreNotTerminated() {
        let apps = [
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
            runningApp("Terminal", bundle: "com.apple.Terminal", pid: 8),
        ]
        let rules = exclusions(keptBundles: ["com.todesktop.230313mzl4w4u92"])
        var seen: [Int32] = []
        _ = QuitExecutor.forceQuit(apps: apps, exclusions: rules) { app in
            seen.append(app.processIdentifier)
            return true
        }
        XCTAssertEqual(seen, [8])
    }
}
