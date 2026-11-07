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
/// The runner waits for every target to exit, re-scans, and sends SIGKILL to
/// anything that is still running, for a bounded number of passes.
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

    public init(
        currentApps: @escaping @MainActor () -> [RunningApp],
        forceTerminate: @escaping @MainActor (RunningApp) -> Bool,
        kill: @escaping @MainActor (RunningApp) -> Bool,
        isRunning: @escaping @MainActor (RunningApp) -> Bool,
        sleep: @escaping @MainActor (Duration) async -> Void,
        maxPasses: Int = 3,
        pollInterval: Duration = .milliseconds(100),
        waitPerPass: Duration = .seconds(2)
    ) {
        self.currentApps = currentApps
        self.forceTerminate = forceTerminate
        self.kill = kill
        self.isRunning = isRunning
        self.sleep = sleep
        self.maxPasses = max(1, maxPasses)
        self.pollInterval = pollInterval
        self.waitPerPass = waitPerPass
    }

    public func run(exclusions: QuitExclusions) async -> QuitOutcome {
        let initial = QuitPlanner.targets(for: currentApps(), exclusions: exclusions)
        guard !initial.isEmpty else {
            return QuitOutcome(closed: [], stillRunning: [])
        }
        // Later passes only touch what the user saw checked, or a relaunched copy of it.
        let plannedPIDs = Set(initial.map(\.processIdentifier))
        let plannedBundles = Set(initial.compactMap { BundleIdentity.normalize($0.bundleIdentifier) })
        func wasPlanned(_ app: RunningApp) -> Bool {
            if plannedPIDs.contains(app.processIdentifier) { return true }
            guard let bundle = BundleIdentity.normalize(app.bundleIdentifier) else { return false }
            return plannedBundles.contains(bundle)
        }

        var closed: [Int32] = []
        var pending = initial
        for pass in 0..<maxPasses {
            for app in pending {
                if pass == 0 {
                    if !forceTerminate(app) {
                        _ = kill(app)
                    }
                } else {
                    _ = kill(app)
                }
            }

            var waited: Duration = .zero
            while waited < waitPerPass, pending.contains(where: { isRunning($0) }) {
                await sleep(pollInterval)
                waited += pollInterval
            }

            for app in pending where !isRunning(app) && !closed.contains(app.processIdentifier) {
                closed.append(app.processIdentifier)
            }

            pending = QuitPlanner.targets(for: currentApps(), exclusions: exclusions)
                .filter { wasPlanned($0) && isRunning($0) }
            if pending.isEmpty { break }
        }
        return QuitOutcome(closed: closed, stillRunning: pending)
    }
}
