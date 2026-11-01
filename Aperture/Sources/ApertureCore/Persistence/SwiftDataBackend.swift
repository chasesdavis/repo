import Foundation
#if canImport(SwiftData)
import SwiftData

/// SwiftData-backed persistence (iOS 17+, macOS 14+). Stores repos, packages,
/// and install history as @Model objects in a shared ModelContainer.
@available(iOS 17, macOS 14, *)
public final class SwiftDataBackend: PersistenceBackend {
    private let container: ModelContainer
    private let queue = DispatchQueue(label: "aperture.swiftdata", qos: .utility)

    public init(rootURL: URL) {
        let storeURL = rootURL.appendingPathComponent("aperture.store", isDirectory: false)
        let config = SwiftData.ModelConfiguration(url: storeURL)
        do {
            container = try ModelContainer(for: SDRepo.self, SDPackage.self, SDHistoryItem.self, configurations: config)
        } catch {
            let memConfig = SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
            try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            container = try! ModelContainer(for: SDRepo.self, SDPackage.self, SDHistoryItem.self, configurations: memConfig)
        }
    }

    public func loadRepos() -> [ApertureRepo] {
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<SDRepo>()
        let rows = (try? ctx.fetch(desc)) ?? []
        return rows.map { $0.toValue() }
    }

    public func saveRepos(_ repos: [ApertureRepo]) {
        queue.async { [container] in
            let ctx = ModelContext(container)
            let existing = (try? ctx.fetch(FetchDescriptor<SDRepo>())) ?? []
            existing.forEach { ctx.delete($0) }
            repos.forEach { ctx.insert(SDRepo(from: $0)) }
            try? ctx.save()
        }
    }

    public func loadPackages(repoID: String) -> [AperturePackage] {
        let ctx = ModelContext(container)
        var desc = FetchDescriptor<SDPackage>(predicate: #Predicate { $0.repoID == repoID })
        desc.fetchLimit = 100_000
        let rows = (try? ctx.fetch(desc)) ?? []
        return rows.map { $0.toValue() }
    }

    public func savePackages(_ packages: [AperturePackage], repoID: String) {
        queue.async { [container] in
            let ctx = ModelContext(container)
            let existing = (try? ctx.fetch(FetchDescriptor<SDPackage>(predicate: #Predicate { $0.repoID == repoID }))) ?? []
            existing.forEach { ctx.delete($0) }
            packages.forEach { ctx.insert(SDPackage(from: $0)) }
            try? ctx.save()
        }
    }

    public func purgePackages(repoID: String) {
        let ctx = ModelContext(container)
        let existing = (try? ctx.fetch(FetchDescriptor<SDPackage>(predicate: #Predicate { $0.repoID == repoID }))) ?? []
        existing.forEach { ctx.delete($0) }
        try? ctx.save()
    }

    public func loadHistory() -> [Transaction] {
        let ctx = ModelContext(container)
        var desc = FetchDescriptor<SDHistoryItem>()
        desc.sortBy = [SortDescriptor(\.finishedAt, order: .reverse)]
        desc.fetchLimit = 200
        let rows = (try? ctx.fetch(desc)) ?? []
        return rows.map { $0.toValue() }
    }

    public func appendHistory(_ txn: Transaction) {
        queue.async { [container] in
            let ctx = ModelContext(container)
            ctx.insert(SDHistoryItem(from: txn))
            var desc = FetchDescriptor<SDHistoryItem>()
            desc.sortBy = [SortDescriptor(\.finishedAt, order: .reverse)]
            if let all = try? ctx.fetch(desc), all.count > 200 {
                all.dropFirst(200).forEach { ctx.delete($0) }
            }
            try? ctx.save()
        }
    }
}

@available(iOS 17, macOS 14, *)
@Model
final class SDRepo {
    @Attribute(.unique) var id: String
    var url: String
    var suite: String
    var components: [String]
    var displayName: String
    var iconURL: String?
    var isDefault: Bool
    var lastRefresh: Date?
    var packageCount: Int
    init(from r: ApertureRepo) {
        id = r.id; url = r.url; suite = r.suite; components = r.components
        displayName = r.displayName; iconURL = r.iconURL; isDefault = r.isDefault
        lastRefresh = r.lastRefresh; packageCount = r.packageCount
    }
    func toValue() -> ApertureRepo {
        ApertureRepo(id: id, url: url, suite: suite, components: components,
                     displayName: displayName, iconURL: iconURL, isDefault: isDefault,
                     lastRefresh: lastRefresh, packageCount: packageCount)
    }
}

@available(iOS 17, macOS 14, *)
@Model
final class SDPackage {
    @Attribute(.unique) var id: String
    var package: String
    var name: String
    var version: String
    var architecture: String
    var section: String?
    var repoID: String
    var repoURL: String
    var maintainer: String?
    var author: String?
    var descriptionText: String
    var homepage: String?
    var depends: [String]
    var conflicts: [String]
    var provides: [String]
    var replaces: [String]
    var filename: String
    var size: Int64
    var md5sum: String?
    var sha256: String?
    var depiction: String?
    var sileoDepiction: String?
    var tags: [String]
    var iconURL: String?
    var screenshotURLs: [String]
    var changelog: String?
    init(from p: AperturePackage) {
        id = p.id; package = p.package; name = p.name; version = p.version
        architecture = p.architecture; section = p.section; repoID = p.repoID
        repoURL = p.repoURL; maintainer = p.maintainer; author = p.author
        descriptionText = p.descriptionText; homepage = p.homepage
        depends = p.depends; conflicts = p.conflicts; provides = p.provides
        replaces = p.replaces; filename = p.filename; size = p.size
        md5sum = p.md5sum; sha256 = p.sha256; depiction = p.depiction
        sileoDepiction = p.sileoDepiction; tags = p.tags; iconURL = p.iconURL
        screenshotURLs = p.screenshotURLs; changelog = p.changelog
    }
    func toValue() -> AperturePackage {
        AperturePackage(id: id, package: package, name: name, version: version,
            architecture: architecture, section: section, repoID: repoID, repoURL: repoURL,
            maintainer: maintainer, author: author, descriptionText: descriptionText,
            homepage: homepage, depends: depends, conflicts: conflicts, provides: provides,
            replaces: replaces, filename: filename, size: size, md5sum: md5sum, sha256: sha256,
            depiction: depiction, sileoDepiction: sileoDepiction, tags: tags,
            iconURL: iconURL, screenshotURLs: screenshotURLs, changelog: changelog)
    }
}

@available(iOS 17, macOS 14, *)
@Model
final class SDHistoryItem {
    @Attribute(.unique) var id: UUID
    var kind: String
    var packageID: String
    var packageName: String
    var state: String
    var startedAt: Date?
    var finishedAt: Date?
    var attempts: Int
    init(from t: Transaction) {
        id = t.id; kind = t.kind.rawValue; packageID = t.package.id
        packageName = t.package.package; state = String(describing: t.state)
        startedAt = t.startedAt; finishedAt = t.finishedAt; attempts = t.attempts
    }
    func toValue() -> Transaction {
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
                           startedAt: startedAt, finishedAt: finishedAt, attempts: attempts)
    }
}
#endif

