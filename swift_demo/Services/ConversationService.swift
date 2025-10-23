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
            // Create new conversation in Firestore
            let conversationData: [String: Any] = [
                "id": conversationId,
                "participants": [userId1, userId2],
                "isGroup": false,
                "lastMessageTime": FieldValue.serverTimestamp()
            ]
            try await conversationRef.setData(conversationData)
            print("🆕 Created new conversation in Firestore: \(conversationId)")
            print("   Participants: \(userId1), \(userId2)")
            print("   Type: 1-on-1")
            
            // Immediately save to local storage so it appears in the list
            try await MainActor.run {
                do {
                    let conversation = ConversationEntity(
                        id: conversationId,
                        participantIds: [userId1, userId2],
                        isGroup: false
                    )
                    conversation.lastMessageTime = Date()
                    try localStorage.saveConversation(conversation)
                    print("✅ Saved new conversation to local storage: \(conversationId)")
                } catch {
                    print("⚠️ Error saving conversation to local storage: \(error)")
                    // Don't throw - conversation exists in Firestore and will sync eventually
                }
            }
        } else {
            print("✅ Conversation already exists: \(conversationId)")
            
            // Make sure it's in local storage
            try await MainActor.run {
                if (try? localStorage.fetchConversation(byId: conversationId)) == nil {
                    // Not in local storage, create it
                    print("📥 Conversation exists in Firestore but not local - syncing...")
                    let conversation = ConversationEntity(
                        id: conversationId,
                        participantIds: [userId1, userId2],
                        isGroup: false
                    )
                    conversation.lastMessageTime = Date()
                    try? localStorage.saveConversation(conversation)
                }
            }
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
        guard !userId.isEmpty else {
            print("⚠️ listenToUserConversations called with empty userId; skipping listener")
            return
        }
        
        print("🎧🎧🎧 [ConversationService] Starting conversation listener for user: \(userId)")
        print("🎧🎧🎧 [ConversationService] Query: conversations where participants array-contains '\(userId)' order by lastMessageTime desc")
        
        let listener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                print("🔔🔔🔔 [ConversationService] LISTENER CALLBACK FIRED!")
                if let error = error {
                    print("❌❌❌ Error listening to conversations: \(error)")
                    print("❌❌❌ Error localized: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("❌❌❌ Error domain: \(nsError.domain)")
                        print("❌❌❌ Error code: \(nsError.code)")
                        print("❌❌❌ Error userInfo: \(nsError.userInfo)")
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️⚠️⚠️ Snapshot is nil!")
                    return
                }
                
                print("📊 Snapshot metadata:")
                print("   - isFromCache: \(snapshot.metadata.isFromCache)")
                print("   - hasPendingWrites: \(snapshot.metadata.hasPendingWrites)")
                print("   - Total documents: \(snapshot.documents.count)")
                print("   - Document changes: \(snapshot.documentChanges.count)")
                
                // Skip metadata-only updates to avoid duplicate processing
                if snapshot.metadata.hasPendingWrites {
                    print("📝 Skipping snapshot with pending writes")
                    return
                }
                
                print("📬 Processing \(snapshot.documentChanges.count) conversation changes")
                
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
        print("✅✅✅ [ConversationService] Listener registered for user: \(userId)")
        print("✅✅✅ [ConversationService] Total active listeners: \(conversationListeners.count)")
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
        // Handle lastMessageTime being null or pending from server timestamp
        let lastMessageTime: Date?
        if let timestamp = data["lastMessageTime"] as? Timestamp {
            lastMessageTime = timestamp.dateValue()
        } else {
            // Timestamp might be pending - use current time as placeholder
            lastMessageTime = Date()
            print("⚠️ Conversation \(data["id"] as? String ?? "unknown") has pending timestamp")
        }
        
        return ConversationSnapshot(
            id: data["id"] as? String ?? "",
            participantIds: data["participants"] as? [String] ?? [],
            isGroup: data["isGroup"] as? Bool ?? false,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageTime: lastMessageTime
        )
    }
}

