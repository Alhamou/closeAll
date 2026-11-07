@preconcurrency import AppKit
import closeAllCore
import Foundation

@MainActor
final class PanelModel: ObservableObject {
    @Published private(set) var rows: [PresentedApp] = []
    @Published private(set) var icons: [Int32: NSImage] = [:]
    @Published private(set) var statusLine = ""
    @Published private(set) var buttonTitle = QuitCopy.buttonTitle(quitCount: 0)
    @Published private(set) var quitCount = 0
    @Published private(set) var failureMessage: String?
    @Published private(set) var isQuitting = false

    private var keptBundleIdentifiers: Set<String>
    private var closedBackgroundBundleIdentifiers: Set<String>
    private var keptProcessIdentifiers: Set<Int32> = []
    /// Apps the last run could not close. The red line names only the ones still alive.
    private var stillRunningAfterQuit: [RunningApp] = []
    private var observers: [NSObjectProtocol] = []

    init() {
        keptBundleIdentifiers = KeptAppsStore.load(
            from: UserDefaults.standard.stringArray(forKey: KeptAppsStore.defaultsKey)
        )
        closedBackgroundBundleIdentifiers = KeptAppsStore.load(
            from: UserDefaults.standard.stringArray(forKey: KeptAppsStore.closedBackgroundDefaultsKey)
        )
        refresh()
        observeWorkspace()
    }

    func refresh() {
        let snapshot = currentSnapshot()
        // Session-only keeps are tied to a pid. Drop them once that process is gone,
        // so a reused pid never inherits the choice.
        let runningPIDs = Set(snapshot.apps.filter { !$0.isTerminated }.map(\.processIdentifier))
        keptProcessIdentifiers.formIntersection(runningPIDs)
        stillRunningAfterQuit = stillRunningAfterQuit.filter { MacRuntime.isRunning($0) }
        failureMessage = QuitCopy.failureLine(stillRunning: stillRunningAfterQuit.map(\.localizedName))
        let presented = SessionPresenter.presentedApps(snapshot)
        rows = presented
        icons = MacRuntime.icons(for: presented.map(\.processIdentifier))
        quitCount = presented.filter(\.willQuit).count
        statusLine = QuitCopy.statusLine(quitCount: quitCount)
        buttonTitle = isQuitting ? QuitCopy.quittingTitle : QuitCopy.buttonTitle(quitCount: quitCount)
    }

    func setWillQuit(_ willQuit: Bool, processIdentifier: Int32) {
        // The run already took its plan. A change now would not protect the app.
        guard !isQuitting else { return }
        guard let row = rows.first(where: { $0.processIdentifier == processIdentifier }) else {
            return
        }
        guard row.willQuit != willQuit else { return }
        if let bundleIdentifier = row.bundleIdentifier {
            switch (row.group, willQuit) {
            case (.dock, true):
                keptBundleIdentifiers.remove(bundleIdentifier)
            case (.dock, false):
                keptBundleIdentifiers.insert(bundleIdentifier)
                closedBackgroundBundleIdentifiers.remove(bundleIdentifier)
            case (.background, true):
                closedBackgroundBundleIdentifiers.insert(bundleIdentifier)
                keptBundleIdentifiers.remove(bundleIdentifier)
            case (.background, false):
                closedBackgroundBundleIdentifiers.remove(bundleIdentifier)
            }
            saveChoices()
        } else if willQuit {
            keptProcessIdentifiers.remove(processIdentifier)
        } else {
            keptProcessIdentifiers.insert(processIdentifier)
        }
        stillRunningAfterQuit = []
        refresh()
    }

    func forceQuit() {
        guard !isQuitting, quitCount > 0 else { return }
        isQuitting = true
        stillRunningAfterQuit = []
        failureMessage = nil
        buttonTitle = QuitCopy.quittingTitle
        let exclusions = currentSnapshot().exclusions
        let runner = MacRuntime.quitRunner(exclusions: exclusions)
        Task { @MainActor in
            let outcome = await runner.run(exclusions: exclusions)
            stillRunningAfterQuit = outcome.stillRunning
            isQuitting = false
            refresh()
        }
    }

    private func saveChoices() {
        let defaults = UserDefaults.standard
        defaults.set(KeptAppsStore.persistable(keptBundleIdentifiers), forKey: KeptAppsStore.defaultsKey)
        defaults.set(
            KeptAppsStore.persistable(closedBackgroundBundleIdentifiers),
            forKey: KeptAppsStore.closedBackgroundDefaultsKey
        )
    }

    private func currentSnapshot() -> SessionSnapshot {
        MacRuntime.snapshot(
            keptBundleIdentifiers: keptBundleIdentifiers,
            keptProcessIdentifiers: keptProcessIdentifiers,
            closedBackgroundBundleIdentifiers: closedBackgroundBundleIdentifiers
        )
    }

    private func observeWorkspace() {
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        let center = NSWorkspace.shared.notificationCenter
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            observers.append(observer)
        }
    }
}
