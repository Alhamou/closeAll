/// What happened after a Force Quit run.
public struct QuitOutcome: Equatable, Sendable {
    /// Process ids that were confirmed gone.
    public let closed: [Int32]
    /// Planned apps that were still running when the run gave up.
    public let stillRunning: [RunningApp]

    public init(closed: [Int32], stillRunning: [RunningApp]) {
        self.closed = closed
        self.stillRunning = stillRunning
    }
}

/// Force-quits the planned apps and confirms that each one actually exited.
///
/// `NSRunningApplication.forceTerminate()` only reports that a request was sent.
/// An app can survive it, refuse it, or be relaunched by a helper right away.
/// The runner waits for every target to exit, pauses briefly so a relaunched copy
/// can appear, re-scans, and sends SIGKILL to anything that is still running,
/// for a bounded number of passes. An app that refuses, or that may no longer be
/// closed, is not retried. It is reported in `stillRunning` while it is alive.
@MainActor
public struct QuitRunner {
    public var currentApps: @MainActor () -> [RunningApp]
    /// First attempt, normally `NSRunningApplication.forceTerminate()`. Returns false if refused.
    public var forceTerminate: @MainActor (RunningApp) -> Bool
    /// Fallback, normally SIGKILL. Returns false if refused.
    public var kill: @MainActor (RunningApp) -> Bool
    public var isRunning: @MainActor (RunningApp) -> Bool
    public var sleep: @MainActor (Duration) async -> Void
    public var maxPasses: Int
    public var pollInterval: Duration
    public var waitPerPass: Duration
    /// Pause before each re-scan. A helper needs a moment to relaunch an app, and
    /// `NSWorkspace` only refreshes its app list while the main run loop turns.
    public var settleDelay: Duration

    public init(
        currentApps: @escaping @MainActor () -> [RunningApp],
        forceTerminate: @escaping @MainActor (RunningApp) -> Bool,
        kill: @escaping @MainActor (RunningApp) -> Bool,
        isRunning: @escaping @MainActor (RunningApp) -> Bool,
        sleep: @escaping @MainActor (Duration) async -> Void,
        maxPasses: Int = 3,
        pollInterval: Duration = .milliseconds(100),
        waitPerPass: Duration = .seconds(2),
        settleDelay: Duration = .milliseconds(500)
    ) {
        self.currentApps = currentApps
        self.forceTerminate = forceTerminate
        self.kill = kill
        self.isRunning = isRunning
        self.sleep = sleep
        self.maxPasses = max(1, maxPasses)
        self.pollInterval = pollInterval
        self.waitPerPass = waitPerPass
        self.settleDelay = settleDelay
    }

    public func run(exclusions: QuitExclusions) async -> QuitOutcome {
        let initial = QuitPlanner.targets(for: currentApps(), exclusions: exclusions)
        guard !initial.isEmpty else {
            return QuitOutcome(closed: [], stillRunning: [])
        }
        // Later passes only touch what the user saw checked, or a relaunched copy of it.
        // A pid counts only while the same app owns it, so a reused pid is never a target.
        var plannedByPID: [Int32: RunningApp] = [:]
        for app in initial {
            plannedByPID[app.processIdentifier] = app
        }
        let plannedBundles = Set(initial.compactMap { BundleIdentity.normalize($0.bundleIdentifier) })
        func wasPlanned(_ app: RunningApp) -> Bool {
            if let planned = plannedByPID[app.processIdentifier],
               BundleIdentity.same(planned.bundleIdentifier, app.bundleIdentifier) {
                return true
            }
            guard let bundle = BundleIdentity.normalize(app.bundleIdentifier) else { return false }
            return plannedBundles.contains(bundle)
        }

        var closed: [Int32] = []
        // Still alive, but refused or no longer allowed to close. Reported, never retried.
        var givenUp: [RunningApp] = []
        var pending = initial
        for pass in 0..<maxPasses {
            var sent: [RunningApp] = []
            for app in pending {
                var accepted: Bool
                if pass == 0 {
                    accepted = forceTerminate(app)
                    if !accepted {
                        accepted = kill(app)
                    }
                } else {
                    accepted = kill(app)
                }
                if accepted {
                    sent.append(app)
                } else if isRunning(app) {
                    givenUp.append(app)
                }
            }

            var waited: Duration = .zero
            while waited < waitPerPass, sent.contains(where: { isRunning($0) }) {
                await sleep(pollInterval)
                waited += pollInterval
            }

            for app in sent where !isRunning(app) && !closed.contains(app.processIdentifier) {
                closed.append(app.processIdentifier)
            }

            await sleep(settleDelay)
            let givenUpPIDs = Set(givenUp.map(\.processIdentifier))
            pending = QuitPlanner.targets(for: currentApps(), exclusions: exclusions).filter { app in
                guard wasPlanned(app), !givenUpPIDs.contains(app.processIdentifier) else { return false }
                return isRunning(app)
            }
            // A planned app that is still alive but no longer a target, for example because it
            // hid its Dock icon, is reported instead of being dropped without a word.
            let pendingPIDs = Set(pending.map(\.processIdentifier))
            for app in sent where !pendingPIDs.contains(app.processIdentifier)
                && !givenUpPIDs.contains(app.processIdentifier) {
                if isRunning(app) {
                    givenUp.append(app)
                }
            }
            if pending.isEmpty { break }
        }

        var reportedPIDs: Set<Int32> = []
        var stillRunning: [RunningApp] = []
        for app in pending + givenUp where isRunning(app) {
            if reportedPIDs.insert(app.processIdentifier).inserted {
                stillRunning.append(app)
            }
        }
        return QuitOutcome(closed: closed, stillRunning: stillRunning.sorted(by: QuitPlanner.sortApps))
    }
}
