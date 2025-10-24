//
//  MessageListView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct MessageListView: View {
    let messages: [MessageEntity]
    let currentUserId: String
    let getSenderName: ((MessageEntity) -> String?)? // Added for PR-17
    let onRetry: ((String) -> Void)?
    let onDelete: ((String) -> Void)?
    
    // Timestamp reveal state for all messages
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear
                        .frame(height: 0)
                        .frame(maxWidth: .infinity)
                    
                    if messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No messages yet")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("Start the conversation!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                // Show date separator if different day from previous message
                                if shouldShowDateSeparator(at: index) {
                                    DateSeparatorView(date: message.timestamp)
                                }
                                
                                    MessageBubbleView(
                                        message: message,
                                        isFromCurrentUser: {
                                            let isFromCurrent = message.senderId == currentUserId
                                            let textPreview = message.text?.prefix(20) ?? (message.imageUrl != nil ? "Image" : "Empty")
                                            let georgianFlag = GeorgianScriptDetector.containsGeorgian(message.text ?? "") ? "🇬🇪" : "🇺🇸"
                                            print("\(georgianFlag) [MessageListView] \(message.id.prefix(8))")
                                            print("   Text: \(textPreview)")
                                            print("   SenderId: '\(message.senderId)'")
                                            print("   CurrentUserId: '\(currentUserId)'")
                                            print("   isFromCurrent: \(isFromCurrent) → Will appear on \(isFromCurrent ? "RIGHT" : "LEFT")")
                                            return isFromCurrent
                                        }(),
                                        senderName: getSenderName?(message), // Added for PR-17
                                        onRetry: { onRetry?(message.id) },
                                        onDelete: { onDelete?(message.id) },
                                        dragOffset: dragOffset
                                    )
                                    .padding(.top, messageSpacing(at: index))
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .background(
                    // Full-screen gesture capture area
                    Color.clear
                        .contentShape(Rectangle())
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { gesture in
                            let translation = gesture.translation
                            
                            // Determine if this is a horizontal or vertical drag
                            if !isDraggingHorizontally {
                                let isHorizontal = abs(translation.width) > abs(translation.height)
                                if isHorizontal && translation.width < 0 {
                                    // It's a left swipe, capture it
                                    isDraggingHorizontally = true
                                } else {
                                    // It's vertical or right swipe, let ScrollView handle it
                                    return
                                }
                            }
                            
                            // Only process if we're in horizontal drag mode
                            if isDraggingHorizontally {
                                // Only allow dragging to the left (negative)
                                let horizontalTranslation = translation.width
                                if horizontalTranslation < 0 {
                                    // Elastic resistance: smooth up to 80, then increasing resistance
                                    let absTranslation = abs(horizontalTranslation)
                                    if absTranslation <= 80 {
                                        dragOffset = horizontalTranslation
                                    } else {
                                        // Apply elastic resistance beyond 80
                                        let excess = absTranslation - 80
                                        let resistance = excess / 3.5 // Elastic dampening
                                        dragOffset = -80 - resistance
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            // Reset state
                            isDraggingHorizontally = false
                            
                            // Elastic drift with slow, bouncy return
                            withAnimation(.spring(response: 1.8, dampingFraction: 0.45, blendDuration: 0)) {
                                dragOffset = 0
                            }
                        }
                )
                .onChange(of: messages.count) { oldValue, newValue in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: messages) { oldValue, newValue in
                    // Scroll when messages array changes (e.g., initial load)
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    // Use Task to ensure layout is complete before scrolling
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = messages.last else { return }
        
        if animated {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true } // Always show for first message
        
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        return !currentMessage.timestamp.isSameDay(as: previousMessage.timestamp)
    }
    
    /// Calculate spacing between messages based on time difference
    /// - Messages within 60 seconds: 2 points (almost touching)
    /// - Messages more than 60 seconds apart: 10 points (slightly larger gap)
    private func messageSpacing(at index: Int) -> CGFloat {
        guard index > 0 else { return 0 } // First message has no top padding
        
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        // Calculate time difference in seconds
        let timeDifference = currentMessage.timestamp.timeIntervalSince(previousMessage.timestamp)
        
        // If messages are from different days (date separator shown), use larger spacing
        if !currentMessage.timestamp.isSameDay(as: previousMessage.timestamp) {
            return 4 // Minimal spacing after date separator
        }
        
        // Messages within 60 seconds get minimal spacing
        if timeDifference < 60 {
            return 2
        } else {
            // Messages more than 60 seconds apart get slightly larger spacing
            return 10
        }
    }
}

