import XCTest
@testable import closeAllCore

final class TerminationGuardTests: XCTestCase {
    func testAllowsTheSameRegularApp() {
        let safari = runningApp("Safari", bundle: "com.apple.Safari", pid: 6)
        XCTAssertTrue(TerminationGuard.allow(safari, live: safari, exclusions: exclusions()))
    }

    func testRefusesProcessIdentifierReuse() {
        let requested = runningApp("Safari", bundle: "com.apple.Safari", pid: 6)
        let live = runningApp("Notes", bundle: "com.apple.Notes", pid: 6)
        XCTAssertFalse(TerminationGuard.allow(requested, live: live, exclusions: exclusions()))
    }

    func testRefusesWhenTheLiveProcessIsNoLongerRegular() {
        let requested = runningApp("Safari", bundle: "com.apple.Safari", pid: 6)
        let live = runningApp("Safari", bundle: "com.apple.Safari", pid: 6, policy: .accessory)
        XCTAssertFalse(TerminationGuard.allow(requested, live: live, exclusions: exclusions()))
    }

    func testRefusesFinderSelfAndKeptApps() {
        let finder = runningApp("Finder", bundle: "com.apple.finder", pid: 1)
        XCTAssertFalse(TerminationGuard.allow(finder, live: finder, exclusions: exclusions()))

        let itself = runningApp("closeAll", pid: 99)
        XCTAssertFalse(TerminationGuard.allow(itself, live: itself, exclusions: exclusions()))

        let cursor = runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5)
        let rules = exclusions(keptBundles: ["com.todesktop.230313mzl4w4u92"])
        XCTAssertFalse(TerminationGuard.allow(cursor, live: cursor, exclusions: rules))
    }

    func testRefusesAMismatchedProcessIdentifier() {
        let requested = runningApp("Safari", bundle: "com.apple.Safari", pid: 6)
        let live = runningApp("Safari", bundle: "com.apple.Safari", pid: 7)
        XCTAssertFalse(TerminationGuard.allow(requested, live: live, exclusions: exclusions()))
    }

    func testRefusesWhenABundledAppReplacesAnUnbundledPid() {
        let requested = runningApp("Untitled", pid: 12)
        let live = runningApp("Safari", bundle: "com.apple.Safari", pid: 12)
        XCTAssertFalse(TerminationGuard.allow(requested, live: live, exclusions: exclusions()))
    }

    func testRefusesATerminatedLiveProcess() {
        let requested = runningApp("Mail", bundle: "com.apple.mail", pid: 4)
        let live = runningApp("Mail", bundle: "com.apple.mail", pid: 4, terminated: true)
        XCTAssertFalse(TerminationGuard.allow(requested, live: live, exclusions: exclusions()))
    }

    func testAllowsMatchingAppsWithNoBundleIdentifier() {
        let app = runningApp("Untitled", pid: 12)
        XCTAssertTrue(TerminationGuard.allow(app, live: app, exclusions: exclusions()))
    }
}
