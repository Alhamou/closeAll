public enum QuitCopy {
    public static func statusLine(quitCount: Int) -> String {
        switch quitCount {
        case 0:
            return "No Dock apps to quit. Finder stays open."
        case 1:
            return "1 app will close. Finder stays open. Unsaved changes will be lost."
        default:
            return "\(quitCount) apps will close. Finder stays open. Unsaved changes will be lost."
        }
    }

    public static func buttonTitle(quitCount: Int) -> String {
        switch quitCount {
        case 0:
            return "Force Quit All"
        case 1:
            return "Force Quit 1 App"
        default:
            return "Force Quit \(quitCount) Apps"
        }
    }

    public static let quittingTitle = "Closing…"

    /// Names the apps that were still running after every attempt.
    public static func failureLine(stillRunning names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        let shown = names.prefix(3).joined(separator: ", ")
        let extra = names.count - 3
        if extra > 0 {
            return "Could not close \(shown) and \(extra) more."
        }
        return "Could not close \(shown)."
    }
}
