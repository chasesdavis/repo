import SwiftUI
import ApertureCore

public struct InstalledView: View {
    @EnvironmentObject private var vm: ApertureViewModel
    @State private var filter = ""

    public init() {}

    public var body: some View {
        if vm.installed.isEmpty {
            EmptyState(icon: "internaldrive", title: "Nothing Installed", subtitle: "Install a package to see it here.")
        } else {
            List {
                ForEach(filtered, id: \.package) { (rec: InstalledRecord) in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.package).font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(rec.version).font(.system(size: 12, design: .monospaced)).foregroundStyle(ApertureTheme.textSecondary)
                        }
                        Spacer()
                        Text(rec.status.display).font(.caption).foregroundStyle(rec.status == .installed ? ApertureTheme.success : ApertureTheme.warning)
                    }.listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
            .background(ApertureTheme.bgPrimary)
        }
    }

    private var filtered: [InstalledRecord] {
        guard !filter.isEmpty else { return vm.installed }
        return vm.installed.filter { $0.package.localizedCaseInsensitiveContains(filter) }
    }
}

