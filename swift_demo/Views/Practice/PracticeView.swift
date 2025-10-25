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
    @State private var showPracticeLanding = true
    
    var body: some View {
        NavigationStack {
            if showPracticeLanding {
                PracticeLandingView(
                    onStartLetters: {
                        // TODO: Navigate to letter practice
                        print("Letter practice not yet implemented")
                    },
                    onStartQuestions: {
                        showPracticeLanding = false
                    }
                )
            } else {
                PracticeQuestionsView(onBack: {
                    showPracticeLanding = true
                })
            }
        }
    }
}

/// Landing screen for practice options
struct PracticeLandingView: View {
    let onStartLetters: () -> Void
    let onStartQuestions: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.georgianRed)
                
                Text("Practice Georgian")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Improve your Georgian spelling with personalized exercises")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 60)
            
            // Practice button
            Button(action: onStartQuestions) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.georgianRed)
                    
                    Text("Start Practice")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Test your spelling with smart exercises")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.georgianRed.opacity(0.3), lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Questions practice view (existing practice functionality)
struct PracticeQuestionsView: View {
    @StateObject private var viewModel = PracticeViewModel()
    let onBack: () -> Void
    
    var body: some View {
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
                        onNext: {
                            viewModel.nextQuestion()
                        }
                    )
                }
            }
        }
        .navigationTitle("Practice Questions")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .onAppear {
            // Auto-load batch on first appear if empty (uses cache if available)
            if viewModel.currentBatch.isEmpty && viewModel.error == nil && !viewModel.isLoading {
                Task {
                    await viewModel.loadInitialBatch()
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
                        .fill(Color.georgianRed)
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
                .tint(.georgianRed)
            
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
                    .background(Color.georgianRed)
                    .cornerRadius(8)
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.georgianRed)
            
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
                    await viewModel.loadInitialBatch()
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
                .background(Color.georgianRed)
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

