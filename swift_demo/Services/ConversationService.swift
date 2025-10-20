//
//  ConversationService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class ConversationService {
    static let shared = ConversationService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    private init() {}
    
    func updateConversation(
        conversationId: String,
        lastMessage: String,
        participants: [String]
    ) async throws {
        let conversationRef = db.collection("conversations").document(conversationId)
        
        let conversationData: [String: Any] = [
            "id": conversationId,
            "participants": participants,
            "isGroup": false,
            "lastMessageText": lastMessage,
            "lastMessageTime": FieldValue.serverTimestamp()
        ]
        
        // Use merge to create or update
        try await conversationRef.setData(conversationData, merge: true)
        print("💬 Conversation updated in Firestore: \(conversationId)")
        
        // Update local storage
        try await MainActor.run {
            // Check if conversation exists
            if let existingConversation = try? localStorage.fetchConversation(byId: conversationId) {
                try localStorage.updateConversation(
                    conversationId: conversationId,
                    lastMessage: lastMessage,
                    timestamp: Date()
                )
            } else {
                // Create new conversation
                let conversation = ConversationEntity(
                    id: conversationId,
                    participantIds: participants,
                    isGroup: false
                )
                conversation.lastMessageText = lastMessage
                conversation.lastMessageTime = Date()
                try localStorage.saveConversation(conversation)
            }
        }
    }
    
    func getOrCreateConversation(
        userId1: String,
        userId2: String
    ) async throws -> String {
        let conversationId = generateConversationId(userId1: userId1, userId2: userId2)
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let snapshot = try await conversationRef.getDocument()
        
        if !snapshot.exists {
            // Create new conversation
            let conversationData: [String: Any] = [
                "id": conversationId,
                "participants": [userId1, userId2],
                "isGroup": false
            ]
            try await conversationRef.setData(conversationData)
            print("🆕 Created new conversation: \(conversationId)")
        }
        
        return conversationId
    }
    
    func generateConversationId(userId1: String, userId2: String) -> String {
        let sorted = [userId1, userId2].sorted()
        return sorted.joined(separator: "_")
    }
}

