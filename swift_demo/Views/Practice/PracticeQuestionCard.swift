//
//  PracticeQuestionCard.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//  Individual question display component
//

import SwiftUI

/// Card displaying a practice question with multiple choice letters
/// Think of this as a Vue component: <PracticeQuestionCard :item="currentItem" @select="handleSelect" />
struct PracticeQuestionCard: View {
    let item: PracticeItem
    let onSelect: (String) -> Void
    
    @State private var selectedOption: String?
    
    var body: some View {
        VStack(spacing: 24) {
            // Word with missing letter
            Text(item.displayWord)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
                .tracking(2)
                .padding(.top, 40)
            
            Text("Choose the missing letter:")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 20)
            
            // Multiple choice options
            VStack(spacing: 16) {
                ForEach(Array(item.options.enumerated()), id: \.offset) { index, letter in
                    OptionButton(
                        letter: letter,
                        label: optionLabel(for: index),
                        isSelected: selectedOption == letter,
                        onTap: {
                            selectedOption = letter
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Small delay for visual feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onSelect(letter)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func optionLabel(for index: Int) -> String {
        switch index {
        case 0: return "A"
        case 1: return "B"
        case 2: return "C"
        default: return ""
        }
    }
}

/// Individual option button
struct OptionButton: View {
    let letter: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Option label (A, B, C)
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.blue : Color.gray)
                    .clipShape(Circle())
                
                // Letter
                Text(letter)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PracticeQuestionCard(
        item: PracticeItem(
            word: "გამარჯობა",
            missingIndex: 3,
            correctLetter: "ა",
            options: ["ა", "ო", "ე"],
            explanation: "Common greeting - 'hello'"
        ),
        onSelect: { letter in
            print("Selected: \(letter)")
        }
    )
}

