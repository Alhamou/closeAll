import XCTest
@testable import closeAllCore

final class SessionPresenterTests: XCTestCase {
    func testPresentsToggleableAppsAndMarksKeptOnes() {
        let snapshot = SessionSnapshot(
            apps: [
                runningApp("Finder", bundle: "com.apple.finder", pid: 1),
                runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
                runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
                menuBarApp("Amphetamine", bundle: "com.if.Amphetamine", pid: 8),
                runningApp("closeAll", bundle: "app.closeall.closeall", pid: 99),
            ],
            exclusions: exclusions(keptBundles: ["com.todesktop.230313mzl4w4u92"])
        )
        let rows = SessionPresenter.presentedApps(snapshot)
        XCTAssertEqual(rows.map(\.title), ["Cursor", "Safari", "Amphetamine"])
        XCTAssertEqual(rows.map(\.willQuit), [false, true, false])
        XCTAssertEqual(rows.map(\.group), [.dock, .dock, .background])
        XCTAssertEqual(rows.map(\.bundleIdentifier), [
            "com.todesktop.230313mzl4w4u92",
            "com.apple.safari",
            "com.if.amphetamine",
        ])
    }

    func testBackgroundAppsComeAfterDockAppsAndShowTheirChoice() {
        let snapshot = SessionSnapshot(
            apps: [
                runningApp("Zoom", bundle: "us.zoom.xos", pid: 3),
                menuBarApp("CopyClip", bundle: "com.fiplab.copyclip", pid: 4),
                menuBarApp("AmneziaWG", bundle: "org.amnezia.awg", pid: 5),
                runningApp("Siri", bundle: "com.apple.Siri", pid: 6, policy: .accessory),
                runningApp("Agent", bundle: "com.example.agent", pid: 7, policy: .prohibited),
                runningApp(
                    "Slack Helper", bundle: "com.tinyspeck.slackmacgap.helper", pid: 9, policy: .accessory,
                    path: "/Applications/Slack.app/Contents/Frameworks/Slack Helper.app"
                ),
            ],
            exclusions: exclusions(closedBackground: ["com.fiplab.copyclip"])
        )
        let rows = SessionPresenter.presentedApps(snapshot)
        XCTAssertEqual(rows.map(\.title), ["Zoom", "AmneziaWG", "CopyClip"])
        XCTAssertEqual(rows.map(\.group), [.dock, .background, .background])
        XCTAssertEqual(rows.map(\.willQuit), [true, false, true])
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
