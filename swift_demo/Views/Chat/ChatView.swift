//
//  ChatView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ChatView: View {
    let recipientId: String
    let recipientName: String
    
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    init(recipientId: String, recipientName: String) {
        self.recipientId = recipientId
        self.recipientName = recipientName
        _viewModel = StateObject(wrappedValue: ChatViewModel(recipientId: recipientId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                messages: viewModel.messages,
                currentUserId: viewModel.currentUserId,
                onRetry: { messageId in
                    viewModel.retryMessage(messageId: messageId)
                },
                onDelete: { messageId in
                    viewModel.deleteMessage(messageId: messageId)
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
            
            Divider()
            
            MessageInputView(text: $messageText) {
                sendMessage()
            }
        }
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(recipientName)
                        .font(.headline)
                    
                    OnlineStatusView(
                        isOnline: viewModel.recipientOnline,
                        lastSeen: viewModel.recipientLastSeen
                    )
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
}

