import SwiftUI

public struct MagnifierLensView: View {
    public let character: Character
    public var diameter: CGFloat

    public init(character: Character, diameter: CGFloat = 56) {
        self.character = character
        self.diameter = diameter
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)

            Text(String(character))
                .font(.system(size: diameter * 0.6, weight: .semibold, design: .default))
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color.primary)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
