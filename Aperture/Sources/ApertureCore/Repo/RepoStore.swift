import Foundation

/// Owns the configured repo list. Reads/writes /etc/apt/sources.list.d/aperture.list.
public actor RepoStore {
    private let sourcesList = SourcesList()
    private var repos: [ApertureRepo] = []
    private var listeners: [UUID: AsyncStream<ApertureRepo>.Continuation] = [:]

    public init() {}

    public func load() async throws {
        let entries = try sourcesList.readAperture()
        repos = entries.map { entry in
            let id = RepoStore.repoID(for: entry.url, suite: entry.suite)
            return ApertureRepo(
                id: id, url: entry.url, suite: entry.suite,
                components: entry.components.isEmpty ? ["main"] : entry.components,
                displayName: RepoStore.displayName(for: entry.url),
                iconURL: nil, isDefault: false
            )
        }
    }

    public func all() -> [ApertureRepo] { repos }

    public func get(id: String) -> ApertureRepo? { repos.first { $0.id == id } }

    public func add(url: String, suite: String, components: [String] = ["main"]) async throws -> ApertureRepo {
        let id = RepoStore.repoID(for: url, suite: suite)
        if let existing = repos.first(where: { $0.id == id }) { return existing }
        let entry = SourcesEntry(url: url, suite: suite, components: components)
        try sourcesList.append(entry)
        let repo = ApertureRepo(
            id: id, url: url, suite: suite, components: components,
            displayName: RepoStore.displayName(for: url), iconURL: nil, isDefault: false
        )
        repos.append(repo)
        emit(repo)
        return repo
    }

    public func remove(id: String) async throws {
        guard let repo = repos.first(where: { $0.id == id }) else { return }
        try sourcesList.remove(url: repo.url, suite: repo.suite)
        repos.removeAll { $0.id == id }
    }

    public func updatePackageCount(_ count: Int, for id: String) {
        guard let idx = repos.firstIndex(where: { $0.id == id }) else { return }
        repos[idx].packageCount = count
        repos[idx].lastRefresh = Date()
        emit(repos[idx])
    }

    public func changes() -> AsyncStream<ApertureRepo> {
        AsyncStream { continuation in
            let token = UUID()
            listeners[token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeListener(token) }
            }
        }
    }

    private func removeListener(_ token: UUID) { listeners.removeValue(forKey: token) }

    private func emit(_ repo: ApertureRepo) {
        for continuation in listeners.values { continuation.yield(repo) }
    }

    public static func repoID(for url: String, suite: String) -> String {
        let raw = url.lowercased() + "::" + suite.lowercased()
        var hash: UInt64 = 5381
        for byte in raw.utf8 { hash = (hash &<< 5) &+ hash &+ UInt64(byte) }
        return String(hash, radix: 16)
    }

    static func displayName(for url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
