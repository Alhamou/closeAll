import XCTest
@testable import closeAllCore

/// A fake process table. Apps listed in `alive` are running.
@MainActor
private final class FakeSystem {
    var apps: [RunningApp]
    var alive: Set<Int32>
    /// Pids that ignore the first, polite force-quit.
    var ignoresForceTerminate: Set<Int32> = []
    /// Pids that refuse every attempt (for example, owned by another user).
    var unkillable: Set<Int32> = []
    /// Pids that accept every attempt but never exit.
    var immortal: Set<Int32> = []
    /// Called after a pid dies.
    var onDeath: (@MainActor (RunningApp) -> Void)?
    /// Called whenever time passes, to model a helper that relaunches an app a moment later.
    var onSleep: (@MainActor () -> Void)?
    var forceTerminated: [Int32] = []
    var killed: [Int32] = []
    var sleeps = 0
    var slept: Duration = .zero

    init(_ apps: [RunningApp]) {
        self.apps = apps
        alive = Set(apps.map(\.processIdentifier))
    }

    func runner(maxPasses: Int = 3) -> QuitRunner {
        QuitRunner(
            currentApps: { self.apps },
            forceTerminate: { app in
                self.forceTerminated.append(app.processIdentifier)
                if self.unkillable.contains(app.processIdentifier) { return false }
                if !self.ignoresForceTerminate.contains(app.processIdentifier) {
                    self.die(app)
                }
                return true
            },
            kill: { app in
                self.killed.append(app.processIdentifier)
                if self.unkillable.contains(app.processIdentifier) { return false }
                self.die(app)
                return true
            },
            isRunning: { app in
                // Like the real check: the pid must be alive and still belong to the same app.
                guard self.alive.contains(app.processIdentifier) else { return false }
                let live = self.apps.last { $0.processIdentifier == app.processIdentifier }
                return BundleIdentity.same(live?.bundleIdentifier, app.bundleIdentifier)
            },
            sleep: { duration in
                self.sleeps += 1
                self.slept += duration
                self.onSleep?()
            },
            maxPasses: maxPasses,
            pollInterval: .milliseconds(100),
            waitPerPass: .milliseconds(300),
            settleDelay: .milliseconds(50)
        )
    }

    private func die(_ app: RunningApp) {
        guard !immortal.contains(app.processIdentifier) else { return }
        guard alive.remove(app.processIdentifier) != nil else { return }
        onDeath?(app)
    }
}

@MainActor
final class QuitRunnerTests: XCTestCase {
    func testClosesOnlyPlannedTargetsInOrder() async {
        let system = FakeSystem([
            runningApp("Finder", bundle: "com.apple.finder", pid: 1),
            runningApp("Safari", bundle: "com.apple.Safari", pid: 6),
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
            runningApp("Dock", bundle: "com.apple.dock", pid: 2, policy: .accessory),
            runningApp("closeAll", bundle: "app.closeall.closeall", pid: 99),
        ])
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertEqual(system.forceTerminated, [5, 6])
        XCTAssertEqual(system.killed, [])
        XCTAssertEqual(outcome, QuitOutcome(closed: [5, 6], stillRunning: []))
        XCTAssertTrue(system.alive.isSuperset(of: [1, 2, 99]))
    }

    func testDoesNothingForAnEmptyPlan() async {
        let system = FakeSystem([runningApp("Finder", bundle: "com.apple.finder", pid: 1)])
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertEqual(system.forceTerminated, [])
        XCTAssertEqual(outcome, QuitOutcome(closed: [], stillRunning: []))
    }

    func testKeptAppsAreNotTouched() async {
        let system = FakeSystem([
            runningApp("Cursor", bundle: "com.todesktop.230313mzl4w4u92", pid: 5),
            runningApp("Terminal", bundle: "com.apple.Terminal", pid: 8),
        ])
        let rules = exclusions(keptBundles: ["com.todesktop.230313mzl4w4u92"])
        _ = await system.runner().run(exclusions: rules)
        XCTAssertEqual(system.forceTerminated, [8])
        XCTAssertTrue(system.alive.contains(5))
    }

    /// The reported bug: forceTerminate() said yes, but the app kept running.
    func testAppThatSurvivesForceTerminateIsKilled() async {
        let system = FakeSystem([
            runningApp("Mail", bundle: "com.apple.mail", pid: 4),
            runningApp("Notes", bundle: "com.apple.Notes", pid: 7),
        ])
        system.ignoresForceTerminate = [4]
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertEqual(system.killed, [4])
        XCTAssertEqual(outcome.stillRunning, [])
        XCTAssertEqual(Set(outcome.closed), [4, 7])
        XCTAssertGreaterThan(system.sleeps, 0)
    }

    func testRefusedForceTerminateFallsBackToKillRightAway() async {
        let system = FakeSystem([runningApp("Mail", bundle: "com.apple.mail", pid: 4)])
        // Refused (returns false) rather than ignored.
        let runner = QuitRunner(
            currentApps: { system.apps },
            forceTerminate: { _ in false },
            kill: { app in
                system.killed.append(app.processIdentifier)
                system.alive.remove(app.processIdentifier)
                return true
            },
            isRunning: { system.alive.contains($0.processIdentifier) },
            sleep: { _ in }
        )
        let outcome = await runner.run(exclusions: exclusions())
        XCTAssertEqual(system.killed, [4])
        XCTAssertEqual(outcome, QuitOutcome(closed: [4], stillRunning: []))
    }

    func testRelaunchedCopyOfAPlannedAppIsClosedToo() async {
        let system = FakeSystem([runningApp("Docker", bundle: "com.docker.docker", pid: 30)])
        // The helper brings the app back a moment after it dies, not instantly.
        var relaunchDue = false
        var relaunched = false
        system.onDeath = { app in
            if app.processIdentifier == 30 { relaunchDue = true }
        }
        system.onSleep = {
            guard relaunchDue, !relaunched else { return }
            relaunched = true
            system.apps.append(runningApp("Docker", bundle: "com.docker.docker", pid: 31))
            system.alive.insert(31)
        }
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertTrue(relaunched)
        XCTAssertEqual(system.killed, [31])
        XCTAssertEqual(Set(outcome.closed), [30, 31])
        XCTAssertEqual(outcome.stillRunning, [])
    }

    func testUnplannedAppLaunchedDuringTheRunIsLeftAlone() async {
        let system = FakeSystem([runningApp("Mail", bundle: "com.apple.mail", pid: 4)])
        system.ignoresForceTerminate = [4]
        system.onDeath = { _ in
            system.apps.append(runningApp("Music", bundle: "com.apple.Music", pid: 50))
            system.alive.insert(50)
        }
        _ = await system.runner().run(exclusions: exclusions())
        XCTAssertFalse(system.killed.contains(50))
        XCTAssertTrue(system.alive.contains(50))
    }

    func testReportsAppsThatRefuseAndDoesNotRetryOrWaitForThem() async {
        let mail = runningApp("Mail", bundle: "com.apple.mail", pid: 4)
        let system = FakeSystem([mail, runningApp("Notes", bundle: "com.apple.Notes", pid: 7)])
        system.unkillable = [4]
        let outcome = await system.runner(maxPasses: 3).run(exclusions: exclusions())
        XCTAssertEqual(outcome.closed, [7])
        XCTAssertEqual(outcome.stillRunning, [mail])
        // One polite try and one kill, then it stops asking.
        XCTAssertEqual(system.forceTerminated, [4, 7])
        XCTAssertEqual(system.killed, [4])
        // Only the pause before the final check. No waiting for an app that said no.
        XCTAssertEqual(system.slept, .milliseconds(50))
    }

    func testWaitIsBoundedForAnAppThatNeverExits() async {
        let mail = runningApp("Mail", bundle: "com.apple.mail", pid: 4)
        let system = FakeSystem([mail])
        system.immortal = [4]
        let outcome = await system.runner(maxPasses: 2).run(exclusions: exclusions())
        XCTAssertEqual(outcome.stillRunning, [mail])
        XCTAssertEqual(system.killed, [4])
        // Each pass: 300 ms of 100 ms polls, then a 50 ms pause before the re-scan.
        XCTAssertEqual(system.sleeps, 8)
        XCTAssertEqual(system.slept, .milliseconds(700))
    }

    func testPlannedAppThatHidesItsDockIconIsReportedNotDropped() async {
        let teams = runningApp("Teams", bundle: "com.microsoft.teams2", pid: 12)
        let system = FakeSystem([teams])
        system.ignoresForceTerminate = [12]
        var hidden = false
        system.onSleep = {
            guard !hidden else { return }
            hidden = true
            // Same process, now a menu-bar app the user did not check.
            system.apps = [runningApp("Teams", bundle: "com.microsoft.teams2", pid: 12, policy: .accessory)]
        }
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertEqual(outcome.stillRunning.map(\.processIdentifier), [12])
        XCTAssertEqual(system.killed, [])
    }

    func testReusedPidOfAnotherAppIsNotKilled() async {
        let system = FakeSystem([runningApp("Mail", bundle: "com.apple.mail", pid: 4)])
        system.onDeath = { _ in
            // Another app gets the same pid right away.
            system.apps = [runningApp("Music", bundle: "com.apple.Music", pid: 4)]
            system.alive.insert(4)
        }
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertEqual(system.killed, [])
        XCTAssertTrue(system.alive.contains(4))
        XCTAssertEqual(outcome, QuitOutcome(closed: [4], stillRunning: []))
    }

    func testChosenBackgroundAppClosesAndOthersStay() async {
        let system = FakeSystem([
            runningApp("CopyClip", bundle: "com.fiplab.copyclip", pid: 40, policy: .accessory),
            runningApp("AmneziaWG", bundle: "org.amnezia.awg", pid: 41, policy: .accessory),
        ])
        let rules = exclusions(closedBackground: ["com.fiplab.copyclip"])
        let outcome = await system.runner().run(exclusions: rules)
        XCTAssertEqual(system.forceTerminated, [40])
        XCTAssertEqual(outcome, QuitOutcome(closed: [40], stillRunning: []))
        XCTAssertTrue(system.alive.contains(41))
    }

    func testPausesOnceBeforeTheFinalCheckWhenEverythingClosed() async {
        let system = FakeSystem([runningApp("Notes", bundle: "com.apple.Notes", pid: 7)])
        let outcome = await system.runner().run(exclusions: exclusions())
        XCTAssertEqual(outcome, QuitOutcome(closed: [7], stillRunning: []))
        XCTAssertEqual(system.slept, .milliseconds(50))
    }
}
