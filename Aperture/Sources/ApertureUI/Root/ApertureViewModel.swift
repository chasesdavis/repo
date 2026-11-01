import Foundation
import SwiftUI
import ApertureCore

@MainActor
public final class ApertureViewModel: ObservableObject {
    @Published public var repos: [ApertureRepo] = []
    @Published public var installed: [InstalledRecord] = []
    @Published public var queue: [ApertureCore.Transaction] = []
    @Published public var selectedHit: SearchIndex.Hit?
    @Published public var detailPath: [SearchIndex.Hit] = []

    public let store: ApertureStore
    public let repoStore: RepoStore
    public let index: SearchIndex
    public let queueActor: InstallQueue
    private let fetcher: RepoFetcher
    private var queueListener: Task<Void, Never>?

    public init(
        store: ApertureStore = .shared,
        repoStore: RepoStore = RepoStore(),
        index: SearchIndex? = nil,
        queueActor: InstallQueue = InstallQueue(),
        fetcher: RepoFetcher = RepoFetcher()
    ) {
        self.store = store
        self.repoStore = repoStore
        self.fetcher = fetcher
        if let provided = index { self.index = provided }
        else if let opened = try? SearchIndex() { self.index = opened }
        else { self.index = try! SearchIndex(path: "/dev/null") }
        self.queueActor = queueActor
        repos = store.loadRepos()
        Task {
            try? await repoStore.load()
            await refreshInstalled()
            repos = store.loadRepos()
        }
        startQueueListener()
    }

    public func addRepo(url: String, suite: String) {
        Task {
            do {
                _ = try await repoStore.add(url: url, suite: suite, components: ["main"])
                if let repo = await repoStore.get(id: RepoStore.repoID(for: url, suite: suite)) {
                    await refreshRepo(repo)
                }
                repos = store.loadRepos()
            } catch {
                print("addRepo failed: \(error)")
            }
        }
    }

    public func removeRepo(_ repo: ApertureRepo) {
        Task {
            try? await repoStore.remove(id: repo.id)
            store.purgePackages(repoID: repo.id)
            try? index.clearRepo(repo.id)
            repos = store.loadRepos()
        }
    }

    public func refreshRepo(_ repo: ApertureRepo) async {
        do {
            let result = try await fetcher.fetch(repo: repo)
            guard let pkgData = result.packagesData else { return }
            let parser = PackagesParser()
            let pkgs = parser.parse(pkgData, repoID: repo.id, repoURL: repo.url)
            try index.replaceRepo(pkgs, repoID: repo.id)
            store.savePackages(pkgs, repoID: repo.id)
            await repoStore.updatePackageCount(pkgs.count, for: repo.id)
            repos = store.loadRepos()
        } catch {
            print("refreshRepo failed: \(error)")
        }
    }

    public func refreshInstalled() async {
        let dpkg = DpkgClient()
        if let records = try? await dpkg.installed() { installed = records }
    }

    public func isInstalled(_ package: String) -> Bool {
        installed.contains { $0.package == package }
    }

    public func install(hit: SearchIndex.Hit) {
        guard let pkg = packageDetail(for: hit) else { return }
        let txn = ApertureCore.Transaction(kind: .install, package: pkg)
        Task { await queueActor.enqueue(txn) }
    }

    public func cancelTransaction(_ id: UUID) { Task { await queueActor.cancel(id: id) } }
    public func retryTransaction(_ id: UUID) { Task { await queueActor.retry(id: id) } }

    public func packageDetail(for hit: SearchIndex.Hit) -> AperturePackage? {
        store.loadPackages(repoID: hit.repoID).first { $0.id == hit.id }
    }

    public func openPackage(_ hit: SearchIndex.Hit) { selectedHit = hit; detailPath.append(hit) }
    public func seeAllFeatured() {}

    private func startQueueListener() {
        queueListener?.cancel()
        queueListener = Task {
            for await event in await queueActor.events() {
                if case .queueChanged(let all) = event { queue = all }
            }
        }
    }
}

