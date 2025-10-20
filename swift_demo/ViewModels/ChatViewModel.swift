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
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty, !isSending else { return }
        
        isSending = true
        errorMessage = nil
        
        // Optimistically add message to UI
        let tempMessage = MessageEntity(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        messages.append(tempMessage)
        
        Task {
            do {
                _ = try await messageService.sendMessage(
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                // Reload messages from local storage to get updated status
                loadLocalMessages()
                
            } catch {
                errorMessage = "Failed to send: \(error.localizedDescription)"
                print("❌ Error sending message: \(error)")
                
                // Remove the optimistic message on failure
                if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                    messages.remove(at: index)
                }
            }
            
            isSending = false
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
    
}

