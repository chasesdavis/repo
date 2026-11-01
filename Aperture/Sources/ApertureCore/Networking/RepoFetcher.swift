import Foundation

/// Fetches Release and Packages (plain or .gz) from a configured repo.
/// Uses URLSession async/await with ETag / Last-Modified conditional GETs.
public actor RepoFetcher {
    private let session: URLSession
    private var etags: [String: String] = [:]
    private var lastModified: [String: String] = [:]

    public init(session: URLSession = .shared) { self.session = session }

    public struct FetchResult: Sendable {
        public let releaseData: Data?
        public let packagesData: Data?
        public let releaseModified: Bool
        public let packagesModified: Bool
    }

    public func fetch(repo: ApertureRepo) async throws -> FetchResult {
        let baseURL = repo.rootURL
        let releaseURL = baseURL.appendingPathComponent("Release")
        let packagesURL = baseURL.appendingPathComponent("Packages.gz")
        async let releaseTask = conditionalGet(url: releaseURL, key: "release:" + repo.id)
        async let packagesTask = conditionalGet(url: packagesURL, key: "packages:" + repo.id)
        let release = try await releaseTask
        let packages = try await packagesTask
        return FetchResult(
            releaseData: release.data, packagesData: packages.data,
            releaseModified: release.modified, packagesModified: packages.modified
        )
    }

    private struct GetResult { let data: Data?; let modified: Bool }

    private func conditionalGet(url: URL, key: String) async throws -> GetResult {
        var req = URLRequest(url: url)
        if let tag = etags[key] { req.setValue(tag, forHTTPHeaderField: "If-None-Match") }
        if let lm = lastModified[key] { req.setValue(lm, forHTTPHeaderField: "If-Modified-Since") }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { return GetResult(data: data, modified: true) }
        if http.statusCode == 304 { return GetResult(data: nil, modified: false) }
        if let tag = http.value(forHTTPHeaderField: "ETag") { etags[key] = tag }
        if let lm = http.value(forHTTPHeaderField: "Last-Modified") { lastModified[key] = lm }
        return GetResult(data: data, modified: true)
    }
}
