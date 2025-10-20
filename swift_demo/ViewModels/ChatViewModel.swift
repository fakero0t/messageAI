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
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    private let listenerService = FirestoreListenerService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(recipientId: String) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = ConversationService.shared.generateConversationId(
            userId1: currentUserId,
            userId2: recipientId
        )
        
        observeRecipientStatus()
        loadLocalMessages()
        startListening()
    }
    
    deinit {
        listenerService.stopListening(conversationId: conversationId)
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty else { return }
        
        let messageId = UUID().uuidString
        
        // 1. Optimistic insert - show immediately with pending status
        let optimisticMessage = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        
        messages.append(optimisticMessage)
        
        // 2. Send in background
        Task {
            do {
                // Save to local storage first
                try await MainActor.run {
                    try localStorage.saveMessage(optimisticMessage)
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
                
                // Status will update to .delivered via Firestore listener
                print("✅ Message sent successfully")
                
            } catch {
                // Mark as failed
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Failed to send message"
                print("❌ Error sending message: \(error)")
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
            messages = try localStorage.fetchMessages(for: conversationId)
            print("📨 Loaded \(messages.count) messages from local storage")
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
        listenerService.listenToMessages(conversationId: conversationId) { [weak self] snapshot in
            guard let self = self else { return }
            
            Task {
                do {
                    try await self.messageService.syncMessageFromFirestore(snapshot)
                    await MainActor.run {
                        self.loadLocalMessages()
                    }
                } catch {
                    print("❌ Error syncing message: \(error)")
                }
            }
        }
    }
    
}

