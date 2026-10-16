import XCTest
@testable import closeAllCore

final class SessionPresenterTests: XCTestCase {
    func testPresentsToggleableAppsAndMarksKeptOnes() {
        let snapshot = SessionSnapshot(
            apps: [
                runningApp("Finder", bundle: "com.apple.finder", pid: 1),
                runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
                runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
                runningApp("Amphetamine", bundle: "com.if.Amphetamine", pid: 8, policy: .accessory),
                runningApp("closeAll", bundle: "app.closeall.closeall", pid: 99),
            ],
            exclusions: exclusions(keptBundles: ["com.todesktop.230313mzl4w4u92"])
        )
        let rows = SessionPresenter.presentedApps(snapshot)
        XCTAssertEqual(rows.map(\.title), ["Cursor", "Safari"])
        XCTAssertEqual(rows.map(\.willQuit), [false, true])
        XCTAssertEqual(rows.map(\.bundleIdentifier), [
            "com.todesktop.230313mzl4w4u92",
            "com.apple.safari",
        ])
    }

    func testDisambiguatesDuplicateNames() {
        let snapshot = SessionSnapshot(
            apps: [
                runningApp("Helper", bundle: "example.one", pid: 3),
                runningApp("Helper", bundle: "example.two", pid: 4),
                runningApp("  ", pid: 5),
                runningApp("  ", pid: 6),
            ],
            exclusions: exclusions()
        )
        let rows = SessionPresenter.presentedApps(snapshot)
        XCTAssertEqual(rows.map(\.title), [
            "App 5",
            "App 6",
            "Helper — example.one",
            "Helper — example.two",
        ])
    }

    func testUniqueNamesStayPlain() {
        let snapshot = SessionSnapshot(
            apps: [runningApp("Slack", bundle: "com.tinyspeck.slackmacgap", pid: 10)],
            exclusions: exclusions()
        )
        XCTAssertEqual(SessionPresenter.presentedApps(snapshot).map(\.title), ["Slack"])
    }
}
