//
//  ReadReceiptService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

enum ReadReceiptStatus {
    case notDelivered
    case delivered
    case readBySome
    case readByAll
}

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
        print("📖 [ReadReceiptService] markMessagesAsRead called")
        print("   Conversation: \(conversationId)")
        print("   User: \(userId)")
        
        // Get messages in conversation
        let messages = try await MainActor.run {
            try localStorage.fetchMessages(for: conversationId)
        }
        
        print("   Total messages in conversation: \(messages.count)")
        
        // Filter to only unread messages (not sent by current user, not already read by them)
        let unreadMessages = messages.filter { message in
            let isFromOtherUser = message.senderId != userId
            let notAlreadyRead = !message.readBy.contains(userId)
            let isUnread = isFromOtherUser && notAlreadyRead
            
            if isFromOtherUser {
                print("   Message \(message.id.prefix(8)): from other user, readBy=\(message.readBy), isUnread=\(isUnread)")
            }
            
            return isUnread
        }
        
        print("   Unread messages to mark: \(unreadMessages.count)")
        
        guard !unreadMessages.isEmpty else {
            print("ℹ️ [ReadReceiptService] No unread messages to mark")
            return
        }
        
        print("📖 [ReadReceiptService] Marking \(unreadMessages.count) message(s) as read")
        
        // Batch update Firestore
        let batch = db.batch()
        let now = Date()
        
        for message in unreadMessages {
            let messageRef = db.collection("messages").document(message.id)
            var updates: [String: Any] = [
                "readBy": FieldValue.arrayUnion([userId])
            ]
            
            // Set readAt timestamp if this is the first read
            if message.readBy.isEmpty {
                updates["readAt"] = Timestamp(date: now)
            }
            
            batch.updateData(updates, forDocument: messageRef)
        }
        
        try await batch.commit()
        print("✅ Read receipts updated in Firestore")
        
        // Update local storage
        await MainActor.run {
            for message in unreadMessages {
                // Add user to readBy array
                message.readBy.append(userId)
                
                // Set readAt if first read
                if message.readAt == nil {
                    message.readAt = now
                }
                
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
    
    /// Mark a message as delivered to a user
    func markAsDelivered(messageId: String, userId: String) async throws {
        print("📦 [ReadReceiptService] markAsDelivered")
        print("   Message: \(messageId.prefix(8))")
        print("   User: \(userId)")
        
        // Get message from local storage
        guard let message = try? await MainActor.run(body: {
            try localStorage.fetchMessage(byId: messageId)
        }) else {
            print("⚠️ Message not found in local storage")
            return
        }
        
        // Check if already delivered
        if message.deliveredTo.contains(userId) {
            print("ℹ️ Already delivered to this user")
            return
        }
        
        let now = Date()
        let isFirstDelivery = message.deliveredTo.isEmpty
        
        // Update Firestore
        var updates: [String: Any] = [
            "deliveredTo": FieldValue.arrayUnion([userId])
        ]
        
        if isFirstDelivery {
            updates["deliveredAt"] = Timestamp(date: now)
        }
        
        let messageRef = db.collection("messages").document(messageId)
        try await messageRef.updateData(updates)
        print("✅ Delivery receipt updated in Firestore")
        
        // Update local storage
        await MainActor.run {
            message.deliveredTo.append(userId)
            if isFirstDelivery {
                message.deliveredAt = now
            }
            
            // Update status to delivered if appropriate
            if message.status == .sent || message.status == .queued {
                try? localStorage.updateMessageStatus(messageId: messageId, status: .delivered)
            }
        }
    }
    
    /// Mark all undelivered messages in a conversation as delivered
    func markMessagesAsDelivered(conversationId: String, userId: String) async throws {
        print("📦 [ReadReceiptService] markMessagesAsDelivered")
        
        let messages = try await MainActor.run {
            try localStorage.fetchMessages(for: conversationId)
        }
        
        let undeliveredMessages = messages.filter { message in
            !message.deliveredTo.contains(userId) && message.senderId != userId
        }
        
        guard !undeliveredMessages.isEmpty else {
            print("ℹ️ No undelivered messages")
            return
        }
        
        print("📦 Marking \(undeliveredMessages.count) message(s) as delivered")
        
        // Batch update
        let batch = db.batch()
        let now = Date()
        
        for message in undeliveredMessages {
            let messageRef = db.collection("messages").document(message.id)
            var updates: [String: Any] = [
                "deliveredTo": FieldValue.arrayUnion([userId])
            ]
            
            if message.deliveredTo.isEmpty {
                updates["deliveredAt"] = Timestamp(date: now)
            }
            
            batch.updateData(updates, forDocument: messageRef)
        }
        
        try await batch.commit()
        
        // Update local
        await MainActor.run {
            for message in undeliveredMessages {
                message.deliveredTo.append(userId)
                if message.deliveredAt == nil {
                    message.deliveredAt = now
                }
            }
        }
    }
    
    /// Compute read receipt status for a message
    func computeReadReceiptStatus(
        message: MessageEntity,
        participants: [String]
    ) -> ReadReceiptStatus {
        let recipientIds = participants.filter { $0 != message.senderId }
        
        if recipientIds.isEmpty {
            return .notDelivered
        }
        
        // Check delivery
        let deliveredCount = recipientIds.filter { message.deliveredTo.contains($0) }.count
        if deliveredCount == 0 {
            return .notDelivered
        }
        
        // Check reads
        let readCount = recipientIds.filter { message.readBy.contains($0) }.count
        
        if readCount == 0 {
            return .delivered
        } else if readCount == recipientIds.count {
            return .readByAll
        } else {
            return .readBySome
        }
    }
    
    /// Generate read receipt display text
    func readReceiptText(
        message: MessageEntity,
        participants: [String],
        currentUserId: String
    ) -> String? {
        // Only show for messages from current user
        guard message.senderId == currentUserId else {
            return nil
        }
        
        let status = computeReadReceiptStatus(message: message, participants: participants)
        let isGroupChat = participants.count > 2
        
        switch status {
        case .notDelivered:
            return nil
            
        case .delivered:
            return "Delivered"
            
        case .readBySome:
            return isGroupChat ? "Read by some users" : readAtText(message)
            
        case .readByAll:
            return isGroupChat ? "Read by all users" : readAtText(message)
        }
    }
    
    private func readAtText(_ message: MessageEntity) -> String {
        if let readAt = message.readAt {
            return "Read at \(readAt.absoluteTime())"
        }
        return "Read"
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

