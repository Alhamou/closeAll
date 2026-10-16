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
    private var keptProcessIdentifiers: Set<Int32> = []
    private var observers: [NSObjectProtocol] = []

    init() {
        keptBundleIdentifiers = KeptAppsStore.load(
            from: UserDefaults.standard.stringArray(forKey: KeptAppsStore.defaultsKey)
        )
        refresh()
        observeWorkspace()
    }

    func refresh() {
        let presented = SessionPresenter.presentedApps(currentSnapshot())
        rows = presented
        icons = MacRuntime.icons(for: presented.map(\.processIdentifier))
        quitCount = presented.filter(\.willQuit).count
        statusLine = QuitCopy.statusLine(quitCount: quitCount)
        buttonTitle = QuitCopy.buttonTitle(quitCount: quitCount)
    }

    func setWillQuit(_ willQuit: Bool, processIdentifier: Int32) {
        guard let row = rows.first(where: { $0.processIdentifier == processIdentifier }) else {
            return
        }
        guard row.willQuit != willQuit else { return }
        if let bundleIdentifier = row.bundleIdentifier {
            if willQuit {
                keptBundleIdentifiers.remove(bundleIdentifier)
            } else {
                keptBundleIdentifiers.insert(bundleIdentifier)
            }
            UserDefaults.standard.set(
                KeptAppsStore.persistable(keptBundleIdentifiers),
                forKey: KeptAppsStore.defaultsKey
            )
        } else if willQuit {
            keptProcessIdentifiers.remove(processIdentifier)
        } else {
            keptProcessIdentifiers.insert(processIdentifier)
        }
        failureMessage = nil
        refresh()
    }

    func forceQuit() {
        guard !isQuitting, quitCount > 0 else { return }
        isQuitting = true
        let exclusions = currentSnapshot().exclusions
        let result = QuitExecutor.forceQuit(
            apps: MacRuntime.currentApps(),
            exclusions: exclusions
        ) { app in
            MacRuntime.forceTerminate(app, exclusions: exclusions)
        }
        failureMessage = result.failed.isEmpty ? nil : QuitCopy.failureLine(failedCount: result.failed.count)
        refresh()
        isQuitting = false
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            refresh()
        }
    }

    private func currentSnapshot() -> SessionSnapshot {
        MacRuntime.snapshot(
            keptBundleIdentifiers: keptBundleIdentifiers,
            keptProcessIdentifiers: keptProcessIdentifiers
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
