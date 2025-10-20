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
    let conversationId: String?
    
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    
    init(recipientId: String, recipientName: String, conversationId: String? = nil) {
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ChatViewModel(recipientId: recipientId, conversationId: conversationId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Network status banner
            NetworkStatusView()
                .animation(.easeInOut, value: NetworkMonitor.shared.connectionQuality)
                .animation(.easeInOut, value: MessageQueueService.shared.queueCount)
            
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
        .onAppear {
            viewModel.markMessagesAsRead()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.markMessagesAsRead()
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
}

