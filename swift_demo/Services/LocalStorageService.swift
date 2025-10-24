//
//  LocalStorageService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import SwiftData

@MainActor
class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let modelContext: ModelContext
    
    private init() {
        self.modelContext = PersistenceController.shared.container.mainContext
    }
    
    // MARK: - Context Operations
    
    func saveContext() throws {
        try modelContext.save()
    }
    
    // MARK: - Message Operations
    
    func saveMessage(_ message: MessageEntity) throws {
        print("💾 [LocalStorage] Saving message:")
        print("   ID: \(message.id.prefix(8))")
        print("   SenderId: '\(message.senderId)'")
        print("   Text: \(message.text?.prefix(30) ?? "nil")")
        print("   ImageUrl: \(message.imageUrl != nil ? "has image" : "no image")")
        
        modelContext.insert(message)
        try modelContext.save()
        
        print("✅ [LocalStorage] Message saved successfully")
    }
    
    func fetchMessages(for conversationId: String) throws -> [MessageEntity] {
        let predicate = #Predicate<MessageEntity> { $0.conversationId == conversationId }
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let messages = try modelContext.fetch(descriptor)
        
        print("📥 [LocalStorage] Fetched \(messages.count) messages for conversation \(conversationId.prefix(8))")
        for msg in messages {
            let preview = msg.text?.prefix(20) ?? (msg.imageUrl != nil ? "Image" : "Empty")
            print("   \(msg.id.prefix(8)): senderId='\(msg.senderId)' | \(preview)")
        }
        
        return messages
    }
    
    func fetchMessage(byId messageId: String) throws -> MessageEntity? {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    func updateMessageStatus(messageId: String, status: MessageStatus) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.status = status
            try modelContext.save()
        }
    }
    
    func markMessageAsRead(messageId: String, userId: String) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            if !message.readBy.contains(userId) {
                message.readBy.append(userId)
                try modelContext.save()
            }
        }
    }
    
    func updateMessage(
        messageId: String,
        status: MessageStatus,
        readBy: [String],
        deliveredTo: [String]? = nil,
        deliveredAt: Date? = nil,
        readAt: Date? = nil
    ) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.status = status
            message.readBy = readBy
            if let deliveredTo = deliveredTo {
                message.deliveredTo = deliveredTo
            }
            if let deliveredAt = deliveredAt {
                message.deliveredAt = deliveredAt
            }
            if let readAt = readAt {
                message.readAt = readAt
            }
            try modelContext.save()
        }
    }
    
    // PR-9: Update image message with Firebase Storage URL
    func updateImageMessage(messageId: String, imageUrl: String, status: MessageStatus) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.imageUrl = imageUrl
            message.status = status
            try modelContext.save()
            print("✅ [LocalStorage] Updated image message with URL")
        }
    }
    
    func messageExists(messageId: String) throws -> Bool {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first != nil
    }
    
    func deleteMessage(messageId: String) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            modelContext.delete(message)
            try modelContext.save()
        }
    }
    
    // Update message with translation data
    func updateMessageTranslation(
        messageId: String,
        translatedEn: String,
        translatedKa: String,
        originalLang: String
    ) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.translatedEn = translatedEn
            message.translatedKa = translatedKa
            message.originalLang = originalLang
            message.translatedAt = Date()
            try modelContext.save()
            print("💾 [LocalStorage] Updated message translation for: \(messageId.prefix(8))")
        } else {
            print("⚠️ [LocalStorage] Message not found for translation update: \(messageId.prefix(8))")
        }
    }
    
    // MARK: - Conversation Operations
    
    func saveConversation(_ conversation: ConversationEntity) throws {
        modelContext.insert(conversation)
        try modelContext.save()
    }
    
    func fetchConversation(byId conversationId: String) throws -> ConversationEntity? {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    func fetchAllConversations() throws -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            sortBy: [SortDescriptor(\.lastMessageTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchConversationsForUser(userId: String) throws -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            sortBy: [SortDescriptor(\.lastMessageTime, order: .reverse)]
        )
        let allConversations = try modelContext.fetch(descriptor)
        
        // Filter to only include conversations where the user is a participant
        return allConversations.filter { conversation in
            conversation.participantIds.contains(userId)
        }
    }
    
    func deleteConversation(byId conversationId: String) throws {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            modelContext.delete(conversation)
            try modelContext.save()
            print("🗑️ Deleted conversation: \(conversationId)")
        }
    }
    
    func updateConversation(conversationId: String, lastMessage: String, timestamp: Date) throws {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            conversation.lastMessageText = lastMessage
            conversation.lastMessageTime = timestamp
            try modelContext.save()
        }
    }
    
    // MARK: - Queued Message Operations
    
    func queueMessage(_ message: QueuedMessageEntity) throws {
        modelContext.insert(message)
        try modelContext.save()
    }
    
    func getQueuedMessages() throws -> [QueuedMessageEntity] {
        let descriptor = FetchDescriptor<QueuedMessageEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func removeQueuedMessage(_ messageId: String) throws {
        let predicate = #Predicate<QueuedMessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<QueuedMessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            modelContext.delete(message)
            try modelContext.save()
        }
    }
    
    func incrementRetryCount(messageId: String) throws {
        let predicate = #Predicate<QueuedMessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<QueuedMessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.retryCount += 1
            message.lastRetryTime = Date()
            try modelContext.save()
        }
    }
    
    // MARK: - Crash Recovery Operations
    
    func findStaleMessages(olderThan date: Date, statuses: [MessageStatus]) throws -> [MessageEntity] {
        let statusStrings = statuses.map { $0.rawValue }
        
        let predicate = #Predicate<MessageEntity> { message in
            statusStrings.contains(message.statusRaw) &&
            message.timestamp < date
        }
        
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Read Receipt Operations
    
    func resetUnreadCount(conversationId: String) throws {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            conversation.unreadCount = 0
            try modelContext.save()
        }
    }
    
    func incrementUnreadCount(conversationId: String) throws {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            conversation.unreadCount += 1
            try modelContext.save()
        }
    }
    
    // MARK: - Data Cleanup
    
    /// Clear all local data (messages, conversations, queued messages)
    /// Should be called on user logout to prevent data leakage between users
    func clearAllData() throws {
        print("🗑️ [LocalStorage] Clearing all local data...")
        
        // Delete all messages
        let messageDescriptor = FetchDescriptor<MessageEntity>()
        let allMessages = try modelContext.fetch(messageDescriptor)
        for message in allMessages {
            modelContext.delete(message)
        }
        print("   Deleted \(allMessages.count) messages")
        
        // Delete all conversations
        let conversationDescriptor = FetchDescriptor<ConversationEntity>()
        let allConversations = try modelContext.fetch(conversationDescriptor)
        for conversation in allConversations {
            modelContext.delete(conversation)
        }
        print("   Deleted \(allConversations.count) conversations")
        
        // Delete all queued messages
        let queuedDescriptor = FetchDescriptor<QueuedMessageEntity>()
        let allQueued = try modelContext.fetch(queuedDescriptor)
        for queued in allQueued {
            modelContext.delete(queued)
        }
        print("   Deleted \(allQueued.count) queued messages")
        
        try modelContext.save()
        print("✅ [LocalStorage] All local data cleared successfully")
    }
}

