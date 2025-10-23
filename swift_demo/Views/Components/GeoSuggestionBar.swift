//
//  GeoSuggestionBar.swift
//  swift_demo
//
//  Created for PR-4: Suggestion Bar with Loading/Error States
//

import SwiftUI

/// Bar displaying Georgian word suggestions above the message composer
/// Think of this as a Vue component managing async state: <SuggestionBar v-model:text="messageText" />
struct GeoSuggestionBar: View {
    @Binding var messageText: String
    @Binding var undoText: String?
    @Binding var hasSuggestions: Bool
    let onTextChange: (String) -> Void
    
    @StateObject private var suggestionService = GeoSuggestionService.shared
    @StateObject private var wordUsageService = WordUsageTrackingService.shared
    private let analytics = TranslationAnalytics.shared
    
    @State private var suggestions: [GeoSuggestion] = []
    @State private var baseWord: String?
    @State private var suggestionSource: SuggestionSource?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var showUndo = false
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        // PR-6: Respect global opt-out setting
        let isEnabled = !UserDefaults.standard.bool(forKey: "geoSuggestionsDisabled")
        
        Group {
            if !isEnabled {
                EmptyView()
            } else if showUndo, let previousText = undoText {
            // Undo snackbar
            HStack {
                Text("Word added")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Undo") {
                    messageText = previousText
                    onTextChange(previousText)
                    showUndo = false
                    undoText = nil
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .transition(.move(edge: .top).combined(with: .opacity))
            
        } else if isLoading {
            // Loading state
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        GeoSuggestionChipSkeleton()
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            
        } else if hasError {
            // Error state
            GeoSuggestionErrorChip {
                hasError = false
                baseWord = nil
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            
        } else if !suggestions.isEmpty {
            // Suggestions
            VStack(alignment: .leading, spacing: 8) {
                if let base = baseWord {
                    Text("You're able to use \(base) a lot. Now try using one of these in a sentence!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            GeoSuggestionChip(
                                suggestion: suggestion,
                                onAccept: {
                                    acceptSuggestion(suggestion)
                                },
                                onDismiss: {
                                    dismissSuggestions()
                                }
                            )
                            .frame(width: 200)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showUndo)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: hasError)
        .animation(.easeInOut(duration: 0.2), value: suggestions.count)
        .onChange(of: messageText) { oldValue, newValue in
            // PR-6: Only check if enabled
            let isEnabled = !UserDefaults.standard.bool(forKey: "geoSuggestionsDisabled")
            guard isEnabled else { return }
            
            // Trigger suggestion check when text changes
            if !newValue.isEmpty {
                checkForSuggestions()
            } else {
                // Clear suggestions when text is empty
                suggestions = []
                baseWord = nil
                isLoading = false
                hasError = false
                hasSuggestions = false
            }
        }
        .onChange(of: suggestions) { _, _ in
            hasSuggestions = !suggestions.isEmpty || isLoading
        }
        .onChange(of: isLoading) { _, _ in
            hasSuggestions = !suggestions.isEmpty || isLoading
        }
    }
    
    /// Check if we should show suggestions for the current text
    func checkForSuggestions() {
        // Cancel any existing debounce task
        debounceTask?.cancel()
        
        // Debounce: only check when user pauses typing
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Check if we were cancelled
            guard !Task.isCancelled else { return }
            
            guard let triggerWord = suggestionService.shouldShowSuggestion(for: messageText) else {
                suggestions = []
                baseWord = nil
                isLoading = false
                hasError = false
                return
            }
            
            // Show loading state
            isLoading = true
            hasError = false
            baseWord = triggerWord
            
            // Fetch suggestions
            if let response = await suggestionService.fetchSuggestions(for: triggerWord) {
                // Check again if we were cancelled while fetching
                guard !Task.isCancelled else { return }
                
                isLoading = false
                suggestions = Array(response.suggestions.prefix(3)) // Max 3 chips
                suggestionSource = response.source
                
                // Log exposure event
                let baseWordHash = analytics.hashWord(triggerWord)
                analytics.logSuggestionExposed(
                    baseWord: triggerWord,
                    baseWordHash: baseWordHash,
                    source: response.source,
                    suggestionCount: suggestions.count
                )
            } else {
                // No suggestions available - just hide quietly, don't show error
                // Error should only show for actual fetch failures, not "no results"
                isLoading = false
                hasError = false
                suggestions = []
                baseWord = nil
            }
        }
    }
    
    /// Accept a suggestion (replace selected or append)
    private func acceptSuggestion(_ suggestion: GeoSuggestion) {
        let previousText = messageText
        
        // Log click event
        if let base = baseWord, let source = suggestionSource {
            let baseHash = analytics.hashWord(base)
            let suggestionHash = analytics.hashWord(suggestion.word)
            analytics.logSuggestionClicked(
                baseWord: base,
                baseWordHash: baseHash,
                suggestion: suggestion.word,
                suggestionHash: suggestionHash,
                source: source
            )
        }
        
        // Logic: replace selected token else append
        // For MVP, we'll append with smart punctuation
        let action: String
        let newText: String
        if messageText.hasSuffix(" ") || messageText.isEmpty {
            newText = messageText + suggestion.word
            action = "append"
        } else {
            newText = messageText + " " + suggestion.word
            action = "append"
        }
        
        messageText = newText
        onTextChange(newText)
        
        // Log acceptance event
        if let base = baseWord, let source = suggestionSource {
            let baseHash = analytics.hashWord(base)
            let suggestionHash = analytics.hashWord(suggestion.word)
            analytics.logSuggestionAccepted(
                baseWord: base,
                baseWordHash: baseHash,
                suggestion: suggestion.word,
                suggestionHash: suggestionHash,
                source: source,
                action: action
            )
        }
        
        // Show undo with previous text
        undoText = previousText
        showUndo = true
        
        // Clear suggestions
        suggestions = []
        baseWord = nil
        suggestionSource = nil
        
        // Auto-hide undo after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if showUndo {
                showUndo = false
                undoText = nil
            }
        }
    }
    
    /// Dismiss suggestions
    private func dismissSuggestions() {
        // Log dismissal event
        if let base = baseWord, let source = suggestionSource {
            let baseHash = analytics.hashWord(base)
            analytics.logSuggestionDismissed(
                baseWord: base,
                baseWordHash: baseHash,
                source: source
            )
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            suggestions = []
            baseWord = nil
            suggestionSource = nil
            hasError = false
        }
    }
}

#Preview {
    @FocusState var isFocused: Bool
    
    return VStack {
        Spacer()
        
        GeoSuggestionBar(
            messageText: .constant("მადლობა"),
            undoText: .constant(nil),
            hasSuggestions: .constant(false),
            onTextChange: { _ in }
        )
        
        MessageInputView(
            text: .constant(""),
            onSend: {},
            isFocused: $isFocused
        )
    }
}

