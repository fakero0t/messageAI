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
    
    var body: some View {
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
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Divider()
                                HStack(alignment: .top, spacing: 6) {
                                    Text("🇬🇪")
                                    Text(translatedKA.isEmpty ? text : translatedKA)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(12)
                            .background(bubbleColor)
                            .foregroundColor(textColor)
                            .cornerRadius(16)
                        } else {
                            Text(text)
                                .padding(12)
                                .background(bubbleColor)
                                .foregroundColor(textColor)
                                .cornerRadius(16)
                        }
                    }
                    .onTapGesture(count: 2) {
                        handleDoubleTap()
                    }
                    .contextMenu {
                        Button("Show Translation") { handleDoubleTap() }
                        if let text = message.text {
                            Button("Explain Slang/Idioms") { runNL(intent: "explain_slang", text: text) }
                            Button("Adjust Tone → Formal") { runNL(intent: "adjust_tone_formal", text: text) }
                            Button("Adjust Tone → Casual") { runNL(intent: "adjust_tone_casual", text: text) }
                            Button("Cultural Context Hint") { runNL(intent: "cultural_hint", text: text) }
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
        print("🔧 [MessageBubble] aiTranslationEnabled=true (forced)")
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
        
        // Try local cache first
        if let cached = TranslationCacheService.shared.get(text: text) {
            print("💾 [MessageBubble] Cache hit for text hash")
            translatedEN = cached.translations.en
            translatedKA = cached.translations.ka
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
            DispatchQueue.main.async {
                guard let result = result else { return }
                self.translatedEN = result.translations.en
                self.translatedKA = result.translations.ka
                withAnimation(.spring(response: 0.3)) {
                    self.isExpanded = true
                }
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
}

private struct NLSheetWrapper: Identifiable {
    let id = UUID()
    let text: String
}

