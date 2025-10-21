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
            
            // In Vue: <MessageInput v-model:text="messageText" v-model:focused="isInputFocused" @send="sendMessage" @textChange="viewModel.handleTextFieldChange" />
            MessageInputView(
                text: $messageText,
                onSend: sendMessage,
                onTextChange: viewModel.handleTextFieldChange, // PR-3
                isFocused: $isInputFocused
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // PR-3: Custom header with typing indicator
                // In Vue: <ChatHeader :recipientName="recipientName" :typing="viewModel.typingText" />
                ChatHeaderView(
                    viewModel: viewModel,
                    recipientName: recipientName
                )
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
            
            // PR-3: Stop typing when leaving chat (call via public method)
            viewModel.stopTypingIndicator()
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

// MARK: - PR-3: Chat Header with Typing Indicator

/// Custom chat header that shows typing indicator or online status
/// In Vue: const ChatHeader = defineComponent({ props: ['recipientName', 'typingText', 'isOnline'] })
struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    let recipientName: String
    
    var body: some View {
        VStack(spacing: 2) {
            // Title (recipient name or group name)
            if viewModel.isGroup {
                Button {
                    // Tappable to show group info - not implemented in this PR
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
                Text(recipientName)
                    .font(.headline)
            }
            
            // Status or typing indicator
            // In Vue: <div v-if="typingText">{{ typingText }}<TypingDots /></div>
            if let typingText = viewModel.typingText {
                // Typing indicator
                HStack(spacing: 4) {
                    Text(typingText)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    // Animated dots
                    TypingDotsView()
                }
                .transition(.opacity)
            } else if !viewModel.isGroup {
                // Online status (only for 1-on-1)
                OnlineStatusView(
                    isOnline: viewModel.recipientOnline,
                    lastSeen: viewModel.recipientLastSeen
                )
                .font(.caption)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.typingText)
    }
}

// MARK: - Animated Typing Dots

/// Three animated dots that pulse to indicate typing
/// In Vue: <span class="typing-dot" v-for="i in 3" :style="{ animationDelay: `${i * 0.2}s` }"></span>
struct TypingDotsView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                    .opacity(animating ? 0.3 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

