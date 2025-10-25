//
//  PracticeCompletionView.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//  Shows completion screen with options to generate new batch or restart
//

import SwiftUI

/// View shown after completing all practice questions
/// Think of this as a Vue component: <PracticeCompletionView @generateNew="handleGenerateNew" @restart="handleRestart" />
struct PracticeCompletionView: View {
    let totalQuestions: Int
    let onGenerateNew: () -> Void
    let onRestart: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Celebration icon
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            // Completion message
            VStack(spacing: 12) {
                Text("Practice Complete!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("You completed \(totalQuestions) questions")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Generate new practice
                Button(action: onGenerateNew) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate New Practice")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.georgianRed)
                    .cornerRadius(12)
                }
                
                // Restart this batch
                Button(action: onRestart) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Restart This Batch")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.georgianRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    PracticeCompletionView(
        totalQuestions: 15,
        onGenerateNew: {
            print("Generate new tapped")
        },
        onRestart: {
            print("Restart tapped")
        }
    )
}

