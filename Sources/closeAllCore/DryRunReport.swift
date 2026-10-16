import Foundation

public struct DryRunReport: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable {
        public var name: String
        public var bundleIdentifier: String?
        public var processIdentifier: Int32
        public var activationPolicy: String
        public var reason: String?

        public init(
            name: String,
            bundleIdentifier: String?,
            processIdentifier: Int32,
            activationPolicy: String,
            reason: String?
        ) {
            self.name = name
            self.bundleIdentifier = bundleIdentifier
            self.processIdentifier = processIdentifier
            self.activationPolicy = activationPolicy
            self.reason = reason
        }
    }

    public var ownProcessIdentifier: Int32
    public var protectedBundleIdentifiers: [String]
    public var targets: [Item]
    public var skipped: [Item]

    public init(
        ownProcessIdentifier: Int32,
        protectedBundleIdentifiers: [String],
        targets: [Item],
        skipped: [Item]
    ) {
        self.ownProcessIdentifier = ownProcessIdentifier
        self.protectedBundleIdentifiers = protectedBundleIdentifiers
        self.targets = targets
        self.skipped = skipped
    }

    public static func make(_ snapshot: SessionSnapshot) -> DryRunReport {
        let decisions = QuitPlanner.decisions(for: snapshot.apps, exclusions: snapshot.exclusions)
        let items = decisions.map(item)
        return DryRunReport(
            ownProcessIdentifier: snapshot.exclusions.ownProcessIdentifier,
            protectedBundleIdentifiers: SystemProtection.bundleIdentifiers.sorted(),
            targets: items.filter { $0.reason == nil }.sorted(by: sortItems),
            skipped: items.filter { $0.reason != nil }.sorted(by: sortItems)
        )
    }

    public func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    private static func item(_ decision: QuitDecision) -> Item {
        Item(
            name: decision.app.localizedName,
            bundleIdentifier: BundleIdentity.normalize(decision.app.bundleIdentifier),
            processIdentifier: decision.app.processIdentifier,
            activationPolicy: decision.app.activationPolicy.rawValue,
            reason: decision.reason?.rawValue
        )
    }

    private static func sortItems(_ lhs: Item, _ rhs: Item) -> Bool {
        let leftName = lhs.name.lowercased()
        let rightName = rhs.name.lowercased()
        if leftName == rightName {
            return lhs.processIdentifier < rhs.processIdentifier
        }
        return leftName < rightName
    }
}
