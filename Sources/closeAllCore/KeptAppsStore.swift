public enum KeptAppsStore {
    public static let defaultsKey = "keptBundleIdentifiers"

    public static func load(from stored: [String]?) -> Set<String> {
        Set((stored ?? []).compactMap(BundleIdentity.normalize))
    }

    public static func persistable(_ identifiers: Set<String>) -> [String] {
        Set(identifiers.compactMap(BundleIdentity.normalize)).sorted()
    }
}
