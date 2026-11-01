import SwiftUI
import ApertureCore

public struct PackageDetailView: View {
    @EnvironmentObject private var vm: ApertureViewModel
    @Environment(\.dismiss) private var dismiss
    public let hit: SearchIndex.Hit
    @State private var detail: AperturePackage?
    @State private var screenshots: [URL] = []

    public init(hit: SearchIndex.Hit) { self.hit = hit }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ApertureTheme.spacingMd) {
                header
                if !screenshots.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ApertureTheme.spacingSm) {
                            ForEach(screenshots, id: \.self) { url in
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image { img.resizable().scaledToFill().frame(width: 240, height: 460).clipShape(RoundedRectangle(cornerRadius: ApertureTheme.radiusMd, style: .continuous)) }
                                    else { RoundedRectangle(cornerRadius: ApertureTheme.radiusMd).fill(ApertureTheme.bgTertiary).frame(width: 240, height: 460) }
                                }
                            }
                        }.padding(.horizontal, ApertureTheme.spacingMd)
                    }
                }
                if let d = detail {
                    descriptionBlock(d)
                    depsBlock("Depends", d.depends)
                    depsBlock("Conflicts", d.conflicts)
                    metaBlock(d)
                    Spacer(minLength: 20)
                    InstallButton(mode: installMode, action: { vm.install(hit: hit) }).padding(.horizontal, ApertureTheme.spacingMd)
                }
            }.padding(.vertical, ApertureTheme.spacingMd)
        }
        .background(ApertureTheme.bgPrimary.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: ApertureTheme.spacingMd) {
            AsyncImage(url: hit.iconURL.flatMap(URL.init(string:))) { phase in
                if let img = phase.image { img.resizable().scaledToFill() }
                else { RoundedRectangle(cornerRadius: ApertureTheme.radiusSm).fill(ApertureTheme.bgTertiary) }
            }.frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: ApertureTheme.radiusMd, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.name).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(hit.package).font(.system(size: 13, design: .monospaced)).foregroundStyle(ApertureTheme.textSecondary)
                Text(hit.version).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(ApertureTheme.accent)
            }
            Spacer()
        }.padding(.horizontal, ApertureTheme.spacingMd)
    }

    private func descriptionBlock(_ d: AperturePackage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description").font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(d.descriptionText).font(.body).foregroundStyle(ApertureTheme.textSecondary)
        }.padding(ApertureTheme.spacingMd).apertureCard().padding(.horizontal, ApertureTheme.spacingMd)
    }

    @ViewBuilder
    private func depsBlock(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                ForEach(items, id: \.self) { Text($0).font(.system(size: 13, design: .monospaced)).foregroundStyle(ApertureTheme.textSecondary) }
            }.padding(ApertureTheme.spacingMd).apertureCard().padding(.horizontal, ApertureTheme.spacingMd)
        }
    }

    private func metaBlock(_ d: AperturePackage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let author = d.author { metaRow("Author", author) }
            if let maintainer = d.maintainer { metaRow("Maintainer", maintainer) }
            if let section = d.section { metaRow("Section", section) }
            metaRow("Size", formatBytes(d.size))
            if let homepage = d.homepage, let url = URL(string: homepage) { Link("Homepage", destination: url) }
        }.padding(ApertureTheme.spacingMd).apertureCard().padding(.horizontal, ApertureTheme.spacingMd)
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(ApertureTheme.textSecondary); Spacer(); Text(v).foregroundStyle(ApertureTheme.textPrimary) }.font(.system(size: 14))
    }

    private var installMode: InstallButton.Mode {
        vm.isInstalled(hit.package) ? .remove : .install
    }

    private func load() async {
        detail = vm.packageDetail(for: hit)
        screenshots = (detail?.screenshotURLs ?? []).compactMap(URL.init(string:))
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useAll]; f.countStyle = .file; return f.string(fromByteCount: b)
    }
}

