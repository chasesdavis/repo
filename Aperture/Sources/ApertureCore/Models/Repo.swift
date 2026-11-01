import Foundation

/// A configured APT repository.
public struct ApertureRepo: Hashable, Identifiable, Sendable {
    public let id: String           // SHA-256 of normalized URL (hex prefix)
    public let url: String          // full Release URL
    public let suite: String        // distribution / suite (e.g. "stable", "./")
    public let components: [String] // typically ["main"]
    public let displayName: String
    public let iconURL: String?
    public let isDefault: Bool      // preinstalled (e.g. Procursus)
    public var lastRefresh: Date?
    public var packageCount: Int

    public init(
        id: String, url: String, suite: String, components: [String],
        displayName: String, iconURL: String?, isDefault: Bool,
        lastRefresh: Date? = nil, packageCount: Int = 0
    ) {
        self.id = id; self.url = url; self.suite = suite; self.components = components
        self.displayName = displayName; self.iconURL = iconURL; self.isDefault = isDefault
        self.lastRefresh = lastRefresh; self.packageCount = packageCount
    }

    /// Directory portion of the repo URL — resolves relative Filename paths.
    public var rootURL: URL {
        URL(string: url)?.deletingLastPathComponent() ?? URL(fileURLWithPath: "")
    }
}

/// APT section grouping (e.g. Tweaks, Themes, System).
public struct RepoSection: Hashable, Sendable {
    public let name: String
    public let packageCount: Int
    public init(name: String, packageCount: Int) {
        self.name = name; self.packageCount = packageCount
    }
}
