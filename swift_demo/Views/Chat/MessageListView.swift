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
    let onRetry: ((String) -> Void)?
    let onDelete: ((String) -> Void)?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
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
                    LazyVStack(spacing: 8) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            // Show date separator if different day from previous message
                            if shouldShowDateSeparator(at: index) {
                                DateSeparatorView(date: message.timestamp)
                            }
                            
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == currentUserId,
                                onRetry: { onRetry?(message.id) },
                                onDelete: { onDelete?(message.id) }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: messages.count) { oldValue, newValue in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true } // Always show for first message
        
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        return !currentMessage.timestamp.isSameDay(as: previousMessage.timestamp)
    }
}

