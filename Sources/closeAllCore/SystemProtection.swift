/// Processes that keep the macOS desktop session alive.
/// They are never force-quit, even if the system reports them as normal apps.
public enum SystemProtection {
    public static let bundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.dock.extra",
        "com.apple.dock.helper",
        "com.apple.loginwindow",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.windowmanager",
        "com.apple.spotlight",
        "com.apple.talagent",
        "com.apple.coreservices.uiagent",
        "com.apple.universalcontrol",
        "com.apple.wallpaper.agent",
        "com.apple.usernotificationcenter",
        "com.apple.airplayuiagent",
        "com.apple.textinputmenuagent",
        "com.apple.textinputswitcher",
        "com.apple.backgroundtaskmanagement.agent",
        "com.apple.corelocationagent",
        "com.apple.wifi.wifiagent",
        "com.apple.accessibilityuiserver",
        "com.apple.security.keychain-circle-notification",
        "com.apple.softwareupdatenotificationmanager",
        "com.apple.appssoagent",
        "com.apple.nbagent",
        "com.apple.followupui",
        "com.apple.accessibility.dfrhud",
        "com.apple.linkednotesuiservice",
        "com.apple.workflowkit.shortcutsviewservice",
    ]

    public static func isProtected(_ bundleIdentifier: String?) -> Bool {
        guard let identifier = BundleIdentity.normalize(bundleIdentifier) else {
            return false
        }
        if bundleIdentifiers.contains(identifier) {
            return true
        }
        return identifier == "com.apple.dock" || identifier.hasPrefix("com.apple.dock.")
    }
}
