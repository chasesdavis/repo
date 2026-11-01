import Foundation

/// Persistence facade. Dispatches to the best available backend at runtime:
/// SwiftData (iOS 17+/macOS 14+) or Core Data (iOS 15+/macOS 12+).
public final class ApertureStore: @unchecked Sendable {
    public static let shared = ApertureStore()

    private let fm = FileManager.default
    private let rootURL: URL
    private let backend: PersistenceBackend

    public init(root: URL? = nil) {
        if let root {
            self.rootURL = root
        } else {
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.rootURL = docs.appendingPathComponent("Aperture", isDirectory: true)
        }
        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        self.backend = PersistenceBackendFactory.make(rootURL: rootURL)
    }

    public func loadRepos() -> [ApertureRepo] { backend.loadRepos() }
    public func saveRepos(_ repos: [ApertureRepo]) { backend.saveRepos(repos) }
    public func loadPackages(repoID: String) -> [AperturePackage] { backend.loadPackages(repoID: repoID) }
    public func savePackages(_ packages: [AperturePackage], repoID: String) { backend.savePackages(packages, repoID: repoID) }
    public func purgePackages(repoID: String) { backend.purgePackages(repoID: repoID) }
    public func loadHistory() -> [Transaction] { backend.loadHistory() }
    public func appendHistory(_ txn: Transaction) { backend.appendHistory(txn) }
}

