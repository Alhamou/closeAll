public enum ActivationPolicy: String, Codable, Equatable, Sendable {
    case regular
    case accessory
    case prohibited
}

/// A process reported by macOS as an application.
public struct RunningApp: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let localizedName: String
    public let processIdentifier: Int32
    public let activationPolicy: ActivationPolicy
    public let isTerminated: Bool

    public init(
        bundleIdentifier: String?,
        localizedName: String,
        processIdentifier: Int32,
        activationPolicy: ActivationPolicy,
        isTerminated: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.processIdentifier = processIdentifier
        self.activationPolicy = activationPolicy
        self.isTerminated = isTerminated
    }
}

public struct QuitExclusions: Equatable, Sendable {
    public var ownProcessIdentifier: Int32
    public var ownBundleIdentifier: String?
    /// Bundle ids the user chose to leave running. Comparison is case-insensitive.
    public var keptBundleIdentifiers: Set<String>
    /// Process ids kept for this session when an app has no bundle id.
    public var keptProcessIdentifiers: Set<Int32>

    public init(
        ownProcessIdentifier: Int32,
        ownBundleIdentifier: String? = nil,
        keptBundleIdentifiers: Set<String> = [],
        keptProcessIdentifiers: Set<Int32> = []
    ) {
        self.ownProcessIdentifier = ownProcessIdentifier
        self.ownBundleIdentifier = ownBundleIdentifier
        self.keptBundleIdentifiers = keptBundleIdentifiers
        self.keptProcessIdentifiers = keptProcessIdentifiers
    }
}

public struct SessionSnapshot: Equatable, Sendable {
    public let apps: [RunningApp]
    public let exclusions: QuitExclusions

    public init(apps: [RunningApp], exclusions: QuitExclusions) {
        self.apps = apps
        self.exclusions = exclusions
    }
}
