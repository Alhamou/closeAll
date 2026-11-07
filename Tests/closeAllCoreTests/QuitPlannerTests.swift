import XCTest
@testable import closeAllCore

func runningApp(
    _ name: String,
    bundle: String? = nil,
    pid: Int32,
    policy: ActivationPolicy = .regular,
    terminated: Bool = false,
    path: String? = nil
) -> RunningApp {
    RunningApp(
        bundleIdentifier: bundle,
        localizedName: name,
        processIdentifier: pid,
        activationPolicy: policy,
        isTerminated: terminated,
        bundlePath: path
    )
}

/// A menu-bar app installed as `/Applications/<name>.app`.
func menuBarApp(_ name: String, bundle: String, pid: Int32) -> RunningApp {
    runningApp(name, bundle: bundle, pid: pid, policy: .accessory, path: "/Applications/\(name).app")
}

func exclusions(
    ownPID: Int32 = 99,
    ownBundle: String? = "app.closeall.closeall",
    keptBundles: Set<String> = [],
    keptPIDs: Set<Int32> = [],
    closedBackground: Set<String> = []
) -> QuitExclusions {
    QuitExclusions(
        ownProcessIdentifier: ownPID,
        ownBundleIdentifier: ownBundle,
        keptBundleIdentifiers: keptBundles,
        keptProcessIdentifiers: keptPIDs,
        closedBackgroundBundleIdentifiers: closedBackground
    )
}

final class QuitPlannerTests: XCTestCase {
    func testEmptySessionHasNoTargets() {
        XCTAssertEqual(QuitPlanner.targets(for: [], exclusions: exclusions()), [])
    }

    func testRegularDockAppsAreTargets() {
        let apps = [
            runningApp("Safari", bundle: "com.apple.Safari", pid: 2),
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 3),
        ]
        XCTAssertEqual(
            QuitPlanner.targets(for: apps, exclusions: exclusions()).map(\.localizedName),
            ["Cursor", "Safari"]
        )
    }

    func testFinderIsProtectedEvenWithOddCasing() {
        let finder = runningApp("Finder", bundle: "  COM.APPLE.FINDER  ", pid: 1)
        XCTAssertEqual(
            QuitPlanner.skipReason(for: finder, exclusions: exclusions()),
            .protectedSystem
        )
        XCTAssertFalse(QuitPlanner.willQuit(finder, exclusions: exclusions()))
        XCTAssertFalse(QuitPlanner.isToggleable(finder, exclusions: exclusions()))
    }

    func testSessionProcessesAreProtectedWhenReportedAsRegularApps() {
        for bundle in SystemProtection.bundleIdentifiers {
            let app = runningApp(bundle, bundle: bundle, pid: 50, policy: .regular)
            XCTAssertEqual(
                QuitPlanner.skipReason(for: app, exclusions: exclusions()),
                .protectedSystem,
                bundle
            )
        }
    }

    func testDockHelpersAreProtectedByPrefix() {
        let extra = runningApp(
            "Dock Extra",
            bundle: "com.apple.dock.external.extra.arm64",
            pid: 7,
            policy: .accessory
        )
        XCTAssertEqual(QuitPlanner.skipReason(for: extra, exclusions: exclusions()), .protectedSystem)
    }

    func testOtherAppleAppsSuchAsSafariAreNotProtected() {
        XCTAssertFalse(SystemProtection.isProtected("com.apple.Safari"))
        XCTAssertFalse(SystemProtection.isProtected("com.apple.Terminal"))
        XCTAssertFalse(SystemProtection.isProtected("com.apple.iCal"))
        let safari = runningApp("Safari", bundle: "com.apple.Safari", pid: 8)
        XCTAssertTrue(QuitPlanner.willQuit(safari, exclusions: exclusions()))
    }

    func testBackgroundAppsStayOpenUntilChosen() {
        let menuBar = menuBarApp("Amphetamine", bundle: "com.if.Amphetamine", pid: 4)
        let agent = runningApp("chronod", bundle: "com.apple.chronod", pid: 5, policy: .prohibited)
        XCTAssertEqual(QuitPlanner.skipReason(for: menuBar, exclusions: exclusions()), .backgroundNotChosen)
        XCTAssertEqual(QuitPlanner.group(for: menuBar, exclusions: exclusions()), .background)
        XCTAssertTrue(QuitPlanner.isToggleable(menuBar, exclusions: exclusions()))
        XCTAssertEqual(QuitPlanner.skipReason(for: agent, exclusions: exclusions()), .notRegularApp)
        XCTAssertNil(QuitPlanner.group(for: agent, exclusions: exclusions()))
    }

    func testChosenBackgroundAppIsATargetIgnoringCase() {
        let menuBar = menuBarApp("Amphetamine", bundle: "com.if.Amphetamine", pid: 4)
        let rules = exclusions(closedBackground: [" COM.IF.AMPHETAMINE "])
        XCTAssertNil(QuitPlanner.skipReason(for: menuBar, exclusions: rules))
        XCTAssertEqual(QuitPlanner.targets(for: [menuBar], exclusions: rules), [menuBar])
    }

    func testAppleAndUnknownBackgroundProcessesStayHiddenEvenIfChosen() {
        let appleAgent = runningApp(
            "Siri", bundle: "com.apple.Siri", pid: 20, policy: .accessory,
            path: "/System/Applications/Siri.app"
        )
        let unknown = runningApp("helper", pid: 21, policy: .accessory, path: "/Applications/helper.app")
        let uiless = runningApp("Sync", bundle: "com.example.sync", pid: 22, policy: .prohibited, path: "/Applications/Sync.app")
        let noPath = runningApp("Mystery", bundle: "com.example.mystery", pid: 25, policy: .accessory)
        let helper = runningApp(
            "Slack Helper", bundle: "com.tinyspeck.slackmacgap.helper", pid: 26, policy: .accessory,
            path: "/Applications/Slack.app/Contents/Frameworks/Slack Helper.app"
        )
        let updater = runningApp(
            "Updater", bundle: "com.example.updater", pid: 27, policy: .accessory,
            path: "/Library/Application Support/Example/Updater.app"
        )
        let rules = exclusions(closedBackground: [
            "com.apple.siri", "com.example.sync", "com.example.mystery",
            "com.tinyspeck.slackmacgap.helper", "com.example.updater",
        ])
        for app in [appleAgent, unknown, uiless, noPath, helper, updater] {
            XCTAssertEqual(QuitPlanner.skipReason(for: app, exclusions: rules), .notRegularApp, app.localizedName)
            XCTAssertNil(QuitPlanner.group(for: app, exclusions: rules), app.localizedName)
        }
    }

    func testProtectedAndSelfNeverBecomeBackgroundTargets() {
        let controlCenter = runningApp("Control Center", bundle: "com.apple.controlcenter", pid: 23, policy: .accessory)
        let itself = menuBarApp("closeAll", bundle: "app.closeall.closeAll", pid: 24)
        let rules = exclusions(closedBackground: ["com.apple.controlcenter", "app.closeall.closeall"])
        XCTAssertEqual(QuitPlanner.skipReason(for: controlCenter, exclusions: rules), .protectedSystem)
        XCTAssertEqual(QuitPlanner.skipReason(for: itself, exclusions: rules), .thisApp)
        XCTAssertNil(QuitPlanner.group(for: controlCenter, exclusions: rules))
        XCTAssertNil(QuitPlanner.group(for: itself, exclusions: rules))
    }

    func testAnotherCopyOfCloseAllIsSkippedWhenThisProcessIsUnbundled() {
        let installed = menuBarApp("closeAll", bundle: "app.closeall.closeAll", pid: 24)
        let rules = exclusions(ownBundle: nil, closedBackground: ["app.closeall.closeall"])
        XCTAssertEqual(QuitPlanner.skipReason(for: installed, exclusions: rules), .thisApp)
    }

    func testOnlyStandaloneAppsInAnApplicationsFolderCount() {
        XCTAssertTrue(QuitPlanner.isInstalledStandaloneApp("/Applications/CopyClip.app"))
        XCTAssertTrue(QuitPlanner.isInstalledStandaloneApp("/Applications/Setapp/Haki.app"))
        XCTAssertTrue(QuitPlanner.isInstalledStandaloneApp("/Users/emad/Applications/OpenBlock.app"))
        XCTAssertTrue(QuitPlanner.isInstalledStandaloneApp("/Applications/AmneziaWG.APP/"))

        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp(nil))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp(""))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp("/Applications/Slack.app/Contents/Frameworks/Slack Helper.app"))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp("/Applications/Microsoft Teams.app/Contents/Helpers/Teams WebView.app"))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp("/Library/Application Support/Example/Updater.app"))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp("/Users/emad/Library/Application Support/ChatGPT/Computer Use.app"))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp("/Users/emad/Downloads/Tool.app"))
        XCTAssertFalse(QuitPlanner.isInstalledStandaloneApp("/Applications/zcode-cli"))
    }

    func testKeepingWinsOverAChosenBackgroundApp() {
        let menuBar = menuBarApp("Amphetamine", bundle: "com.if.Amphetamine", pid: 4)
        let rules = exclusions(keptBundles: ["com.if.amphetamine"], closedBackground: ["com.if.amphetamine"])
        XCTAssertEqual(QuitPlanner.skipReason(for: menuBar, exclusions: rules), .keptByUser)
    }

    func testDockAppIgnoresTheBackgroundList() {
        let slack = runningApp("Slack", bundle: "com.tinyspeck.slackmacgap", pid: 30)
        XCTAssertEqual(QuitPlanner.group(for: slack, exclusions: exclusions()), .dock)
        XCTAssertNil(QuitPlanner.skipReason(for: slack, exclusions: exclusions()))
        let rules = exclusions(keptBundles: ["com.tinyspeck.slackmacgap"], closedBackground: ["com.tinyspeck.slackmacgap"])
        XCTAssertEqual(QuitPlanner.skipReason(for: slack, exclusions: rules), .keptByUser)
    }

    func testSelfIsSkippedByProcessIdentifier() {
        let itself = runningApp("closeAll", bundle: "example.other", pid: 99)
        XCTAssertEqual(QuitPlanner.skipReason(for: itself, exclusions: exclusions()), .thisApp)
    }

    func testSelfIsSkippedByBundleIdentifierIgnoringCase() {
        let itself = runningApp(
            "closeAll",
            bundle: "APP.closeAll.closeAll",
            pid: 40
        )
        XCTAssertEqual(QuitPlanner.skipReason(for: itself, exclusions: exclusions()), .thisApp)
    }

    func testAnotherAppIsNotTreatedAsSelf() {
        let other = runningApp("Notes", bundle: "com.apple.Notes", pid: 41)
        XCTAssertTrue(QuitPlanner.willQuit(other, exclusions: exclusions()))
    }

    func testKeptBundleIdentifierIsCaseInsensitive() {
        let cursor = runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 3)
        let rules = exclusions(keptBundles: ["  COM.TODESKTOP.230313MZL4W4U92 "])
        XCTAssertEqual(QuitPlanner.skipReason(for: cursor, exclusions: rules), .keptByUser)
        XCTAssertTrue(QuitPlanner.isToggleable(cursor, exclusions: rules))
    }

    func testKeptProcessIdentifierOnlyMatchesThatProcess() {
        let unnamed = runningApp("Helper", pid: 15)
        let other = runningApp("Helper", pid: 16)
        let rules = exclusions(keptPIDs: [15])
        XCTAssertEqual(QuitPlanner.skipReason(for: unnamed, exclusions: rules), .keptByUser)
        XCTAssertNil(QuitPlanner.skipReason(for: other, exclusions: rules))
    }

    func testTerminatedAndInvalidProcessesAreSkipped() {
        let gone = runningApp("Mail", bundle: "com.apple.mail", pid: 9, terminated: true)
        let invalid = runningApp("Ghost", pid: 0)
        let negative = runningApp("Ghost", pid: -5)
        XCTAssertEqual(QuitPlanner.skipReason(for: gone, exclusions: exclusions()), .alreadyTerminated)
        XCTAssertEqual(QuitPlanner.skipReason(for: invalid, exclusions: exclusions()), .invalidProcess)
        XCTAssertEqual(QuitPlanner.skipReason(for: negative, exclusions: exclusions()), .invalidProcess)
    }

    func testRegularAppWithoutBundleIdentifierCanBeQuit() {
        let loose = runningApp("Untitled", pid: 12)
        XCTAssertEqual(QuitPlanner.targets(for: [loose], exclusions: exclusions()), [loose])
    }

    func testDuplicateProcessIdentifiersAreRemoved() {
        let first = runningApp("Safari", bundle: "com.apple.Safari", pid: 2)
        let duplicate = runningApp("Safari Copy", bundle: "com.apple.Safari", pid: 2)
        XCTAssertEqual(QuitPlanner.targets(for: [first, duplicate], exclusions: exclusions()), [first])
    }

    func testTargetsSortByNameThenProcessIdentifier() {
        let apps = [
            runningApp("zebra", pid: 3),
            runningApp("Alpha", pid: 8),
            runningApp("alpha", pid: 2),
            runningApp("Middle", pid: 4),
        ]
        XCTAssertEqual(
            QuitPlanner.targets(for: apps, exclusions: exclusions()).map(\.processIdentifier),
            [2, 8, 4, 3]
        )
    }

    func testSkipPriorityPrefersSelfAndProtectionOverAKeepList() {
        let finder = runningApp("Finder", bundle: "com.apple.finder", pid: 1)
        let rules = exclusions(keptBundles: ["com.apple.finder"])
        XCTAssertEqual(QuitPlanner.skipReason(for: finder, exclusions: rules), .protectedSystem)

        let itself = runningApp("closeAll", bundle: "app.closeall.closeall", pid: 70)
        XCTAssertEqual(QuitPlanner.skipReason(for: itself, exclusions: rules), .thisApp)
    }

    func testTerminatedProtectedAppReportsAlreadyTerminated() {
        let finder = runningApp("Finder", bundle: "com.apple.finder", pid: 1, terminated: true)
        XCTAssertEqual(QuitPlanner.skipReason(for: finder, exclusions: exclusions()), .alreadyTerminated)
    }

    func testRealisticDockSessionQuitsUserAppsAndKeepsTheSession() {
        let apps = [
            runningApp("Finder", bundle: "com.apple.finder", pid: 1),
            runningApp("Dock", bundle: "com.apple.dock", pid: 2, policy: .accessory),
            runningApp("loginwindow", bundle: "com.apple.loginwindow", pid: 3, policy: .accessory),
            runningApp("Control Center", bundle: "com.apple.controlcenter", pid: 4, policy: .accessory),
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
            runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
            runningApp("closeAll", bundle: "app.closeall.closeall", pid: 99),
            runningApp("Amphetamine", bundle: "com.if.Amphetamine", pid: 8, policy: .accessory),
        ]
        let names = QuitPlanner.targets(for: apps, exclusions: exclusions()).map(\.localizedName)
        XCTAssertEqual(names, ["Cursor", "Safari"])
    }

    func testKeepingCursorLeavesTheOtherDockApps() {
        let apps = [
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
            runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
            runningApp("Finder", bundle: "com.apple.finder", pid: 1),
        ]
        let rules = exclusions(keptBundles: ["com.todesktop.230313mzl4w4u92"])
        XCTAssertEqual(
            QuitPlanner.targets(for: apps, exclusions: rules).map(\.localizedName),
            ["Safari"]
        )
    }

    func testBlankBundleIdentifierIsTreatedAsMissing() {
        XCTAssertNil(BundleIdentity.normalize("   "))
        XCTAssertNil(BundleIdentity.normalize(nil))
        XCTAssertEqual(BundleIdentity.normalize(" Com.Apple.Safari "), "com.apple.safari")
    }
}
