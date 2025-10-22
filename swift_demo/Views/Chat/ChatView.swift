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
            
            // In Vue: <MessageInput v-model:text="messageText" v-model:focused="isInputFocused" @send="sendMessage" @sendImage="sendImage" @textChange="viewModel.handleTextFieldChange" />
            MessageInputView(
                text: $messageText,
                onSend: sendMessage,
                onSendImage: sendImage, // PR-9
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
        .onChange(of: isInputFocused) { oldValue, newValue in
            // Stop typing when keyboard is dismissed
            if !newValue {
                print("⌨️ [ChatView] Keyboard dismissed, stopping typing indicator")
                viewModel.stopTypingIndicator()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.markMessagesAsRead()
                notificationService.currentConversationId = viewModel.conversationId
            } else if newPhase == .background || newPhase == .inactive {
                notificationService.currentConversationId = nil
                // Stop typing when app goes to background
                print("📱 [ChatView] App backgrounded, stopping typing indicator")
                viewModel.stopTypingIndicator()
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
    
    // PR-9: Send image message
    private func sendImage(_ image: UIImage) {
        print("📸 [ChatView] sendImage called")
        viewModel.sendImage(image)
    }
}

// MARK: - PR-3: Chat Header with Typing Indicator

/// Custom chat header that shows typing indicator or online status
/// In Vue: const ChatHeader = defineComponent({ props: ['recipientName', 'typingText', 'isOnline'] })
struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    let recipientName: String
    
    @State private var recipientUser: User?
    
    // Computed property to check if this is a self-chat
    private var isSelfChat: Bool {
        viewModel.recipientId == viewModel.currentUserId
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isGroup {
                // PR-16: Group - Show name and typing indicator
                VStack(alignment: .center, spacing: 2) {
                    Text(viewModel.groupName ?? "Group Chat")
                        .font(.headline)
                    
                    // Show typing indicator or participant count
                    if let typingText = viewModel.typingText {
                        HStack(spacing: 4) {
                            Text(typingText)
                                .font(.caption)
                                .foregroundColor(.green)
                            TypingDotsView()
                        }
                        .transition(.opacity)
                    } else {
                        Text("\(viewModel.participants.count) participants")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // PR-16: 1-on-1 - Show avatar + name + status
                AvatarView(user: recipientUser, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipientUser?.displayName ?? recipientName)
                        .font(.headline)
                    
                    // Typing indicator or status (hide status for self-chats)
                    if let typingText = viewModel.typingText {
                        HStack(spacing: 4) {
                            Text(typingText)
                                .font(.caption)
                                .foregroundColor(.green)
                            TypingDotsView()
                        }
                        .transition(.opacity)
                    } else if !isSelfChat {
                        OnlineStatusView(
                            isOnline: viewModel.recipientOnline,
                            lastSeen: viewModel.recipientLastSeen
                        )
                        .font(.caption)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.typingText)
        .task {
            await loadRecipientUser()
        }
    }
    
    private func loadRecipientUser() async {
        guard !viewModel.isGroup else { return }
        
        do {
            recipientUser = try await UserService.shared.fetchUser(byId: viewModel.recipientId)
            print("✅ [ChatHeader] Loaded recipient user: \(recipientUser?.displayName ?? "Unknown")")
        } catch {
            print("❌ [ChatHeader] Failed to load recipient user: \(error)")
        }
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

