import XCTest
@testable import closeAllCore

final class SupportTests: XCTestCase {
    func testCopyReflectsTheQuitCount() {
        XCTAssertEqual(QuitCopy.buttonTitle(quitCount: 0), "Force Quit All")
        XCTAssertEqual(QuitCopy.buttonTitle(quitCount: 1), "Force Quit 1 App")
        XCTAssertEqual(QuitCopy.buttonTitle(quitCount: 4), "Force Quit 4 Apps")
        XCTAssertTrue(QuitCopy.statusLine(quitCount: 0).contains("Finder stays open"))
        XCTAssertTrue(QuitCopy.statusLine(quitCount: 2).contains("Unsaved changes"))
        XCTAssertEqual(QuitCopy.failureLine(failedCount: 1), "Could not force quit 1 app.")
        XCTAssertEqual(QuitCopy.failureLine(failedCount: 3), "Could not force quit 3 apps.")
    }

    func testKeptAppsStoreNormalizesAndSorts() {
        XCTAssertEqual(KeptAppsStore.load(from: nil), [])
        XCTAssertEqual(
            KeptAppsStore.load(from: [" COM.APPLE.SAFARI ", "", "   ", "com.apple.safari"]),
            ["com.apple.safari"]
        )
        XCTAssertEqual(
            KeptAppsStore.persistable(["B.App", " a.App ", ""]),
            ["a.app", "b.app"]
        )
        XCTAssertEqual(KeptAppsStore.defaultsKey, "keptBundleIdentifiers")
    }

    func testDryRunReportSplitsTargetsAndSkipped() throws {
        let snapshot = SessionSnapshot(
            apps: [
                runningApp("Finder", bundle: "com.apple.finder", pid: 1),
                runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
                runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
            ],
            exclusions: exclusions(ownPID: 42, ownBundle: nil)
        )
        let report = DryRunReport.make(snapshot)
        XCTAssertEqual(report.ownProcessIdentifier, 42)
        XCTAssertEqual(report.targets.map(\.name), ["Cursor", "Safari"])
        XCTAssertTrue(report.targets.allSatisfy { $0.reason == nil && $0.activationPolicy == "regular" })
        XCTAssertEqual(report.skipped.map(\.name), ["Finder"])
        XCTAssertEqual(report.skipped.first?.reason, SkipReason.protectedSystem.rawValue)
        XCTAssertTrue(report.protectedBundleIdentifiers.contains("com.apple.finder"))
        XCTAssertFalse(report.targets.map(\.processIdentifier).contains(42))

        let decoded = try JSONDecoder().decode(DryRunReport.self, from: Data(report.json().utf8))
        XCTAssertEqual(decoded, report)
        XCTAssertTrue(try report.json().contains("\"protectedSystem\""))
    }
}
