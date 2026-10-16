public enum SkipReason: String, Codable, Equatable, Sendable {
    case invalidProcess
    case alreadyTerminated
    case thisApp
    case protectedSystem
    case notRegularApp
    case keptByUser
}

public struct QuitDecision: Equatable, Sendable {
    public let app: RunningApp
    public let reason: SkipReason?

    public var willQuit: Bool { reason == nil }

    public init(app: RunningApp, reason: SkipReason?) {
        self.app = app
        self.reason = reason
    }
}

public enum QuitPlanner {
    /// Decides which Dock apps a force-quit is allowed to close.
    /// Finder, this process, and other session processes are never targets.
    public static func skipReason(
        for app: RunningApp,
        exclusions: QuitExclusions
    ) -> SkipReason? {
        if app.processIdentifier <= 0 {
            return .invalidProcess
        }
        if app.isTerminated {
            return .alreadyTerminated
        }
        if app.processIdentifier == exclusions.ownProcessIdentifier {
            return .thisApp
        }
        if let ownBundleIdentifier = BundleIdentity.normalize(exclusions.ownBundleIdentifier),
           let appBundleIdentifier = BundleIdentity.normalize(app.bundleIdentifier),
           ownBundleIdentifier == appBundleIdentifier {
            return .thisApp
        }
        if SystemProtection.isProtected(app.bundleIdentifier) {
            return .protectedSystem
        }
        if app.activationPolicy != .regular {
            return .notRegularApp
        }
        if isKept(app, exclusions: exclusions) {
            return .keptByUser
        }
        return nil
    }

    public static func willQuit(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        skipReason(for: app, exclusions: exclusions) == nil
    }

    /// Apps the user may check or uncheck. Protected and background processes stay hidden.
    public static func isToggleable(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        var cleared = exclusions
        cleared.keptBundleIdentifiers = []
        cleared.keptProcessIdentifiers = []
        return skipReason(for: app, exclusions: cleared) == nil
    }

    public static func decisions(
        for apps: [RunningApp],
        exclusions: QuitExclusions
    ) -> [QuitDecision] {
        unique(apps).map { app in
            QuitDecision(app: app, reason: skipReason(for: app, exclusions: exclusions))
        }
    }

    public static func targets(
        for apps: [RunningApp],
        exclusions: QuitExclusions
    ) -> [RunningApp] {
        decisions(for: apps, exclusions: exclusions)
            .filter(\.willQuit)
            .map(\.app)
            .sorted(by: sortApps)
    }

    public static func isKept(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        if exclusions.keptProcessIdentifiers.contains(app.processIdentifier) {
            return true
        }
        guard let bundleIdentifier = BundleIdentity.normalize(app.bundleIdentifier) else {
            return false
        }
        return exclusions.keptBundleIdentifiers.contains { candidate in
            BundleIdentity.normalize(candidate) == bundleIdentifier
        }
    }

    static func sortApps(_ lhs: RunningApp, _ rhs: RunningApp) -> Bool {
        let leftName = lhs.localizedName.lowercased()
        let rightName = rhs.localizedName.lowercased()
        if leftName == rightName {
            return lhs.processIdentifier < rhs.processIdentifier
        }
        return leftName < rightName
    }

    private static func unique(_ apps: [RunningApp]) -> [RunningApp] {
        var seen: Set<Int32> = []
        return apps.filter { app in
            seen.insert(app.processIdentifier).inserted
        }
    }
}
