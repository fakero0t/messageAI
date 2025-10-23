import Foundation
import SwiftUI
import UIKit

public protocol TextHitTesting {
    func characterIndex(at point: CGPoint, in size: CGSize, text: AttributedString) -> Int?
}

public final class TextHitTestingHelper: TextHitTesting {
    public init() {}

    public func characterIndex(at point: CGPoint, in size: CGSize, text: AttributedString) -> Int? {
        // TextKit-based hit-testing using an offscreen UITextView
        let nsAttributed = NSAttributedString(text)
        let textView = UITextView(frame: CGRect(origin: .zero, size: size))
        textView.attributedText = nsAttributed
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.layoutManager.ensureLayout(for: textView.textContainer)

        let glyphIndex = textView.layoutManager.glyphIndex(for: point, in: textView.textContainer)
        let charIndex = textView.layoutManager.characterIndexForGlyph(at: glyphIndex)
        return charIndex < nsAttributed.length ? charIndex : nil
    }
}
