import SwiftUI
import ApertureCore

public struct StorefrontView: View {
    @EnvironmentObject private var vm: ApertureViewModel
    @State private var featured: [SearchIndex.Hit] = []
    @State private var recent: [SearchIndex.Hit] = []

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ApertureTheme.spacingLg, pinnedViews: [.sectionHeaders]) {
                heroSection
                if !featured.isEmpty {
                    Section {
                        ForEach(featured, id: \.id) { hit in
                            PackageCard(hit: hit, installed: vm.isInstalled(hit.package)) { vm.openPackage(hit) }
                        }
                    }
                    SectionHeader(title: "Featured", trailingTitle: "See All", trailingAction: { vm.seeAllFeatured() }).id("featured_header")
                }
                if !recent.isEmpty {
                    Section {
                        ForEach(recent, id: \.id) { hit in
                            PackageCard(hit: hit, installed: vm.isInstalled(hit.package)) { vm.openPackage(hit) }
                        }
                    }
                    SectionHeader(title: "Recently Added").id("recent_header")
                }
                if featured.isEmpty && recent.isEmpty {
                    EmptyState(icon: "shippingbox.fill", title: "No Packages Yet", subtitle: "Add a repository to start browsing tweaks and packages.")
                        .padding(.top, 80)
                }
            }
            .padding(.horizontal, ApertureTheme.spacingMd)
            .padding(.bottom, 40)
        }
        .background(ApertureTheme.bgPrimary.ignoresSafeArea())
        .task { await load() }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [ApertureTheme.accent, ApertureTheme.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: ApertureTheme.radiusLg, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text("Aperture").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("Your tweaks, beautifully delivered.").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            }.padding(ApertureTheme.spacingLg)
        }
    }

    private func load() async {
        featured = (try? vm.index.search("tweak", limit: 10)) ?? []
        recent = (try? vm.index.search("theme", limit: 10)) ?? []
    }
}

