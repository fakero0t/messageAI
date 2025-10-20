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
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private var cancellables = Set<AnyCancellable>()
    
    init(recipientId: String) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = Self.generateConversationId(userId1: currentUserId, userId2: recipientId)
        
        observeRecipientStatus()
        loadMockMessages() // Temporary for testing
    }
    
    func sendMessage(text: String) {
        // Placeholder - will implement real sending in PR-7
        let message = MessageEntity(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        messages.append(message)
        
        // Simulate status change after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if let index = self?.messages.firstIndex(where: { $0.id == message.id }) {
                self?.messages[index].status = .sent
            }
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
    
    private func loadMockMessages() {
        // Create some mock messages for UI testing
        let mockMessages = [
            MessageEntity(
                id: "1",
                conversationId: conversationId,
                senderId: recipientId,
                text: "Hey! How are you?",
                timestamp: Date().addingTimeInterval(-3600),
                status: .read
            ),
            MessageEntity(
                id: "2",
                conversationId: conversationId,
                senderId: currentUserId,
                text: "I'm doing great! Thanks for asking.",
                timestamp: Date().addingTimeInterval(-3500),
                status: .read
            ),
            MessageEntity(
                id: "3",
                conversationId: conversationId,
                senderId: recipientId,
                text: "That's awesome! What are you working on?",
                timestamp: Date().addingTimeInterval(-3400),
                status: .read
            ),
            MessageEntity(
                id: "4",
                conversationId: conversationId,
                senderId: currentUserId,
                text: "Building a messaging app with SwiftUI and Firebase!",
                timestamp: Date().addingTimeInterval(-3300),
                status: .delivered
            )
        ]
        
        messages = mockMessages
    }
    
    static func generateConversationId(userId1: String, userId2: String) -> String {
        let sorted = [userId1, userId2].sorted()
        return sorted.joined(separator: "_")
    }
}

