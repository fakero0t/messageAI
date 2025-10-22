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
    
    // MARK: - Message Operations
    
    func saveMessage(_ message: MessageEntity) throws {
        modelContext.insert(message)
        try modelContext.save()
    }
    
    func fetchMessages(for conversationId: String) throws -> [MessageEntity] {
        let predicate = #Predicate<MessageEntity> { $0.conversationId == conversationId }
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
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
    
    func updateMessage(messageId: String, status: MessageStatus, readBy: [String]) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.status = status
            message.readBy = readBy
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
}

