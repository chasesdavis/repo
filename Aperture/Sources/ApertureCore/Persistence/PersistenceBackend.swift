import Foundation

/// Abstraction over the on-device persistence layer. ApertureStore
/// picks the best available backend at runtime: SwiftData (iOS 17+),
/// Core Data (iOS 15+), or JSON files (always-available fallback).
public protocol PersistenceBackend: AnyObject {
    func loadRepos() -> [ApertureRepo]
    func saveRepos(_ repos: [ApertureRepo])
    func loadPackages(repoID: String) -> [AperturePackage]
    func savePackages(_ packages: [AperturePackage], repoID: String)
    func purgePackages(repoID: String)
    func loadHistory() -> [Transaction]
    func appendHistory(_ txn: Transaction)
}

public enum PersistenceBackendFactory {
    public static func make(rootURL: URL) -> PersistenceBackend {
        if #available(iOS 17, macOS 14, *) {
            return SwiftDataBackend(rootURL: rootURL)
        }
        return CoreDataBackend(rootURL: rootURL)
    }
}

