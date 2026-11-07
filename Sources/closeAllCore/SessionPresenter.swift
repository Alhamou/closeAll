public struct PresentedApp: Equatable, Sendable, Identifiable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let title: String
    public let willQuit: Bool
    public let group: AppGroup

    public var id: Int32 { processIdentifier }

    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        title: String,
        willQuit: Bool,
        group: AppGroup = .dock
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.willQuit = willQuit
        self.group = group
    }
}

public enum SessionPresenter {
    /// Dock apps first, then background apps, each sorted by name.
    public static func presentedApps(_ snapshot: SessionSnapshot) -> [PresentedApp] {
        let listed: [Listed] = QuitPlanner
            .decisions(for: snapshot.apps, exclusions: snapshot.exclusions)
            .compactMap { decision -> Listed? in
                guard let group = QuitPlanner.group(for: decision.app, exclusions: snapshot.exclusions) else {
                    return nil
                }
                return Listed(app: decision.app, group: group)
            }
            .sorted { lhs, rhs in
                if lhs.group != rhs.group {
                    return lhs.group == .dock
                }
                return QuitPlanner.sortApps(lhs.app, rhs.app)
            }
        let duplicateNames = duplicateNameKeys(in: listed.map { $0.app })
        return listed.map { entry in
            PresentedApp(
                processIdentifier: entry.app.processIdentifier,
                bundleIdentifier: BundleIdentity.normalize(entry.app.bundleIdentifier),
                title: title(for: entry.app, duplicateNames: duplicateNames),
                willQuit: QuitPlanner.willQuit(entry.app, exclusions: snapshot.exclusions),
                group: entry.group
            )
        }
    }

    private struct Listed {
        let app: RunningApp
        let group: AppGroup
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
