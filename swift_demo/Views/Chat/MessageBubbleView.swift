//
//  MessageBubbleView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    let senderName: String? // Added for PR-17
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    @State private var showFullScreenImage = false // PR-10
    
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
                    Text(text)
                        .padding(12)
                        .background(bubbleColor)
                        .foregroundColor(textColor)
                        .cornerRadius(16)
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
}

