//
//  PracticeViewModel.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//  Similar to ChatViewModel pattern - manages UI state and user interactions
//

import Foundation
import SwiftUI
import Combine

/// ViewModel managing practice session state
/// Think of this as a Vue component's data() and methods combined
@MainActor
class PracticeViewModel: ObservableObject {
    @Published var currentBatch: [PracticeItem] = []
    @Published var currentIndex: Int = 0
    @Published var selectedLetter: String?
    @Published var showResult: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: PracticeError?
    @Published var practiceSource: PracticeSource?
    
    private let practiceService = PracticeService.shared
    
    // MARK: - Computed Properties
    
    var currentItem: PracticeItem? {
        guard currentIndex >= 0 && currentIndex < currentBatch.count else {
            return nil
        }
        return currentBatch[currentIndex]
    }
    
    var isLastQuestion: Bool {
        return currentIndex == currentBatch.count - 1
    }
    
    var hasMoreQuestions: Bool {
        return currentIndex < currentBatch.count - 1
    }
    
    var hasReachedEnd: Bool {
        return currentIndex >= currentBatch.count
    }
    
    var progress: (current: Int, total: Int) {
        return (currentIndex + 1, currentBatch.count)
    }
    
    var isAnswerCorrect: Bool {
        guard let selected = selectedLetter,
              let item = currentItem else {
            return false
        }
        return item.isCorrect(selected)
    }
    
    // MARK: - Public API
    
    /// Load initial practice batch (uses cache if available)
    func loadInitialBatch() async {
        isLoading = true
        error = nil
        selectedLetter = nil
        showResult = false
        currentIndex = 0
        
        // Log analytics
        logAnalytics(event: "practice_batch_requested", params: [
            "forceRefresh": false,
            "initial": true
        ])
        
        do {
            // Use cache if available for initial load
            let response = try await practiceService.fetchPracticeBatch(forceRefresh: false)
            
            await MainActor.run {
                currentBatch = response.items
                practiceSource = response.source
                isLoading = false
                
                // Log success
                logAnalytics(event: "practice_batch_generated", params: [
                    "source": response.source.rawValue,
                    "itemCount": response.items.count,
                    "initial": true
                ])
            }
            
        } catch let practiceError as PracticeError {
            await MainActor.run {
                error = practiceError
                isLoading = false
                
                // Log error
                logAnalytics(event: "practice_batch_error", params: [
                    "errorType": String(describing: practiceError),
                    "initial": true
                ])
            }
        } catch {
            await MainActor.run {
                self.error = .generationFailed
                isLoading = false
            }
        }
    }
    
    /// Generate a new practice batch (bypasses caches for fresh questions)
    func generateNewBatch() async {
        isLoading = true
        error = nil
        selectedLetter = nil
        showResult = false
        currentIndex = 0
        
        // Log analytics
        logAnalytics(event: "practice_batch_requested", params: [
            "forceRefresh": true,
            "initial": false
        ])
        
        do {
            // Force refresh to bypass both client and server caches
            let response = try await practiceService.fetchPracticeBatch(forceRefresh: true)
            
            await MainActor.run {
                currentBatch = response.items
                practiceSource = response.source
                isLoading = false
                
                // Log success
                logAnalytics(event: "practice_batch_generated", params: [
                    "source": response.source.rawValue,
                    "itemCount": response.items.count
                ])
            }
            
        } catch let practiceError as PracticeError {
            await MainActor.run {
                error = practiceError
                isLoading = false
                
                // Log error
                logAnalytics(event: "practice_batch_error", params: [
                    "errorType": String(describing: practiceError)
                ])
            }
        } catch {
            await MainActor.run {
                self.error = .generationFailed
                isLoading = false
            }
        }
    }
    
    /// Submit an answer for the current question
    func submitAnswer(_ letter: String) {
        guard currentItem != nil else { return }
        
        selectedLetter = letter
        showResult = true
        
        // Haptic feedback
        if isAnswerCorrect {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        // Log analytics
        logAnalytics(event: "practice_question_answered", params: [
            "questionIndex": currentIndex,
            "correct": isAnswerCorrect,
            "letter": letter,
            "source": practiceSource?.rawValue ?? "unknown"
        ])
    }
    
    /// Move to next question
    func nextQuestion() {
        // Allow advancing past last question to trigger completion
        currentIndex += 1
        selectedLetter = nil
        showResult = false
    }
    
    /// Restart the current batch
    func restartBatch() {
        currentIndex = 0
        selectedLetter = nil
        showResult = false
        
        // Log analytics
        logAnalytics(event: "practice_batch_restarted")
    }
    
    /// Check if batch is completed
    func isBatchCompleted() -> Bool {
        return hasReachedEnd
    }
    
    /// Get completion statistics
    func getCompletionStats() -> (correct: Int, total: Int) {
        // Note: Since we don't persist answers, we can't show actual stats
        // This is a placeholder for future enhancement
        return (0, currentBatch.count)
    }
    
    /// Clear error state
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Helpers
    
    private func logAnalytics(event: String, params: [String: Any] = [:]) {
        print("📊 [PracticeAnalytics] \(event): \(params)")
        // TODO: Integrate with actual analytics service if needed
    }
}

