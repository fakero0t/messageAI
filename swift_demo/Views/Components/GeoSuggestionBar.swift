//
//  GeoSuggestionBar.swift
//  swift_demo
//
//  Created for PR-4: Suggestion Bar with Loading/Error States
//

import SwiftUI

/// Bar displaying Georgian word suggestions OR English→Georgian translation suggestions
/// AI V3: Extended to support both suggestion types (never both simultaneously)
/// Think of this as a Vue component managing async state: <SuggestionBar v-model:text="messageText" />
struct GeoSuggestionBar: View {
    @Binding var messageText: String
    @Binding var undoText: String?
    @Binding var hasSuggestions: Bool
    let onTextChange: (String) -> Void
    
    @StateObject private var suggestionService = GeoSuggestionService.shared
    @StateObject private var wordUsageService = WordUsageTrackingService.shared
    @StateObject private var englishSuggestionService = EnglishTranslationSuggestionService.shared
    @StateObject private var englishUsageService = EnglishUsageTrackingService.shared
    private let analytics = TranslationAnalytics.shared
    
    @State private var suggestions: [GeoSuggestion] = []
    @State private var baseWord: String?
    @State private var suggestionSource: SuggestionSource?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var showUndo = false
    @State private var debounceTask: Task<Void, Never>?
    
    // AI V3: English suggestion state
    @State private var englishSuggestions: [EnglishSuggestion] = []
    @State private var baseEnglishWord: String?
    @State private var suggestionType: SuggestionType = .georgian
    
    var body: some View {
        // Check User model for Georgian Learning Mode setting
        let isEnabled = AuthenticationService.shared.currentUser?.georgianLearningMode ?? false
        
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
                .foregroundColor(.georgianRed)
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
            
        } else if suggestionType == .georgian && !suggestions.isEmpty {
            // Georgian suggestions
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
            
        } else if suggestionType == .english && !englishSuggestions.isEmpty {
            // AI V3: English→Georgian translation suggestions
            VStack(alignment: .leading, spacing: 8) {
                if let base = baseEnglishWord {
                    Text("You use '\(base)' often. Try using one of these Georgian translations!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(englishSuggestions) { suggestion in
                            EnglishSuggestionChip(
                                suggestion: suggestion,
                                onAccept: {
                                    acceptEnglishSuggestion(suggestion)
                                },
                                onDismiss: {
                                    dismissEnglishSuggestions()
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
            // Check User model for Georgian Learning Mode setting
            let isEnabled = AuthenticationService.shared.currentUser?.georgianLearningMode ?? false
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
    /// AI V3: Priority - Check Georgian first, then English (never both)
    func checkForSuggestions() {
        // Cancel any existing debounce task
        debounceTask?.cancel()
        
        // Debounce: only check when user pauses typing
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Check if we were cancelled
            guard !Task.isCancelled else { return }
            
            // PRIORITY 1: Check Georgian suggestions first
            if let triggerWord = suggestionService.shouldShowSuggestion(for: messageText) {
                // Show loading state
                isLoading = true
                hasError = false
                baseWord = triggerWord
                suggestionType = .georgian
                
                // Fetch Georgian suggestions
                if let response = await suggestionService.fetchSuggestions(for: triggerWord) {
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
                    return // Exit early if Georgian suggestions found
                }
            }
            
            // PRIORITY 2: Check English suggestions (only if no Georgian)
            guard let userId = AuthenticationService.shared.currentUser?.id else {
                clearAllSuggestions()
                return
            }
            
            if let englishWord = englishSuggestionService.shouldShowEnglishSuggestion(for: messageText, userId: userId) {
                // Show loading state
                isLoading = true
                hasError = false
                baseEnglishWord = englishWord
                suggestionType = .english
                
                // Get user's conversation ID (assume first conversation for now)
                let conversationId = messageText.isEmpty ? "" : "temp_conv_id"
                
                // Fetch English suggestions
                if let response = await englishSuggestionService.fetchSuggestions(for: englishWord, conversationId: conversationId) {
                    guard !Task.isCancelled else { return }
                    
                    isLoading = false
                    englishSuggestions = Array(response.suggestions.prefix(3)) // Max 3 chips
                    
                    // Log exposure event
                    let baseWordHash = analytics.hashWord(englishWord)
                    let threshold = englishUsageService.calculateDynamicThreshold(userId: userId)
                    analytics.logEnglishSuggestionExposed(
                        englishWord: englishWord,
                        wordHash: baseWordHash,
                        suggestionCount: englishSuggestions.count,
                        userVelocity: threshold
                    )
                    return
                }
            }
            
            // No suggestions available
            clearAllSuggestions()
        }
    }
    
    /// Clear all suggestion states
    private func clearAllSuggestions() {
        suggestions = []
        englishSuggestions = []
        baseWord = nil
        baseEnglishWord = nil
        isLoading = false
        hasError = false
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
    
    /// Dismiss Georgian suggestions
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
    
    // AI V3: Accept English suggestion with smart replace
    private func acceptEnglishSuggestion(_ suggestion: EnglishSuggestion) {
        let previousText = messageText
        guard let englishWord = baseEnglishWord else { return }
        
        // Log click event
        let englishHash = analytics.hashWord(englishWord)
        let georgianHash = analytics.hashWord(suggestion.word)
        analytics.logEnglishSuggestionClicked(
            englishWord: englishWord,
            wordHash: englishHash,
            georgianWord: suggestion.word,
            georgianHash: georgianHash,
            formality: suggestion.formality
        )
        
        // Smart replace: if English word in text, replace it; otherwise append
        let newText: String
        let action: String
        
        if messageText.lowercased().contains(englishWord.lowercased()) {
            // Replace first occurrence of English word
            if let range = messageText.range(of: englishWord, options: [.caseInsensitive]) {
                newText = messageText.replacingCharacters(in: range, with: suggestion.word)
                action = "replace"
            } else {
                // Fallback to append
                newText = messageText.hasSuffix(" ") || messageText.isEmpty
                    ? messageText + suggestion.word
                    : messageText + " " + suggestion.word
                action = "append"
            }
        } else {
            // Append with smart punctuation
            newText = messageText.hasSuffix(" ") || messageText.isEmpty
                ? messageText + suggestion.word
                : messageText + " " + suggestion.word
            action = "append"
        }
        
        messageText = newText
        onTextChange(newText)
        
        // Log acceptance event
        analytics.logEnglishSuggestionAccepted(
            englishWord: englishWord,
            wordHash: englishHash,
            georgianWord: suggestion.word,
            georgianHash: georgianHash,
            action: action
        )
        
        // Show undo with previous text
        undoText = previousText
        showUndo = true
        
        // Clear suggestions
        englishSuggestions = []
        baseEnglishWord = nil
        
        // Auto-hide undo after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if showUndo {
                showUndo = false
                undoText = nil
            }
        }
    }
    
    // AI V3: Dismiss English suggestions
    private func dismissEnglishSuggestions() {
        // Log dismissal event
        if let englishWord = baseEnglishWord {
            let wordHash = analytics.hashWord(englishWord)
            analytics.logEnglishSuggestionDismissed(
                englishWord: englishWord,
                wordHash: wordHash
            )
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            englishSuggestions = []
            baseEnglishWord = nil
            hasError = false
        }
    }
}

// AI V3: Suggestion type enum
enum SuggestionType {
    case georgian
    case english
}

// AI V3: English suggestion chip component
struct EnglishSuggestionChip: View {
    let suggestion: EnglishSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.word)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(suggestion.gloss)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text(suggestion.contextHint)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .italic()
                
                Spacer()
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAccept()
                } label: {
                    Text("Use this")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.georgianRed)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

