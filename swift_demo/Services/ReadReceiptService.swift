//
//  ReadReceiptService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class ReadReceiptService {
    static let shared = ReadReceiptService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    private init() {}
    
    /// Mark all unread messages in a conversation as read
    func markMessagesAsRead(
        conversationId: String,
        userId: String
    ) async throws {
        // Get messages in conversation
        let messages = try await MainActor.run {
            try localStorage.fetchMessages(for: conversationId)
        }
        
        // Filter to only unread messages (not sent by current user, not already read by them)
        let unreadMessages = messages.filter { message in
            message.senderId != userId && !message.readBy.contains(userId)
        }
        
        guard !unreadMessages.isEmpty else {
            print("ℹ️ No unread messages to mark")
            return
        }
        
        print("📖 Marking \(unreadMessages.count) message(s) as read")
        
        // Batch update Firestore
        let batch = db.batch()
        
        for message in unreadMessages {
            let messageRef = db.collection("messages").document(message.id)
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId])
            ], forDocument: messageRef)
        }
        
        try await batch.commit()
        print("✅ Read receipts updated in Firestore")
        
        // Update local storage
        await MainActor.run {
            for message in unreadMessages {
                // Add user to readBy array
                message.readBy.append(userId)
                
                // Update status to read if appropriate
                if shouldMarkAsRead(message: message, conversationId: conversationId) {
                    try? localStorage.updateMessageStatus(messageId: message.id, status: .read)
                }
            }
            
            // Reset unread count for conversation
            try? localStorage.resetUnreadCount(conversationId: conversationId)
            
            print("✅ Local storage updated with read receipts")
        }
    }
    
    /// Determine if a message should be marked as "read" status
    private func shouldMarkAsRead(message: MessageEntity, conversationId: String) -> Bool {
        // Extract participants from conversation ID
        let participants = conversationId.split(separator: "_").map(String.init)
        
        if participants.count == 2 {
            // One-on-one chat: mark as read ONLY if recipient (not sender) has read it
            // Check if someone OTHER than the sender is in readBy
            let hasRecipientRead = message.readBy.contains { readerId in
                readerId != message.senderId
            }
            return hasRecipientRead
        } else {
            // Group chat: mark as read if at least one other person (not sender) read
            let nonSenderReads = message.readBy.filter { $0 != message.senderId }
            return nonSenderReads.count > 0
        }
    }
}

