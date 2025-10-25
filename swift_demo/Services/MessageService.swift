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
        recipientId: String,
        retryPolicy: RetryPolicy = .default
    ) async throws {
        print("☁️ Sending to Firestore: \(messageId)")

        // Wrap in retry logic for resilience
        try await retryService.executeWithRetry(policy: retryPolicy) {
            let messageData: [String: Any] = [
                "id": messageId,
                "conversationId": conversationId,
                "senderId": senderId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "delivered",
                "readBy": [], // Empty - recipients will add themselves when they read it
                "deliveredTo": [], // Empty - will be populated when delivered
                "deliveredAt": NSNull(), // Null until first delivery
                "readAt": NSNull() // Null until first read
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
    
    /// Send image message to Firestore
    /// PR-7: New method for image-only messages
    /// In Vue: const sendImageMessage = async (messageData) => { ... }
    func sendImageMessage(
        messageId: String,
        imageUrl: String,
        conversationId: String,
        senderId: String,
        recipientId: String,
        imageWidth: Double,
        imageHeight: Double
    ) async throws {
        print("☁️ [MessageService] Sending image message to Firestore: \(messageId)")
        print("   Image URL: \(imageUrl)")
        print("   Dimensions: \(Int(imageWidth))x\(Int(imageHeight))")
        
        try await retryService.executeWithRetry(policy: .default) {
            let messageData: [String: Any] = [
                "id": messageId,
                "conversationId": conversationId,
                "senderId": senderId,
                "text": NSNull(), // Explicitly null for image-only messages
                "timestamp": FieldValue.serverTimestamp(),
                "status": "delivered",
                "readBy": [],
                "deliveredTo": [], // Empty - will be populated when delivered
                "deliveredAt": NSNull(), // Null until first delivery
                "readAt": NSNull(), // Null until first read
                "imageUrl": imageUrl,
                "imageWidth": imageWidth,
                "imageHeight": imageHeight
            ]
            
            try await self.db.collection("messages").document(messageId).setData(messageData)
            print("✅ [MessageService] Image message sent to Firestore")
            
            // Update conversation
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
                lastMessage: "Image", // Show "Image" in conversation list
                participants: participants
            )
            
            print("✅ [MessageService] Conversation updated with image message")
        }
    }
    
    func syncMessageFromFirestore(_ snapshot: MessageSnapshot) async throws {
        print("💾 [MessageService] Starting sync for message: \(snapshot.id)")
        print("   Text: \(snapshot.text ?? "nil")")
        print("   Image URL: \(snapshot.imageUrl ?? "nil")")
        print("   Conversation: \(snapshot.conversationId)")
        print("   SenderId from Firestore: '\(snapshot.senderId)'")
        
        try await MainActor.run {
            do {
                // Check if message exists locally
                let exists = try localStorage.messageExists(messageId: snapshot.id)
                print("   Exists locally: \(exists)")
                
                if exists {
                    // Update existing message
                    print("🔄 [MessageService] Updating existing message: \(snapshot.id)")
                    try localStorage.updateMessage(
                        messageId: snapshot.id,
                        status: MessageStatus(rawValue: snapshot.status) ?? .delivered,
                        readBy: snapshot.readBy,
                        deliveredTo: snapshot.deliveredTo,
                        deliveredAt: snapshot.deliveredAt,
                        readAt: snapshot.readAt
                    )
                } else {
                    // Insert new message
                    print("➕ [MessageService] Inserting new message: \(snapshot.id)")
                    let message = MessageEntity(
                        id: snapshot.id,
                        conversationId: snapshot.conversationId,
                        senderId: snapshot.senderId,
                        text: snapshot.text,
                        timestamp: snapshot.timestamp,
                        status: MessageStatus(rawValue: snapshot.status) ?? .delivered,
                        readBy: snapshot.readBy,
                        deliveredTo: snapshot.deliveredTo,
                        deliveredAt: snapshot.deliveredAt,
                        readAt: snapshot.readAt,
                        imageUrl: snapshot.imageUrl,
                        imageWidth: snapshot.imageWidth,
                        imageHeight: snapshot.imageHeight
                    )
                    try localStorage.saveMessage(message)
                    print("✅ [MessageService] Message saved successfully")
                }
            } catch {
                print("❌ [MessageService] Error syncing message: \(error)")
                throw error
            }
        }
    }
}

