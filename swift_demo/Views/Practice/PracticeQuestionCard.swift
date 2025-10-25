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
    let selectedLetter: String?
    let showResult: Bool
    let onSelect: (String) -> Void
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Word with missing letter
            VStack(spacing: 8) {
                Text(showResult ? item.word : item.displayWord)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                    .tracking(2)
                
                Text(item.englishMeaning)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            if showResult {
                // Result feedback
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isCorrect ? .green : .red)
                    
                    Text(isCorrect ? "Correct!" : "Incorrect")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isCorrect ? .green : .red)
                }
                .padding(.top, 8)
            } else {
                Text("Choose the missing letter:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
            
            // Multiple choice options
            VStack(spacing: 16) {
                ForEach(Array(item.options.enumerated()), id: \.offset) { index, letter in
                    OptionButton(
                        letter: letter,
                        label: optionLabel(for: index),
                        isSelected: selectedLetter == letter,
                        isCorrect: letter == item.correctLetter,
                        showResult: showResult,
                        onTap: {
                            if !showResult {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onSelect(letter)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            // Next button (only shown in result state)
            if showResult {
                Button(action: onNext) {
                    Text("Next")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.georgianRed)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var isCorrect: Bool {
        guard let selected = selectedLetter else { return false }
        return selected == item.correctLetter
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
    let isCorrect: Bool
    let showResult: Bool
    let onTap: () -> Void
    
    private var buttonColor: Color {
        if showResult {
            if isSelected {
                // Show green if selected and correct, red if selected and wrong
                return isCorrect ? .green : .red
            } else if isCorrect {
                // Also highlight the correct answer in green (for when user chose wrong)
                return .green
            }
            return .gray
        }
        return isSelected ? .georgianRed : .gray
    }
    
    private var backgroundColor: Color {
        if showResult {
            if isSelected {
                return isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
            } else if isCorrect {
                return Color.green.opacity(0.1)
            }
            return Color(.systemGray6)
        }
        return isSelected ? Color.georgianRed.opacity(0.1) : Color(.systemGray6)
    }
    
    private var borderColor: Color {
        if showResult {
            if isSelected {
                return isCorrect ? .green : .red
            } else if isCorrect {
                return .green
            }
            return .clear
        }
        return isSelected ? .georgianRed : .clear
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Option label (A, B, C)
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(buttonColor)
                    .clipShape(Circle())
                
                // Letter
                Text(letter)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Checkmark or X icon when showing result
                if showResult && (isSelected || isCorrect) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isCorrect ? .green : .red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(showResult) // Disable interaction when showing result
    }
}

#Preview {
    PracticeQuestionCard(
        item: PracticeItem(
            word: "გამარჯობა",
            missingIndex: 3,
            correctLetter: "ა",
            options: ["ა", "ო", "ე"],
            explanation: "Common greeting - 'hello'",
            englishMeaning: "hello"
        ),
        selectedLetter: nil,
        showResult: false,
        onSelect: { letter in
            print("Selected: \(letter)")
        },
        onNext: {
            print("Next tapped")
        }
    )
}

