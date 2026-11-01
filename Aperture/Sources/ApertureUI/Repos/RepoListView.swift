import SwiftUI
import ApertureCore

public struct RepoListView: View {
    @EnvironmentObject private var vm: ApertureViewModel
    @State private var showingAdd = false
    @State private var newURL = ""
    @State private var newSuite = "./"

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Default") {
                    ForEach(vm.repos.filter { $0.isDefault }, id: \.id) { repo in
                        RepoRow(repo: repo, onRefresh: { Task { await vm.refreshRepo(repo) } })
                    }
                }
                Section("Added") {
                    ForEach(vm.repos.filter { !$0.isDefault }, id: \.id) { repo in
                        RepoRow(repo: repo, onRefresh: { Task { await vm.refreshRepo(repo) } })
                            .swipeActions {
                                Button(role: .destructive) { vm.removeRepo(repo) } label: { Label("Remove", systemImage: "trash") }
                            }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            #else
            .listStyle(.sidebar)
            #endif
            .background(ApertureTheme.bgPrimary)
            .navigationTitle("Repositories")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
                #endif
            }
            .sheet(isPresented: $showingAdd) {
                AddRepoSheet(url: $newURL, suite: $newSuite) {
                    vm.addRepo(url: newURL, suite: newSuite); newURL = ""; newSuite = "./"; showingAdd = false
                }
            }
        }
    }
}

private struct RepoRow: View {
    let repo: ApertureRepo
    let onRefresh: () -> Void
    var body: some View {
        HStack(spacing: ApertureTheme.spacingMd) {
            ZStack {
                RoundedRectangle(cornerRadius: ApertureTheme.radiusSm, style: .continuous).fill(ApertureTheme.bgTertiary)
                if let iconURL = repo.iconURL, let url = URL(string: iconURL) {
                    AsyncImage(url: url).cornerRadius(ApertureTheme.radiusSm)
                } else {
                    Image(systemName: "building.2.fill").foregroundStyle(ApertureTheme.textSecondary)
                }
            }.frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.displayName).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(repo.url).font(.system(size: 12, design: .monospaced)).foregroundStyle(ApertureTheme.textSecondary).lineLimit(1)
                Text("\(repo.packageCount) packages").font(.caption).foregroundStyle(ApertureTheme.textSecondary)
            }
            Spacer()
            Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless)
        }
    }
}

private struct AddRepoSheet: View {
    @Binding var url: String
    @Binding var suite: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("URL") {
                    TextField("https://example.com/", text: $url)
                        .autocorrectionDisabled()
                }
                Section("Suite") {
                    TextField("./", text: $suite)
                        .autocorrectionDisabled()
                }
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
            .background(ApertureTheme.bgPrimary)
            .navigationTitle("Add Repository")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Add", action: onAdd).font(.system(size: 16, weight: .semibold)).disabled(url.isEmpty) }
                #else
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", action: onAdd).font(.system(size: 16, weight: .semibold)).disabled(url.isEmpty) }
                #endif
            }
        }
    }
}

