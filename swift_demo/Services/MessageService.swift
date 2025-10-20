//
//  MessageService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class MessageService {
    static let shared = MessageService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    private let retryService = FirestoreRetryService.shared

    private init() {}

    func sendToFirestore(
        messageId: String,
        text: String,
        conversationId: String,
        senderId: String,
        recipientId: String
    ) async throws {
        print("☁️ Sending to Firestore: \(messageId)")

        // Wrap in retry logic for resilience
        try await retryService.executeWithRetry(policy: .default) {
            let messageData: [String: Any] = [
                "id": messageId,
                "conversationId": conversationId,
                "senderId": senderId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "delivered",
                "readBy": [senderId]
            ]

            try await self.db.collection("messages").document(messageId).setData(messageData)
            print("✅ Sent to Firestore successfully")

            // Update conversation
            // For groups, recipientId will be empty, so get participants from conversation
            var participants = [senderId]
            if !recipientId.isEmpty {
                participants.append(recipientId)
            } else {
                // Group chat - get all participants from local storage
                if let conversation = try? await MainActor.run(body: {
                    try self.localStorage.fetchConversation(byId: conversationId)
                }) {
                    participants = conversation.participantIds
                }
            }
            
            try await ConversationService.shared.updateConversation(
                conversationId: conversationId,
                lastMessage: text,
                participants: participants
            )
        }
    }
    
    func syncMessageFromFirestore(_ snapshot: MessageSnapshot) async throws {
        try await MainActor.run {
            do {
                // Check if message exists locally
                let exists = try localStorage.messageExists(messageId: snapshot.id)
                
                if exists {
                    // Update existing message
                    print("🔄 Updating existing message: \(snapshot.id)")
                    try localStorage.updateMessage(
                        messageId: snapshot.id,
                        status: MessageStatus(rawValue: snapshot.status) ?? .delivered,
                        readBy: snapshot.readBy
                    )
                } else {
                    // Insert new message
                    print("➕ Inserting new message: \(snapshot.id)")
                    let message = MessageEntity(
                        id: snapshot.id,
                        conversationId: snapshot.conversationId,
                        senderId: snapshot.senderId,
                        text: snapshot.text,
                        timestamp: snapshot.timestamp,
                        status: MessageStatus(rawValue: snapshot.status) ?? .delivered,
                        readBy: snapshot.readBy
                    )
                    try localStorage.saveMessage(message)
                }
            } catch {
                print("❌ Error syncing message: \(error)")
                throw error
            }
        }
    }
}

