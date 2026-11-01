import SwiftUI
import ApertureCore

public struct PackageCard: View, Equatable {
    public let hit: SearchIndex.Hit
    public let installed: Bool
    public let action: () -> Void
    public init(hit: SearchIndex.Hit, installed: Bool, action: @escaping () -> Void) { self.hit = hit; self.installed = installed; self.action = action }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: ApertureTheme.spacingMd) {
                iconView
                VStack(alignment: .leading, spacing: 4) {
                    Text(hit.name).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(ApertureTheme.textPrimary).lineLimit(1)
                    Text(hit.package).font(.system(size: 13, design: .monospaced)).foregroundStyle(ApertureTheme.textSecondary).lineLimit(1)
                    if let section = hit.section {
                        Text(section).font(.caption2).foregroundStyle(ApertureTheme.accentSecondary).padding(.horizontal, 8).padding(.vertical, 2).background(ApertureTheme.accentSecondary.opacity(0.15), in: Capsule())
                    }
                }
                Spacer()
                if installed { Image(systemName: "checkmark.circle.fill").foregroundStyle(ApertureTheme.success) }
            }.padding(ApertureTheme.spacingMd).apertureCard()
        }.buttonStyle(.plain)
    }
    @ViewBuilder private var iconView: some View {
        if let urlString = hit.iconURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in if let img = phase.image { img.resizable().scaledToFill() } else { placeholderIcon } }
            .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: ApertureTheme.radiusSm, style: .continuous))
        } else { placeholderIcon }
    }
    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ApertureTheme.radiusSm, style: .continuous).fill(ApertureTheme.bgTertiary)
            Image(systemName: "shippingbox").font(.system(size: 22, weight: .light)).foregroundStyle(ApertureTheme.textSecondary)
        }.frame(width: 52, height: 52)
    }
    public static func == (lhs: PackageCard, rhs: PackageCard) -> Bool { lhs.hit.id == rhs.hit.id && lhs.installed == rhs.installed }
}

