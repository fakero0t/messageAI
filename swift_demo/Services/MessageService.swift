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
    
    private init() {}
    
    func sendMessage(
        text: String,
        conversationId: String,
        senderId: String,
        recipientId: String
    ) async throws -> String {
        let messageId = UUID().uuidString
        
        print("📤 Sending message: \(text)")
        
        // 1. Create message entity for local storage
        let message = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        
        // 2. Save to local SwiftData first
        try await MainActor.run {
            try localStorage.saveMessage(message)
            print("💾 Saved to local storage")
        }
        
        // 3. Update status to sent
        try await MainActor.run {
            try localStorage.updateMessageStatus(messageId: messageId, status: .sent)
            print("✅ Status updated to sent")
        }
        
        // 4. Send to Firestore
        let messageData: [String: Any] = [
            "id": messageId,
            "conversationId": conversationId,
            "senderId": senderId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "delivered",
            "readBy": [senderId]
        ]
        
        try await db.collection("messages").document(messageId).setData(messageData)
        print("☁️ Sent to Firestore")
        
        // 5. Update local status to delivered
        try await MainActor.run {
            try localStorage.updateMessageStatus(messageId: messageId, status: .delivered)
            print("📬 Status updated to delivered")
        }
        
        // 6. Update conversation
        try await ConversationService.shared.updateConversation(
            conversationId: conversationId,
            lastMessage: text,
            participants: [senderId, recipientId]
        )
        
        print("✅ Message sent successfully: \(messageId)")
        return messageId
    }
}

