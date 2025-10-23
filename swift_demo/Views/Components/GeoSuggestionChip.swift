//
//  GeoSuggestionChip.swift
//  swift_demo
//
//  Created for PR-4: UI Components for Georgian Vocabulary Suggestions
//

import SwiftUI

/// A chip displaying a Georgian word suggestion with gloss
/// Think of this as a reusable Vue component: <SuggestionChip :suggestion="..." @accept="..." @dismiss="..." />
struct GeoSuggestionChip: View {
    let suggestion: GeoSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.word)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(suggestion.gloss)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if suggestion.formality != "neutral" {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(suggestion.formality)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(formalityColor)
                    }
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .accessibilityLabel("Dismiss suggestion")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .onTapGesture {
            onAccept()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggestion: \(suggestion.word), \(suggestion.gloss)")
        .accessibilityHint("Tap to use this word, or tap X to dismiss")
    }
    
    private var formalityColor: Color {
        switch suggestion.formality {
        case "formal":
            return .purple
        case "informal":
            return .orange
        default:
            return .secondary
        }
    }
}

/// Loading skeleton for suggestion chip
struct GeoSuggestionChipSkeleton: View {
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(width: 80, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 10)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shimmer()
    }
}

/// Shimmer effect modifier for loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Error chip for failed suggestions
struct GeoSuggestionErrorChip: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text("Couldn't fetch suggestions")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview("Suggestion Chip") {
    VStack(spacing: 12) {
        GeoSuggestionChip(
            suggestion: GeoSuggestion(
                word: "არაპრის",
                gloss: "you're welcome",
                formality: "neutral"
            ),
            onAccept: { print("Accepted") },
            onDismiss: { print("Dismissed") }
        )
        
        GeoSuggestionChip(
            suggestion: GeoSuggestion(
                word: "გმადლობთ",
                gloss: "thank you",
                formality: "formal"
            ),
            onAccept: { print("Accepted") },
            onDismiss: { print("Dismissed") }
        )
        
        GeoSuggestionChipSkeleton()
        
        GeoSuggestionErrorChip(onDismiss: { print("Dismissed") })
    }
    .padding()
}

