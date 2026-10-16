public struct PresentedApp: Equatable, Sendable, Identifiable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let title: String
    public let willQuit: Bool

    public var id: Int32 { processIdentifier }

    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        title: String,
        willQuit: Bool
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.willQuit = willQuit
    }
}

public enum SessionPresenter {
    public static func presentedApps(_ snapshot: SessionSnapshot) -> [PresentedApp] {
        let listed = QuitPlanner.decisions(for: snapshot.apps, exclusions: snapshot.exclusions)
            .map(\.app)
            .filter { QuitPlanner.isToggleable($0, exclusions: snapshot.exclusions) }
            .sorted(by: QuitPlanner.sortApps)
        let duplicateNames = duplicateNameKeys(in: listed)
        return listed.map { app in
            PresentedApp(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: BundleIdentity.normalize(app.bundleIdentifier),
                title: title(for: app, duplicateNames: duplicateNames),
                willQuit: QuitPlanner.willQuit(app, exclusions: snapshot.exclusions)
            )
        }
    }

    private static func duplicateNameKeys(in apps: [RunningApp]) -> Set<String> {
        var counts: [String: Int] = [:]
        for app in apps {
            let key = app.localizedName.lowercased()
            counts[key, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    private static func title(for app: RunningApp, duplicateNames: Set<String>) -> String {
        let name = app.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? "App \(app.processIdentifier)" : name
        guard duplicateNames.contains(displayName.lowercased()) else {
            return displayName
        }
        if let bundleIdentifier = BundleIdentity.normalize(app.bundleIdentifier) {
            return "\(displayName) — \(bundleIdentifier)"
        }
        return "\(displayName) (\(app.processIdentifier))"
    }
}
