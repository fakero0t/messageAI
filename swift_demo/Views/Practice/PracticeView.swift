//
//  PracticeView.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//  Main practice interface - third tab in TabView
//

import SwiftUI

/// Main practice view orchestrating the practice flow
/// Think of this as a Vue page component managing child components and state
struct PracticeView: View {
    @StateObject private var viewModel = PracticeViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    // Loading state
                    loadingView
                } else if let error = viewModel.error {
                    // Error state
                    errorView(error)
                } else if viewModel.currentBatch.isEmpty {
                    // Empty state (initial)
                    emptyView
                } else if viewModel.isBatchCompleted() {
                    // Completion state
                    PracticeCompletionView(
                        totalQuestions: viewModel.currentBatch.count,
                        onGenerateNew: {
                            Task {
                                await viewModel.generateNewBatch()
                            }
                        },
                        onRestart: {
                            viewModel.restartBatch()
                        }
                    )
                } else if let item = viewModel.currentItem {
                    // Question state (includes result state)
                    VStack(spacing: 0) {
                        // Progress indicator
                        progressBar
                        
                        PracticeQuestionCard(
                            item: item,
                            selectedLetter: viewModel.selectedLetter,
                            showResult: viewModel.showResult,
                            onSelect: { letter in
                                viewModel.submitAnswer(letter)
                            },
                            onNext: viewModel.hasMoreQuestions ? {
                                viewModel.nextQuestion()
                            } : nil
                        )
                    }
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Auto-generate batch on first appear if empty
                if viewModel.currentBatch.isEmpty && viewModel.error == nil && !viewModel.isLoading {
                    Task {
                        await viewModel.generateNewBatch()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Question \(viewModel.progress.current) of \(viewModel.progress.total)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(viewModel.progress.current) / CGFloat(viewModel.progress.total), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Generating practice...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Analyzing your conversations")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: PracticeError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon(for: error))
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text(error.localizedDescription)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                viewModel.clearError()
                Task {
                    await viewModel.generateNewBatch()
                }
            }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Ready to Practice?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Improve your Georgian spelling with personalized exercises")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await viewModel.generateNewBatch()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Start Practice")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.top, 16)
        }
    }
    
    private func errorIcon(for error: PracticeError) -> String {
        switch error {
        case .offline:
            return "wifi.slash"
        case .notAuthenticated:
            return "person.fill.xmark"
        case .rateLimitExceeded:
            return "hourglass"
        case .noData:
            return "message.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
}

#Preview {
    PracticeView()
}

