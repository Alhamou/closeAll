import AppKit
import closeAllCore

@MainActor
enum MacRuntime {
    static func currentApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications.map(map)
    }

    static func snapshot(keptBundleIdentifiers: Set<String>, keptProcessIdentifiers: Set<Int32>) -> SessionSnapshot {
        SessionSnapshot(
            apps: currentApps(),
            exclusions: QuitExclusions(
                ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
                ownBundleIdentifier: Bundle.main.bundleIdentifier,
                keptBundleIdentifiers: keptBundleIdentifiers,
                keptProcessIdentifiers: keptProcessIdentifiers
            )
        )
    }

    static func icons(for processIdentifiers: [Int32]) -> [Int32: NSImage] {
        var icons: [Int32: NSImage] = [:]
        for processIdentifier in processIdentifiers {
            guard let icon = NSRunningApplication(processIdentifier: processIdentifier)?.icon?.copy() as? NSImage else {
                continue
            }
            icon.size = NSSize(width: 16, height: 16)
            icon.isTemplate = false
            icons[processIdentifier] = icon
        }
        return icons
    }

    static func forceTerminate(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        guard let liveApplication = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            return false
        }
        let live = map(liveApplication)
        guard TerminationGuard.allow(app, live: live, exclusions: exclusions) else {
            return false
        }
        return liveApplication.forceTerminate()
    }

    private static func map(_ application: NSRunningApplication) -> RunningApp {
        let name = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false ? name : nil) ?? "App \(application.processIdentifier)"
        return RunningApp(
            bundleIdentifier: application.bundleIdentifier,
            localizedName: displayName,
            processIdentifier: application.processIdentifier,
            activationPolicy: policy(application.activationPolicy),
            isTerminated: application.isTerminated
        )
    }

    private static func policy(_ policy: NSApplication.ActivationPolicy) -> ActivationPolicy {
        switch policy {
        case .regular:
            return .regular
        case .accessory:
            return .accessory
        case .prohibited:
            return .prohibited
        @unknown default:
            return .prohibited
        }
    }
}
