import SwiftUI

public struct GeorgianMagnifierOverlay<Content: View>: View {
    private let text: String
    private let content: Content
    private let hitTester: TextHitTesting
    private let alignment: Alignment

    @State private var isActive: Bool = false
    @State private var touchLocation: CGPoint = .zero
    @State private var currentCharacter: Character? = nil

    public init(
        text: String,
        alignment: Alignment = .topLeading,
        hitTester: TextHitTesting = TextHitTestingHelper(),
        @ViewBuilder content: () -> Content
    ) {
        self.text = text
        self.alignment = alignment
        self.hitTester = hitTester
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: alignment) {
            content
                .contentShape(Rectangle())

            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .onEnded { _ in
                                isActive = true
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if isActive {
                                    touchLocation = value.location
                                    updateCharacter(at: value.location, in: proxy.size)
                                }
                            }
                            .onEnded { _ in
                                isActive = false
                                currentCharacter = nil
                            }
                    )
            }

            if isActive, let ch = currentCharacter {
                MagnifierLensView(character: ch)
                    .offset(x: max(8, touchLocation.x - 28), y: max(-60, touchLocation.y - 72))
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.1), value: currentCharacter)
            }
        }
    }

    private func updateCharacter(at point: CGPoint, in size: CGSize) {
        let attributed = AttributedString(text)
        guard let idx = hitTester.characterIndex(at: point, in: size, text: attributed) else { return }
        guard idx >= 0 && idx < text.count else { return }
        let strIndex = text.index(text.startIndex, offsetBy: idx)
        let ch = text[strIndex]
        if currentCharacter != ch {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            currentCharacter = ch
        }
    }
}
