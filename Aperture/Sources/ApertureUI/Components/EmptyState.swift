import SwiftUI

public struct EmptyState: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public init(icon: String, title: String, subtitle: String) { self.icon = icon; self.title = title; self.subtitle = subtitle }
    public var body: some View {
        VStack(spacing: ApertureTheme.spacingMd) {
            Image(systemName: icon).font(.system(size: 44, weight: .light)).foregroundStyle(ApertureTheme.textSecondary)
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(subtitle).font(.subheadline).foregroundStyle(ApertureTheme.textSecondary).multilineTextAlignment(.center)
        }.padding(ApertureTheme.spacingXl).frame(maxWidth: .infinity)
    }
}

