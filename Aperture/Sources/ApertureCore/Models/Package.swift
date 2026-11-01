import Foundation

/// A single package entry parsed from an APT `Packages` file.
public struct AperturePackage: Hashable, Identifiable, Sendable {
    public let id: String          // "<repoID>::<package>::<version>"
    public let package: String     // dpkg package name
    public let name: String        // human-readable name
    public let version: String
    public let architecture: String
    public let section: String?
    public let repoID: String
    public let repoURL: String
    public let maintainer: String?
    public let author: String?
    public let descriptionText: String
    public let homepage: String?
    public let depends: [String]
    public let conflicts: [String]
    public let provides: [String]
    public let replaces: [String]
    public let filename: String     // path relative to repo root
    public let size: Int64         // installed size in bytes
    public let md5sum: String?
    public let sha256: String?
    public let depiction: String?  // legacy native depiction URL
    public let sileoDepiction: String?
    public let tags: [String]
    public let iconURL: String?
    public let screenshotURLs: [String]
    public let changelog: String?

    public init(
        id: String, package: String, name: String, version: String,
        architecture: String, section: String?, repoID: String, repoURL: String,
        maintainer: String?, author: String?, descriptionText: String,
        homepage: String?, depends: [String], conflicts: [String],
        provides: [String], replaces: [String], filename: String,
        size: Int64, md5sum: String?, sha256: String?,
        depiction: String?, sileoDepiction: String?, tags: [String],
        iconURL: String?, screenshotURLs: [String], changelog: String?
    ) {
        self.id = id; self.package = package; self.name = name; self.version = version
        self.architecture = architecture; self.section = section; self.repoID = repoID
        self.repoURL = repoURL; self.maintainer = maintainer; self.author = author
        self.descriptionText = descriptionText; self.homepage = homepage
        self.depends = depends; self.conflicts = conflicts; self.provides = provides
        self.replaces = replaces; self.filename = filename; self.size = size
        self.md5sum = md5sum; self.sha256 = sha256; self.depiction = depiction
        self.sileoDepiction = sileoDepiction; self.tags = tags; self.iconURL = iconURL
        self.screenshotURLs = screenshotURLs; self.changelog = changelog
    }

    /// Download URL for the .deb — repo root + filename.
    public var downloadURL: URL? {
        guard let base = URL(string: repoURL)?.deletingLastPathComponent() else { return nil }
        return base.appendingPathComponent(filename)
    }
}

public extension AperturePackage {
    static func == (lhs: AperturePackage, rhs: AperturePackage) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
        && lhs.iconURL == rhs.iconURL && lhs.screenshotURLs == rhs.screenshotURLs
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

