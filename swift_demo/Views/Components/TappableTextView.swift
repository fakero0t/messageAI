//
//  TappableTextView.swift
//  swift_demo
//
//  AI V3: Custom text view that detects word at touch location
//

import SwiftUI
import UIKit

/// Custom UILabel that properly calculates intrinsic content size with max width
class SizingLabel: UILabel {
    var maxWidth: CGFloat? {
        didSet {
            if maxWidth != oldValue {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        guard let maxWidth = maxWidth else {
            return super.intrinsicContentSize
        }
        
        // Calculate size that fits within maxWidth
        let size = sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width, maxWidth), height: size.height)
    }
}

/// UIViewRepresentable wrapper for UILabel that detects word at long-press location
struct TappableTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let textAlignment: NSTextAlignment
    let maxWidth: CGFloat?
    let onLongPressWord: (String, String) -> Void // (word, fullContext)
    
    func makeUIView(context: Context) -> SizingLabel {
        let label = SizingLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isUserInteractionEnabled = true
        
        // Make label hug its content horizontally
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // Add long-press gesture
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        // Allow scrolling to work simultaneously with long-press detection
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        label.addGestureRecognizer(longPress)
        
        return label
    }
    
    func updateUIView(_ label: SizingLabel, context: Context) {
        label.text = text
        label.font = font
        label.textColor = textColor
        label.textAlignment = textAlignment
        label.maxWidth = maxWidth
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, onLongPressWord: onLongPressWord)
    }
    
    class Coordinator: NSObject {
        let text: String
        let onLongPressWord: (String, String) -> Void
        
        init(text: String, onLongPressWord: @escaping (String, String) -> Void) {
            self.text = text
            self.onLongPressWord = onLongPressWord
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let label = gesture.view as? UILabel,
                  let labelText = label.text else {
                return
            }
            
            // Get touch location
            let location = gesture.location(in: label)
            
            // Find word at touch location
            if let word = wordAt(location: location, in: label, text: labelText) {
                print("📍 [TappableText] Word at touch: \(word)")
                
                // Trigger haptic feedback
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                // Only process Georgian words
                if GeorgianScriptDetector.containsGeorgian(word) {
                    let cleanWord = WordBoundaryDetector.stripPunctuation(from: word)
                    onLongPressWord(cleanWord, labelText)
                } else {
                    print("⚠️ [TappableText] Word is not Georgian: \(word)")
                }
            }
        }
        
        private func wordAt(location: CGPoint, in label: UILabel, text: String) -> String? {
            guard let attributedText = label.attributedText else {
                return nil
            }
            
            // Create text storage and layout manager
            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)
            
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            textContainer.lineBreakMode = label.lineBreakMode
            
            // Find character index at location
            let characterIndex = layoutManager.characterIndex(
                for: location,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            
            // Ensure index is valid
            guard characterIndex < text.count else {
                return nil
            }
            
            // Find word boundaries using NSLinguisticTagger
            let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
            tagger.string = text
            
            let range = NSRange(location: 0, length: (text as NSString).length)
            var foundWord: String?
            
            tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: []) { _, tokenRange, _ in
                if NSLocationInRange(characterIndex, tokenRange) {
                    if let swiftRange = Range(tokenRange, in: text) {
                        foundWord = String(text[swiftRange])
                    }
                }
            }
            
            return foundWord
        }
    }
}

/// Wrapper view that matches Text styling but uses TappableTextView
struct LongPressableText: View {
    let text: String
    let font: Font
    let color: Color
    let alignment: TextAlignment
    let maxWidth: CGFloat?
    let onLongPressWord: (String, String) -> Void
    
    var body: some View {
        TappableTextView(
            text: text,
            font: uiFont(from: font),
            textColor: uiColor(from: color),
            textAlignment: nsTextAlignment(from: alignment),
            maxWidth: maxWidth,
            onLongPressWord: onLongPressWord
        )
    }
    
    // Convert SwiftUI Font to UIFont (approximation)
    private func uiFont(from font: Font) -> UIFont {
        // For simplicity, use system font
        // In production, you'd want more sophisticated font conversion
        return UIFont.systemFont(ofSize: 16)
    }
    
    // Convert SwiftUI Color to UIColor
    private func uiColor(from color: Color) -> UIColor {
        return UIColor(color)
    }
    
    // Convert SwiftUI TextAlignment to NSTextAlignment
    private func nsTextAlignment(from alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }
}

