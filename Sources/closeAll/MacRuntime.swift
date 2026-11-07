import AppKit
import closeAllCore

@MainActor
enum MacRuntime {
    static func currentApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications.map(map)
    }

    static func snapshot(
        keptBundleIdentifiers: Set<String>,
        keptProcessIdentifiers: Set<Int32>,
        closedBackgroundBundleIdentifiers: Set<String>
    ) -> SessionSnapshot {
        SessionSnapshot(
            apps: currentApps(),
            exclusions: QuitExclusions(
                ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
                ownBundleIdentifier: Bundle.main.bundleIdentifier,
                keptBundleIdentifiers: keptBundleIdentifiers,
                keptProcessIdentifiers: keptProcessIdentifiers,
                closedBackgroundBundleIdentifiers: closedBackgroundBundleIdentifiers
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
        guard let liveApplication = guardedLiveApplication(app, exclusions: exclusions) else {
            return false
        }
        return liveApplication.forceTerminate()
    }

    /// Fallback when `forceTerminate()` was refused or the app is still running.
    static func kill(_ app: RunningApp, exclusions: QuitExclusions) -> Bool {
        guard guardedLiveApplication(app, exclusions: exclusions) != nil else {
            return false
        }
        return Darwin.kill(app.processIdentifier, SIGKILL) == 0
    }

    /// True while the same app still owns this process id.
    static func isRunning(_ app: RunningApp) -> Bool {
        let processIdentifier = app.processIdentifier
        guard processIdentifier > 0 else { return false }
        if Darwin.kill(processIdentifier, 0) != 0, errno == ESRCH {
            return false
        }
        guard let liveApplication = NSRunningApplication(processIdentifier: processIdentifier),
              !liveApplication.isTerminated else {
            return false
        }
        return BundleIdentity.same(liveApplication.bundleIdentifier, app.bundleIdentifier)
    }

    static func quitRunner(exclusions: QuitExclusions) -> QuitRunner {
        QuitRunner(
            currentApps: { MacRuntime.currentApps() },
            forceTerminate: { MacRuntime.forceTerminate($0, exclusions: exclusions) },
            kill: { MacRuntime.kill($0, exclusions: exclusions) },
            isRunning: { MacRuntime.isRunning($0) },
            sleep: { try? await Task.sleep(for: $0) }
        )
    }

    private static func guardedLiveApplication(_ app: RunningApp, exclusions: QuitExclusions) -> NSRunningApplication? {
        guard let liveApplication = NSRunningApplication(processIdentifier: app.processIdentifier),
              !liveApplication.isTerminated else {
            return nil
        }
        guard TerminationGuard.allow(app, live: map(liveApplication), exclusions: exclusions) else {
            return nil
        }
        return liveApplication
    }

    private static func map(_ application: NSRunningApplication) -> RunningApp {
        let name = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false ? name : nil) ?? "App \(application.processIdentifier)"
        return RunningApp(
            bundleIdentifier: application.bundleIdentifier,
            localizedName: displayName,
            processIdentifier: application.processIdentifier,
            activationPolicy: policy(application.activationPolicy),
            isTerminated: application.isTerminated,
            bundlePath: application.bundleURL?.path
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
