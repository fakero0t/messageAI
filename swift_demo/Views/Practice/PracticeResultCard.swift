//
//  PracticeResultCard.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//  Shows result feedback after answer submission
//

import SwiftUI

/// Card displaying result feedback with complete word and explanation
/// Think of this as a Vue component: <PracticeResultCard :item="currentItem" :correct="isCorrect" @next="handleNext" />
struct PracticeResultCard: View {
    let item: PracticeItem
    let selectedLetter: String
    let isCorrect: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Result icon and message
            VStack(spacing: 12) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isCorrect ? .green : .red)
                
                Text(isCorrect ? "Correct!" : "Incorrect")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(isCorrect ? .green : .red)
            }
            .padding(.top, 40)
            
            // Complete word revealed
            VStack(spacing: 8) {
                Text("Complete word:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(item.word)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                    .tracking(2)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Next button
            Button(action: onNext) {
                HStack {
                    Text("Next Question")
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack {
        PracticeResultCard(
            item: PracticeItem(
                word: "გამარჯობა",
                missingIndex: 3,
                correctLetter: "ა",
                options: ["ა", "ო", "ე"],
                explanation: "Common greeting - 'hello'"
            ),
            selectedLetter: "ა",
            isCorrect: true,
            onNext: {
                print("Next tapped")
            }
        )
    }
}

