public enum SkipReason: String, Codable, Equatable, Sendable {
    case invalidProcess
    case alreadyTerminated
    case thisApp
    case protectedSystem
    case notRegularApp
    case keptByUser
    /// A background app the user has not checked. Background apps stay open by default.
    case backgroundNotChosen
}

/// Where an app is listed in the panel.
public enum AppGroup: String, Codable, Equatable, Sendable {
    /// A normal Dock app. Checked by default.
    case dock
    /// A menu-bar app the user installed in an Applications folder. Unchecked by default.
    case background
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
    /// closeAll's own bundle id. Another copy of closeAll is never a target, even when this
    /// process runs unbundled (for example from `swift run`).
    public static let closeAllBundleIdentifier = "app.closeall.closeall"

    /// Decides which apps a force-quit is allowed to close.
    /// Finder, this process, and other session processes are never targets.
    /// Background apps close only when the user checked them.
    public static func skipReason(
        for app: RunningApp,
        exclusions: QuitExclusions
    ) -> SkipReason? {
        if let reason = sessionSkipReason(for: app, exclusions: exclusions) {
            return reason
        }
        switch listedGroup(for: app) {
        case nil:
            return .notRegularApp
        case .dock:
            return isKept(app, exclusions: exclusions) ? .keptByUser : nil
        case .background:
            if isKept(app, exclusions: exclusions) {
                return .keptByUser
            }
            return isChosenBackground(app, exclusions: exclusions) ? nil : .backgroundNotChosen
        }
    }

    public static func willQuit(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        skipReason(for: app, exclusions: exclusions) == nil
    }

    /// The panel section for an app the user may check or uncheck, or nil when it stays hidden.
    public static func group(for app: RunningApp, exclusions: QuitExclusions) -> AppGroup? {
        guard sessionSkipReason(for: app, exclusions: exclusions) == nil else { return nil }
        return listedGroup(for: app)
    }

    /// Apps the user may check or uncheck. Protected and system background processes stay hidden.
    public static func isToggleable(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        group(for: app, exclusions: exclusions) != nil
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

    public static func isChosenBackground(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        guard let bundleIdentifier = BundleIdentity.normalize(app.bundleIdentifier) else {
            return false
        }
        return exclusions.closedBackgroundBundleIdentifiers.contains { candidate in
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

    /// Rules that hold for every app, whatever the user checked.
    private static func sessionSkipReason(
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
        if let appBundleIdentifier = BundleIdentity.normalize(app.bundleIdentifier) {
            if appBundleIdentifier == closeAllBundleIdentifier
                || appBundleIdentifier == BundleIdentity.normalize(exclusions.ownBundleIdentifier) {
                return .thisApp
            }
        }
        if SystemProtection.isProtected(app.bundleIdentifier) {
            return .protectedSystem
        }
        return nil
    }

    /// True for an app bundle that sits in `/Applications` or `~/Applications` (or a folder
    /// inside them) and is not packed inside another app. Helpers such as
    /// `Slack.app/Contents/Frameworks/Slack Helper.app` and updaters kept in Library folders fail this.
    public static func isInstalledStandaloneApp(_ bundlePath: String?) -> Bool {
        guard let bundlePath else { return false }
        let components = bundlePath.split(separator: "/").map(String.init)
        guard let last = components.last, last.lowercased().hasSuffix(".app") else { return false }
        let inApplications = components.first == "Applications"
            || (components.count > 3 && components[0] == "Users" && components[2] == "Applications")
        let insideAnotherApp = components.dropLast().contains { $0.lowercased().hasSuffix(".app") }
        return inApplications && !insideAnotherApp
    }

    /// Dock apps are listed. A menu-bar app is listed only when it is a standalone app the
    /// user installed, has a bundle id, and is not Apple's, so system agents, helpers inside
    /// other apps, and unknown processes stay hidden. UI-less processes are never listed.
    private static func listedGroup(for app: RunningApp) -> AppGroup? {
        switch app.activationPolicy {
        case .regular:
            return .dock
        case .accessory:
            guard let bundleIdentifier = BundleIdentity.normalize(app.bundleIdentifier),
                  !bundleIdentifier.hasPrefix("com.apple."),
                  isInstalledStandaloneApp(app.bundlePath) else {
                return nil
            }
            return .background
        case .prohibited:
            return nil
        }
    }

    private static func unique(_ apps: [RunningApp]) -> [RunningApp] {
        var seen: Set<Int32> = []
        return apps.filter { app in
            seen.insert(app.processIdentifier).inserted
        }
    }
}
