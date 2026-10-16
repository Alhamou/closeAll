public struct QuitResult: Equatable, Sendable {
    public let started: [Int32]
    public let failed: [Int32]

    public init(started: [Int32], failed: [Int32]) {
        self.started = started
        self.failed = failed
    }
}

public enum QuitExecutor {
    /// Force-quits only the apps selected by `QuitPlanner`, in name order.
    @MainActor
    public static func forceQuit(
        apps: [RunningApp],
        exclusions: QuitExclusions,
        forceTerminate: (RunningApp) -> Bool
    ) -> QuitResult {
        var started: [Int32] = []
        var failed: [Int32] = []
        for app in QuitPlanner.targets(for: apps, exclusions: exclusions) {
            if app.processIdentifier == exclusions.ownProcessIdentifier || app.processIdentifier <= 0 {
                failed.append(app.processIdentifier)
                continue
            }
            if forceTerminate(app) {
                started.append(app.processIdentifier)
            } else {
                failed.append(app.processIdentifier)
            }
        }
        return QuitResult(started: started, failed: failed)
    }
}
