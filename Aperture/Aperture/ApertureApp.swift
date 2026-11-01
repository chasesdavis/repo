import SwiftUI
import ApertureCore
import ApertureUI

@main
struct ApertureApp: App {
    @StateObject private var vm: ApertureViewModel

    init() {
        let store = ApertureStore.shared
        let repoStore = RepoStore()
        guard let index = try? SearchIndex() else {
            fatalError("Failed to open search index")
        }
        _vm = StateObject(wrappedValue: ApertureViewModel(store: store, repoStore: repoStore, index: index))
    }

    var body: some Scene {
        TabView {
            StorefrontView()
                .tabItem { Label("Featured", systemImage: "sparkles") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            InstalledView()
                .tabItem { Label("Installed", systemImage: "internaldrive") }
            RepoListView()
                .tabItem { Label("Repos", systemImage: "building.2") }
        }
        .environmentObject(vm)
        .tint(ApertureTheme.accent)
    }
}

