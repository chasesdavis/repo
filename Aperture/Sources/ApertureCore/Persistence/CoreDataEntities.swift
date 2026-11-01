import Foundation
import CoreData

@objc(CDRepo)
public class CDRepo: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var url: String
    @NSManaged public var suite: String
    @NSManaged public var components: String
    @NSManaged public var displayName: String
    @NSManaged public var iconURL: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var lastRefresh: Date?
    @NSManaged public var packageCount: Int32

    public func fill(from r: ApertureRepo) {
        id = r.id; url = r.url; suite = r.suite
        components = (r.components as NSArray).componentsJoined(by: "\u{1F}")
        displayName = r.displayName; iconURL = r.iconURL; isDefault = r.isDefault
        lastRefresh = r.lastRefresh; packageCount = Int32(r.packageCount)
    }
    public func toValue() -> ApertureRepo {
        let comps = components.components(separatedBy: "\u{1F}")
        return ApertureRepo(id: id, url: url, suite: suite, components: comps,
                            displayName: displayName, iconURL: iconURL, isDefault: isDefault,
                            lastRefresh: lastRefresh, packageCount: Int(packageCount))
    }
}

@objc(CDPackage)
public class CDPackage: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var package: String
    @NSManaged public var name: String
    @NSManaged public var version: String
    @NSManaged public var architecture: String
    @NSManaged public var section: String?
    @NSManaged public var repoID: String
    @NSManaged public var repoURL: String
    @NSManaged public var maintainer: String?
    @NSManaged public var author: String?
    @NSManaged public var descriptionText: String
    @NSManaged public var homepage: String?
    @NSManaged public var depends: String
    @NSManaged public var conflicts: String
    @NSManaged public var provides: String
    @NSManaged public var replaces: String
    @NSManaged public var filename: String
    @NSManaged public var size: Int64
    @NSManaged public var md5sum: String?
    @NSManaged public var sha256: String?
    @NSManaged public var depiction: String?
    @NSManaged public var sileoDepiction: String?
    @NSManaged public var tags: String
    @NSManaged public var iconURL: String?
    @NSManaged public var screenshotURLs: String
    @NSManaged public var changelog: String?

    private func joinArr(_ a: [String]) -> String { (a as NSArray).componentsJoined(by: "\u{1F}") }
    private func splitArr(_ s: String) -> [String] { s.components(separatedBy: "\u{1F}") }

    public func fill(from p: AperturePackage) {
        id = p.id; package = p.package; name = p.name; version = p.version
        architecture = p.architecture; section = p.section; repoID = p.repoID
        repoURL = p.repoURL; maintainer = p.maintainer; author = p.author
        descriptionText = p.descriptionText; homepage = p.homepage
        depends = joinArr(p.depends); conflicts = joinArr(p.conflicts)
        provides = joinArr(p.provides); replaces = joinArr(p.replaces)
        filename = p.filename; size = p.size; md5sum = p.md5sum; sha256 = p.sha256
        depiction = p.depiction; sileoDepiction = p.sileoDepiction
        tags = joinArr(p.tags); iconURL = p.iconURL
        screenshotURLs = joinArr(p.screenshotURLs); changelog = p.changelog
    }
    public func toValue() -> AperturePackage {
        AperturePackage(id: id, package: package, name: name, version: version,
            architecture: architecture, section: section, repoID: repoID, repoURL: repoURL,
            maintainer: maintainer, author: author, descriptionText: descriptionText,
            homepage: homepage, depends: splitArr(depends), conflicts: splitArr(conflicts),
            provides: splitArr(provides), replaces: splitArr(replaces),
            filename: filename, size: size, md5sum: md5sum, sha256: sha256,
            depiction: depiction, sileoDepiction: sileoDepiction, tags: splitArr(tags),
            iconURL: iconURL, screenshotURLs: splitArr(screenshotURLs), changelog: changelog)
    }
}

@objc(CDHistoryItem)
public class CDHistoryItem: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var kind: String
    @NSManaged public var packageID: String
    @NSManaged public var packageName: String
    @NSManaged public var state: String
    @NSManaged public var startedAt: Date?
    @NSManaged public var finishedAt: Date?
    @NSManaged public var attempts: Int32

    public func fill(from t: Transaction) {
        id = t.id; kind = t.kind.rawValue; packageID = t.package.id
        packageName = t.package.package; state = String(describing: t.state)
        startedAt = t.startedAt; finishedAt = t.finishedAt; attempts = Int32(t.attempts)
    }
    public func toValue() -> Transaction {
        let placeholder = AperturePackage(
            id: packageID, package: packageName, name: packageName, version: "",
            architecture: "", section: nil, repoID: "", repoURL: "",
            maintainer: nil, author: nil, descriptionText: "", homepage: nil,
            depends: [], conflicts: [], provides: [], replaces: [],
            filename: "", size: 0, md5sum: nil, sha256: nil,
            depiction: nil, sileoDepiction: nil, tags: [],
            iconURL: nil, screenshotURLs: [], changelog: nil)
        return Transaction(id: id, kind: TransactionKind(rawValue: kind) ?? .install,
                           package: placeholder, state: .queued,
                           startedAt: startedAt, finishedAt: finishedAt, attempts: Int(attempts))
    }
}

