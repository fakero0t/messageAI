//
//  ChatViewModel.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageEntity] = []
    @Published var recipientOnline = false
    @Published var recipientLastSeen: Date?
    @Published var errorMessage: String?
    @Published var isSending = false
    
    // Group-specific
    @Published var isGroup = false
    @Published var groupName: String?
    @Published var participants: [User] = []
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    private let listenerService = FirestoreListenerService.shared
    private let queueService = MessageQueueService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let readReceiptService = ReadReceiptService.shared
    private let userService = UserService.shared
    private let notificationService = NotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(recipientId: String, conversationId: String? = nil) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        
        // Use provided conversationId (for groups) or generate it (for one-on-one)
        if let conversationId = conversationId {
            self.conversationId = conversationId
        } else {
            self.conversationId = ConversationService.shared.generateConversationId(
                userId1: currentUserId,
                userId2: recipientId
            )
        }
        
        loadConversationDetails()
        loadLocalMessages()
        startListening()
        observeNetwork()
        markMessagesAsRead()
    }
    
    private func loadConversationDetails() {
        Task {
            do {
                if let conversation = try? localStorage.fetchConversation(byId: conversationId) {
                    isGroup = conversation.isGroup
                    groupName = conversation.groupName
                    
                    if isGroup {
                        // Load all participant details for groups
                        print("👥 Loading group details for: \(conversationId)")
                        for participantId in conversation.participantIds {
                            if let user = try? await userService.fetchUser(byId: participantId) {
                                participants.append(user)
                                print("  ✓ Loaded participant: \(user.displayName)")
                            }
                        }
                        print("  Total participants: \(participants.count)")
                    } else {
                        // Only observe recipient status for one-on-one chats
                        await MainActor.run {
                            observeRecipientStatus()
                        }
                    }
                } else {
                    // No conversation found in local storage (new chat)
                    // Assume one-on-one if recipientId is not empty
                    if !recipientId.isEmpty {
                        await MainActor.run {
                            observeRecipientStatus()
                        }
                    }
                }
            } catch {
                print("⚠️ Error loading conversation details: \(error)")
            }
        }
    }
    
    deinit {
        listenerService.stopListening(conversationId: conversationId)
    }
    
    func getSenderName(for message: MessageEntity) -> String? {
        guard isGroup else { return nil }
        return participants.first { $0.id == message.senderId }?.displayName
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty else { return }
        
        let messageId = UUID().uuidString
        
        // Determine initial status based on network
        let initialStatus: MessageStatus = networkMonitor.isConnected ? .pending : .queued
        
        // 1. Optimistic insert - show immediately
        let optimisticMessage = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: initialStatus
        )
        
        messages.append(optimisticMessage)
        
        // 2. Handle based on network status
        if networkMonitor.isConnected {
            sendOnline(messageId: messageId, text: text)
        } else {
            sendOffline(messageId: messageId, text: text)
        }
    }
    
    private func sendOnline(messageId: String, text: String) {
        Task {
            do {
                // Save locally first
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .pending
                )
                try await MainActor.run {
                    try localStorage.saveMessage(message)
                }
                updateMessageStatus(messageId: messageId, status: .sent)
                
                // Send to Firestore
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                print("✅ Message sent successfully")
                
            } catch {
                // If send fails, queue it
                print("⚠️ Send failed, queueing message: \(error)")
                updateMessageStatus(messageId: messageId, status: .queued)
                try? queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text
                )
            }
        }
    }
    
    private func sendOffline(messageId: String, text: String) {
        Task {
            do {
                // Save locally with queued status
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .queued
                )
                try await MainActor.run {
                    try localStorage.saveMessage(message)
                }
                
                // Add to queue
                try queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text
                )
                
                print("📥 Message queued (offline)")
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Failed to queue message"
                print("❌ Failed to queue: \(error)")
            }
        }
    }
    
    func retryMessage(messageId: String) {
        guard let message = messages.first(where: { $0.id == messageId }) else { return }
        
        // Update status to pending
        updateMessageStatus(messageId: messageId, status: .pending)
        
        Task {
            do {
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: message.text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                updateMessageStatus(messageId: messageId, status: .sent)
                print("✅ Message retry successful")
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Retry failed"
                print("❌ Retry failed: \(error)")
            }
        }
    }
    
    func deleteMessage(messageId: String) {
        messages.removeAll { $0.id == messageId }
        
        Task {
            do {
                try await MainActor.run {
                    // Try to delete from local storage
                    if let message = try? localStorage.fetchMessages(for: conversationId).first(where: { $0.id == messageId }) {
                        try localStorage.deleteMessage(messageId: messageId)
                    }
                }
            } catch {
                print("⚠️ Error deleting message: \(error)")
            }
        }
    }
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
            
            Task {
                try? await MainActor.run {
                    try? localStorage.updateMessageStatus(messageId: messageId, status: status)
                }
            }
        }
    }
    
    func loadLocalMessages() {
        do {
            let fetchedMessages = try localStorage.fetchMessages(for: conversationId)
            messages = fetchedMessages.map { $0 } // Force new array to trigger SwiftUI update
            print("📨 Loaded \(messages.count) messages from local storage")
            
            // If local has messages but we suspect they're stale, the Firestore listener will sync them
            // For fresh installs, ConversationListViewModel already fetches messages
            
        } catch {
            print("⚠️ Error loading local messages: \(error)")
        }
    }
    
    private func observeRecipientStatus() {
        UserService.shared.observeUserStatus(userId: recipientId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.recipientOnline = user?.online ?? false
                self?.recipientLastSeen = user?.lastSeen
            }
            .store(in: &cancellables)
    }
    
    private func startListening() {
        print("🎧 [ChatViewModel] Setting up listener for conversation: \(conversationId)")
        
        listenerService.listenToMessages(conversationId: conversationId) { [weak self] snapshot in
            guard let self = self else { 
                print("⚠️ [ChatViewModel] Self is nil in listener callback")
                return 
            }
            
            print("📬 [ChatViewModel] Received message in callback: \(snapshot.text)")
            print("   From: \(snapshot.senderId)")
            print("   Current user: \(self.currentUserId)")
            
            Task {
                do {
                    print("💾 [ChatViewModel] Syncing message to local storage...")
                    try await self.messageService.syncMessageFromFirestore(snapshot)
                    
                    await MainActor.run {
                        print("🔄 [ChatViewModel] Triggering UI update...")
                        self.objectWillChange.send() // Explicitly trigger update
                        self.loadLocalMessages()
                        
                        // Trigger notification if message is from someone else
                        if snapshot.senderId != self.currentUserId {
                            print("🔔 [ChatViewModel] Message is from someone else, triggering notification...")
                            self.showNotificationForMessage(snapshot)
                        } else {
                            print("ℹ️ [ChatViewModel] Message is from current user, skipping notification")
                        }
                    }
                } catch {
                    print("❌ [ChatViewModel] Error syncing message: \(error)")
                }
            }
        }
    }
    
    private func showNotificationForMessage(_ snapshot: MessageSnapshot) {
        // Get sender name
        let senderName: String
        if isGroup {
            senderName = participants.first { $0.id == snapshot.senderId }?.displayName ?? "Unknown"
        } else {
            senderName = participants.first?.displayName ?? recipientId
        }
        
        // Show system notification (will be suppressed if user is viewing this conversation)
        notificationService.showMessageNotification(
            conversationId: conversationId,
            senderName: senderName,
            messageText: snapshot.text,
            isGroup: isGroup
        )
        
        // ✨ NEW: Show in-app notification (always, even if in conversation)
        Task { @MainActor in
            let inAppNotification = InAppNotification(
                conversationId: conversationId,
                senderName: senderName,
                messageText: snapshot.text,
                isGroup: isGroup
            )
            InAppNotificationManager.shared.show(inAppNotification)
            print("🔔 [ChatViewModel] In-app notification triggered for: \(senderName)")
        }
        
        // ✨ NEW: Increment unread count ONLY if user not viewing this conversation
        let isViewingThisConversation = notificationService.currentConversationId == conversationId
        print("📊 [ChatViewModel] Unread count check:")
        print("   Current conversation: \(notificationService.currentConversationId ?? "nil")")
        print("   Message conversation: \(conversationId)")
        print("   Is viewing: \(isViewingThisConversation)")
        
        if !isViewingThisConversation {
            print("📊 [ChatViewModel] User NOT viewing this conversation - incrementing unread count")
            Task {
                do {
                    try await localStorage.incrementUnreadCount(conversationId: conversationId)
                    print("✅ [ChatViewModel] Unread count incremented for: \(conversationId)")
                } catch {
                    print("❌ [ChatViewModel] Failed to increment unread count: \(error)")
                }
            }
        } else {
            print("ℹ️ [ChatViewModel] User IS viewing conversation - skipping unread count increment")
        }
    }
    
    private func observeNetwork() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                print(isConnected ? "🌐 Network connected" : "📵 Network disconnected")
                
                // Process queue when coming back online
                if isConnected {
                    Task {
                        await self.queueService.processQueue()
                        self.loadLocalMessages()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func markMessagesAsRead() {
        Task {
            do {
                try await readReceiptService.markMessagesAsRead(
                    conversationId: conversationId,
                    userId: currentUserId
                )
                loadLocalMessages()
            } catch {
                print("⚠️ Failed to mark messages as read: \(error)")
            }
        }
    }
    
}

