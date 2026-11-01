import SwiftUI
import ApertureCore

public struct InstallButton: View {
    public enum Mode: Equatable { case install, upgrade, remove, installed }
    public let mode: Mode
    public let action: () -> Void
    public init(mode: Mode, action: @escaping () -> Void) { self.mode = mode; self.action = action }
    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemIcon).font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(background, in: RoundedRectangle(cornerRadius: ApertureTheme.radiusSm, style: .continuous))
                .foregroundStyle(foreground)
        }
    }
    private var title: String { switch mode { case .install: return "Install"; case .upgrade: return "Upgrade"; case .remove: return "Remove"; case .installed: return "Installed" } }
    private var systemIcon: String { switch mode { case .install: return "arrow.down.circle"; case .upgrade: return "arrow.up.circle"; case .remove: return "trash.circle"; case .installed: return "checkmark.circle" } }
    private var background: Color { switch mode { case .install, .upgrade: return ApertureTheme.accent; case .remove: return ApertureTheme.danger.opacity(0.2); case .installed: return ApertureTheme.bgTertiary } }
    private var foreground: Color { switch mode { case .install, .upgrade: return .white; case .remove: return ApertureTheme.danger; case .installed: return ApertureTheme.textSecondary } }
}

