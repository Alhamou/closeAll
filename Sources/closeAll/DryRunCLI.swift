import Foundation
import closeAllCore

enum DryRunCLI {
    @MainActor
    static func run() {
        let kept = KeptAppsStore.load(
            from: UserDefaults.standard.stringArray(forKey: KeptAppsStore.defaultsKey)
        )
        let snapshot = MacRuntime.snapshot(
            keptBundleIdentifiers: kept,
            keptProcessIdentifiers: []
        )
        do {
            let json = try DryRunReport.make(snapshot).json()
            FileHandle.standardOutput.write(Data(json.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
            Darwin.exit(EXIT_SUCCESS)
        } catch {
            FileHandle.standardError.write(Data("Could not encode the quit plan.\n".utf8))
            Darwin.exit(EXIT_FAILURE)
        }
    }
}
