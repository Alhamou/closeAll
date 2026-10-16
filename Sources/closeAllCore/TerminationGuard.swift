public enum TerminationGuard {
    /// Re-checks a live process immediately before force-quit, in case the pid was reused.
    public static func allow(
        _ requested: RunningApp,
        live: RunningApp,
        exclusions: QuitExclusions
    ) -> Bool {
        guard requested.processIdentifier > 0 else { return false }
        guard requested.processIdentifier == live.processIdentifier else { return false }
        guard requested.processIdentifier != exclusions.ownProcessIdentifier else { return false }
        guard BundleIdentity.same(requested.bundleIdentifier, live.bundleIdentifier) else {
            return false
        }
        return QuitPlanner.willQuit(live, exclusions: exclusions)
    }
}
