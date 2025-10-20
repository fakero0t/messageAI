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
    @EnvironmentObject private var notificationService: NotificationService
    @State private var messageText = ""
    @State private var showGroupInfo = false // Added for PR-17
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
                    getSenderName: { message in // Added for PR-17
                        viewModel.getSenderName(for: message)
                    },
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
        .navigationTitle(viewModel.isGroup ? (viewModel.groupName ?? "Group Chat") : recipientName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if viewModel.isGroup {
                    // Group header - tappable to show info
                    Button {
                        showGroupInfo = true
                    } label: {
                        VStack(spacing: 2) {
                            Text(viewModel.groupName ?? "Group Chat")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(viewModel.participants.count) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // One-on-one header
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
        .sheet(isPresented: $showGroupInfo) {
            if let conversationId = conversationId {
                GroupInfoView(groupId: conversationId)
            }
        }
        .onAppear {
            viewModel.markMessagesAsRead()
            // Track that user entered this conversation
            notificationService.currentConversationId = viewModel.conversationId
        }
        .onDisappear {
            // User left conversation
            notificationService.currentConversationId = nil
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.markMessagesAsRead()
                notificationService.currentConversationId = viewModel.conversationId
            } else if newPhase == .background || newPhase == .inactive {
                notificationService.currentConversationId = nil
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
}

