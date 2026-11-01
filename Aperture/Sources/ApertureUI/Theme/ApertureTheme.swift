import SwiftUI

/// Central design tokens for Aperture. Apple-style storefront palette:
/// pure black canvas, vibrant accent, generous spacing, soft card shadows.
public enum ApertureTheme {
    public static let accent = Color(red: 0.35, green: 0.55, blue: 1.0)
    public static let accentSecondary = Color(red: 0.45, green: 0.85, blue: 0.95)
    public static let success = Color(red: 0.30, green: 0.85, blue: 0.45)
    public static let danger = Color(red: 1.0, green: 0.35, blue: 0.35)
    public static let warning = Color(red: 1.0, green: 0.75, blue: 0.30)

    public static let bgPrimary = Color(.sRGB, white: 0.02, opacity: 1.0)
    public static let bgSecondary = Color(.sRGB, white: 0.06, opacity: 1.0)
    public static let bgTertiary = Color(.sRGB, white: 0.10, opacity: 1.0)
    public static let bgCard = Color(.sRGB, white: 0.09, opacity: 1.0)

    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary

    public static let radiusSm: CGFloat = 10
    public static let radiusMd: CGFloat = 16
    public static let radiusLg: CGFloat = 22
    public static let radiusXl: CGFloat = 28

    public static let spacingXs: CGFloat = 6
    public static let spacingSm: CGFloat = 10
    public static let spacingMd: CGFloat = 16
    public static let spacingLg: CGFloat = 24
    public static let spacingXl: CGFloat = 36

    public static let cardShadow = (
        color: Color.black.opacity(0.35),
        radius: CGFloat(18),
        x: CGFloat(0),
        y: CGFloat(8)
    )
}

public extension View {
    func apertureCard() -> some View {
        self
            .background(ApertureTheme.bgCard, in: RoundedRectangle(cornerRadius: ApertureTheme.radiusMd, style: .continuous))
            .shadow(color: ApertureTheme.cardShadow.color,
                    radius: ApertureTheme.cardShadow.radius,
                    x: ApertureTheme.cardShadow.x,
                    y: ApertureTheme.cardShadow.y)
    }

    func apertureAccentButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(ApertureTheme.accent, in: RoundedRectangle(cornerRadius: ApertureTheme.radiusSm, style: .continuous))
            .foregroundStyle(.white)
    }
}

