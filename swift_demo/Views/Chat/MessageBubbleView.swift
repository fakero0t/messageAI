//
//  MessageBubbleView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    let senderName: String? // Added for PR-17
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    @State private var showFullScreenImage = false // PR-10
    @State private var isExpanded = false
    @State private var isLoading = false
    @State private var translatedEN: String = ""
    @State private var translatedKA: String = ""
    @State private var nlSheetText: String? = nil
    
    // AI V3: Definition lookup
    @State private var showDefinitionModal = false
    @State private var definitionResult: DefinitionResult? = nil
    @State private var definitionError: Error? = nil
    @State private var isLoadingDefinition = false
    @State private var highlightedWordRange: Range<String.Index>? = nil
    
    var body: some View {
        // Calculate available width for text wrapping
        let maxBubbleWidth = UIScreen.main.bounds.width * 0.75
        let contentWidth = maxBubbleWidth - 24  // Subtract horizontal padding (12 * 2)
        
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name for group messages (PR-17)
                if !isFromCurrentUser, let senderName = senderName {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                // PR-10: Display image or text message
                if message.isImageMessage {
                    ImageMessageView(
                        message: message,
                        isFromCurrentUser: isFromCurrentUser,
                        onTap: {
                            print("🖼️ [MessageBubble] Opening full-screen viewer for: \(message.id)")
                            showFullScreenImage = true
                        }
                    )
                } else if let text = message.text {
                    ZStack {
                        if isExpanded {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("🇺🇸")
                                    Text(translatedEN.isEmpty ? text : translatedEN)
                                }
                                Divider()
                                HStack(alignment: .top, spacing: 6) {
                                    Text("🇬🇪")
                                    // AI V3: Use TappableTextView for Georgian in expanded view
                                    let georgianText = translatedKA.isEmpty ? text : translatedKA
                                    if GeorgianScriptDetector.containsGeorgian(georgianText) {
                                        LongPressableText(
                                            text: georgianText,
                                            font: .body,
                                            color: textColor,
                                            alignment: .leading,
                                            maxWidth: contentWidth - 30
                                        ) { word, fullContext in
                                            handleLongPressWord(word: word, fullContext: fullContext)
                                        }
                                    } else {
                                        Text(georgianText)
                                    }
                                }
                            }
                            .padding(12)
                            .background(bubbleColor)
                            .foregroundColor(textColor)
                            .cornerRadius(16)
                            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                            .onTapGesture(count: 2) {
                                handleDoubleTap()
                            }
                        } else {
                            // AI V3: Use TappableTextView for Georgian text to detect exact word
                            if GeorgianScriptDetector.containsGeorgian(text) {
                                LongPressableText(
                                    text: text,
                                    font: .body,
                                    color: textColor,
                                    alignment: isFromCurrentUser ? .trailing : .leading,
                                    maxWidth: contentWidth
                                ) { word, fullContext in
                                    handleLongPressWord(word: word, fullContext: fullContext)
                                }
                                .padding(12)
                                .background(bubbleColor)
                                .cornerRadius(16)
                                .frame(maxWidth: maxBubbleWidth, alignment: isFromCurrentUser ? .trailing : .leading)
                                .onTapGesture(count: 2) {
                                    handleDoubleTap()
                                }
                            } else {
                                // Regular text for non-Georgian messages
                                Text(text)
                                    .padding(12)
                                    .background(bubbleColor)
                                    .foregroundColor(textColor)
                                    .cornerRadius(16)
                                    .frame(maxWidth: maxBubbleWidth, alignment: isFromCurrentUser ? .trailing : .leading)
                                    .onTapGesture(count: 2) {
                                        handleDoubleTap()
                                    }
                            }
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    Text(message.timestamp.chatTimestamp())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        statusIndicator
                    }
                }
                
                if message.status == .failed && isFromCurrentUser {
                    FailedMessageActionsView(onRetry: onRetry, onDelete: onDelete)
                }
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.2), value: message.status)
        .sheet(isPresented: $showFullScreenImage) {
            FullScreenImageView(
                imageUrl: message.imageUrl,
                localImage: nil,
                message: message
            )
        }
        .sheet(item: Binding(
            get: { nlSheetText.map { NLSheetWrapper(text: $0) } },
            set: { nlSheetText = $0?.text }
        )) { payload in
            ScrollView { Text(payload.text).padding() }
        }
        // AI V3: Definition modal
        .sheet(isPresented: $showDefinitionModal) {
            if isLoadingDefinition {
                DefinitionLoadingView()
            } else if let error = definitionError {
                DefinitionErrorView(error: error)
            } else if let result = definitionResult {
                DefinitionModalView(result: result)
            }
        }
        .onAppear {
            // Load existing translations from message entity
            if let en = message.translatedEn, !en.isEmpty {
                translatedEN = en
            }
            if let ka = message.translatedKa, !ka.isEmpty {
                translatedKA = ka
            }
        }
    }
    
    private var bubbleColor: Color {
        if message.status == .failed {
            return Color.red.opacity(0.7)
        }
        return isFromCurrentUser ? Color.blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        if isFromCurrentUser {
            return .white
        }
        return .primary
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch message.status {
        case .pending:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        case .sent, .queued:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .delivered:
            // Double checkmark (gray) for delivered but not read
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        case .read:
            // Double checkmark (blue) for read
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundColor(.blue)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }

    private func handleDoubleTap() {
        print("👆 [MessageBubble] Double-tap on message: \(message.id)")
        guard let text = message.text else {
            print("⚠️ [MessageBubble] Guard failed: no text")
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // If we already have both translations, just toggle
        if !translatedEN.isEmpty && !translatedKA.isEmpty {
            withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            return
        }
        
        // Try loading from message entity first
        if let storedEN = message.translatedEn, !storedEN.isEmpty,
           let storedKA = message.translatedKa, !storedKA.isEmpty {
            print("💾 [MessageBubble] Loaded both translations from message entity")
            translatedEN = storedEN
            translatedKA = storedKA
            withAnimation(.spring(response: 0.3)) { isExpanded = true }
            return
        }
        
        // Try local cache
        if let cached = TranslationCacheService.shared.get(text: text) {
            print("💾 [MessageBubble] Cache hit for text hash")
            translatedEN = cached.translations.en
            translatedKA = cached.translations.ka
            
            // Save to local storage
            saveTranslationToStorage(en: cached.translations.en, ka: cached.translations.ka)
            
            withAnimation(.spring(response: 0.3)) {
                isExpanded = true
            }
            return
        }
        
        print("🌐 [MessageBubble] Cache miss → expand immediately and request SSE translation")
        // Expand immediately with placeholders so there's no loading state
        translatedEN = ""
        translatedKA = ""
        withAnimation(.spring(response: 0.3)) { isExpanded = true }
        
        let tsMs = Int64(Date().timeIntervalSince1970 * 1000)
        TranslationTransport.shared.requestTranslation(
            messageId: message.id,
            text: text,
            conversationId: message.conversationId,
            timestampMs: tsMs
        ) { result in
            print("📨 [MessageBubble] SSE completion for message \(message.id) result=\(result != nil)")
            Task { @MainActor in
                guard let result = result else { return }
                
                self.translatedEN = result.translations.en
                self.translatedKA = result.translations.ka
                
                // Save to local storage
                self.saveTranslationToStorage(en: result.translations.en, ka: result.translations.ka)
                
                withAnimation(.spring(response: 0.3)) {
                    self.isExpanded = true
                }
            }
        }
    }
    
    private func saveTranslationToStorage(en: String, ka: String) {
        Task { @MainActor in
            do {
                try await LocalStorageService.shared.updateMessageTranslation(
                    messageId: message.id,
                    translatedEn: en,
                    translatedKa: ka,
                    originalLang: GeorgianScriptDetector.containsGeorgian(message.text ?? "") ? "ka" : "en"
                )
                print("💾 [MessageBubble] Saved translation to local storage")
            } catch {
                print("⚠️ [MessageBubble] Failed to save translation: \(error)")
            }
        }
    }

    private func runNL(intent: String, text: String) {
        let start = Date()
        let tsMs = Int64(start.timeIntervalSince1970 * 1000)
        TranslationTransport.shared.requestNLCommand(
            intent: intent,
            text: text,
            conversationId: message.conversationId,
            timestampMs: tsMs
        ) { result in
            DispatchQueue.main.async {
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                TranslationAnalytics.shared.logNLCommand(intent: intent, latencyMs: elapsed)
                self.nlSheetText = result
            }
        }
    }
    
    // AI V3: Handle long-press for word definition lookup (from TappableTextView)
    private func handleLongPressWord(word: String, fullContext: String) {
        print("👆 [MessageBubble] Long-press for definition lookup")
        print("📖 [MessageBubble] Word: \(word)")
        print("📝 [MessageBubble] Context: \(fullContext)")
        
        // Haptic feedback already handled by TappableTextView
        
        // Show loading state
        isLoadingDefinition = true
        definitionError = nil
        definitionResult = nil
        showDefinitionModal = true
        
        // Fetch definition for the exact word that was pressed
        Task { @MainActor in
            do {
                let result = try await DefinitionService.shared.fetchDefinition(
                    word: word,
                    conversationId: message.conversationId,
                    fullContext: fullContext
                )
                
                isLoadingDefinition = false
                definitionResult = result
                print("✅ [MessageBubble] Definition loaded for: \(word)")
                
            } catch {
                isLoadingDefinition = false
                definitionError = error
                print("❌ [MessageBubble] Definition error: \(error)")
            }
        }
    }
    
    // Legacy handler for expanded view long-press (still extracts first word)
    private func handleLongPress(text: String) {
        print("👆 [MessageBubble] Long-press in expanded view")
        
        // Extract first Georgian word as fallback
        guard let extractedWord = extractFirstGeorgianWord(from: text) else {
            print("⚠️ [MessageBubble] No Georgian word found")
            return
        }
        
        // Use the same handler with the extracted word
        handleLongPressWord(word: extractedWord, fullContext: text)
    }
    
    // Extract first Georgian word from text (used for expanded view)
    private func extractFirstGeorgianWord(from text: String) -> String? {
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text
        
        let range = NSRange(location: 0, length: (text as NSString).length)
        var firstGeorgianWord: String? = nil
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: [.omitWhitespace, .omitPunctuation]) { _, tokenRange, _ in
            if let swiftRange = Range(tokenRange, in: text) {
                let word = String(text[swiftRange])
                if GeorgianScriptDetector.containsGeorgian(word) {
                    firstGeorgianWord = WordBoundaryDetector.stripPunctuation(from: word)
                    return // Stop after first Georgian word
                }
            }
        }
        
        return firstGeorgianWord
    }
}

private struct NLSheetWrapper: Identifiable {
    let id = UUID()
    let text: String
}

