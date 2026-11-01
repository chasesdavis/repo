import SwiftUI

public struct SectionHeader: View {
    public let title: String
    public let trailingTitle: String?
    public let trailingAction: (() -> Void)?
    public init(title: String, trailingTitle: String? = nil, trailingAction: (() -> Void)? = nil) { self.title = title; self.trailingTitle = trailingTitle; self.trailingAction = trailingAction }
    public var body: some View {
        HStack {
            Text(title).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(ApertureTheme.textPrimary)
            Spacer()
            if let trailingTitle, let trailingAction {
                Button(trailingTitle, action: trailingAction).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(ApertureTheme.accent)
            }
        }.padding(.horizontal, ApertureTheme.spacingMd).padding(.vertical, ApertureTheme.spacingSm)
    }
}

