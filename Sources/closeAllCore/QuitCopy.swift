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

    public static func failureLine(failedCount: Int) -> String {
        if failedCount == 1 {
            return "Could not force quit 1 app."
        }
        return "Could not force quit \(failedCount) apps."
    }
}
