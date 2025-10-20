//
//  ConversationService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

struct ConversationSnapshot {
    let id: String
    let participantIds: [String]
    let isGroup: Bool
    let lastMessageText: String?
    let lastMessageTime: Date?
}

class ConversationService {
    static let shared = ConversationService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    private var conversationListeners: [String: ListenerRegistration] = [:]
    
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
    
    // MARK: - Firestore Listeners
    
    func listenToUserConversations(
        userId: String,
        onUpdate: @escaping (ConversationSnapshot) -> Void
    ) {
        print("🎧 Starting conversation listener for user: \(userId)")
        
        let listener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to conversations: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                print("📬 Received \(snapshot.documentChanges.count) conversation changes")
                
                snapshot.documentChanges.forEach { change in
                    if change.type == .added || change.type == .modified {
                        do {
                            let data = change.document.data()
                            let conversationSnapshot = try self.parseConversation(from: data)
                            print("💬 Conversation \(change.type == .added ? "added" : "modified"): \(conversationSnapshot.id)")
                            onUpdate(conversationSnapshot)
                        } catch {
                            print("❌ Error parsing conversation: \(error)")
                        }
                    }
                }
            }
        
        conversationListeners[userId] = listener
    }
    
    func stopListeningToConversations(userId: String) {
        print("🛑 Stopping conversation listener for user: \(userId)")
        conversationListeners[userId]?.remove()
        conversationListeners.removeValue(forKey: userId)
    }
    
    func syncConversationFromFirestore(_ snapshot: ConversationSnapshot) async throws {
        try await MainActor.run {
            do {
                // Check if conversation exists locally
                if let existingConversation = try? localStorage.fetchConversation(byId: snapshot.id) {
                    // Update existing
                    print("🔄 Updating existing conversation: \(snapshot.id)")
                    existingConversation.lastMessageText = snapshot.lastMessageText
                    existingConversation.lastMessageTime = snapshot.lastMessageTime
                    // SwiftData auto-saves changes to tracked objects
                } else {
                    // Create new
                    print("➕ Creating new conversation: \(snapshot.id)")
                    let conversation = ConversationEntity(
                        id: snapshot.id,
                        participantIds: snapshot.participantIds,
                        isGroup: snapshot.isGroup
                    )
                    conversation.lastMessageText = snapshot.lastMessageText
                    conversation.lastMessageTime = snapshot.lastMessageTime
                    try localStorage.saveConversation(conversation)
                }
            } catch {
                print("❌ Error syncing conversation: \(error)")
                throw error
            }
        }
    }
    
    private func parseConversation(from data: [String: Any]) throws -> ConversationSnapshot {
        return ConversationSnapshot(
            id: data["id"] as? String ?? "",
            participantIds: data["participants"] as? [String] ?? [],
            isGroup: data["isGroup"] as? Bool ?? false,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageTime: (data["lastMessageTime"] as? Timestamp)?.dateValue()
        )
    }
}

