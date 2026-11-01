import SwiftUI
import ApertureCore

public struct SearchView: View {
    @EnvironmentObject private var vm: ApertureViewModel
    @State private var query = ""
    @State private var results: [SearchIndex.Hit] = []
    @State private var debounceTask: Task<Void, Never>?
    @State private var isSearching = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(ApertureTheme.textSecondary)
                TextField("Search tweaks, themes, packages…", text: $query)
                    .font(.system(size: 16, design: .rounded))
                    #if os(iOS)
                    .textInputAutocapitalization(.none)
                    .submitLabel(.search)
                    #endif
                    .autocorrectionDisabled()
                    .onChange(of: query) { _ in scheduleSearch() }
                if !query.isEmpty {
                    Button { query = ""; results = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(ApertureTheme.textSecondary) }
                }
            }
            .padding(ApertureTheme.spacingSm)
            .background(ApertureTheme.bgSecondary, in: RoundedRectangle(cornerRadius: ApertureTheme.radiusSm, style: .continuous))
            .padding(.horizontal, ApertureTheme.spacingMd)
            .padding(.vertical, ApertureTheme.spacingSm)

            if results.isEmpty && !query.isEmpty && !isSearching {
                EmptyState(icon: "magnifyingglass", title: "No Matches", subtitle: "Try a different keyword.")
                    .padding(.top, 80)
            } else if results.isEmpty && query.isEmpty {
                EmptyState(icon: "magnifyingglass", title: "Search", subtitle: "Find tweaks, themes, and packages across all your repositories.")
                    .padding(.top, 80)
            } else {
                List(results, id: \.id) { hit in
                    PackageCard(hit: hit, installed: vm.isInstalled(hit.package)) { vm.openPackage(hit) }
                        .listRowInsets(EdgeInsets(top: 4, leading: ApertureTheme.spacingMd, bottom: 4, trailing: ApertureTheme.spacingMd))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                #if os(iOS)
                .scrollContentBackground(.hidden)
                #endif
                .background(ApertureTheme.bgPrimary)
            }
        }
        .background(ApertureTheme.bgPrimary.ignoresSafeArea())
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let q = query
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, !q.isEmpty else { results = []; return }
            isSearching = true
            let hits = (try? vm.index.search(q, limit: 200)) ?? []
            if !Task.isCancelled { results = hits; isSearching = false }
        }
    }
}

