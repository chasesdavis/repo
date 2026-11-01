import SwiftUI

public struct ProgressBar: View {
    public let progress: Double
    public init(progress: Double) { self.progress = progress }
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ApertureTheme.bgTertiary)
                Capsule().fill(ApertureTheme.accent).frame(width: max(0, min(geo.size.width, geo.size.width * progress)))
            }
        }.frame(height: 6)
    }
}

