public enum BundleIdentity {
    public static func normalize(_ bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier else { return nil }
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func same(_ lhs: String?, _ rhs: String?) -> Bool {
        normalize(lhs) == normalize(rhs)
    }
}
