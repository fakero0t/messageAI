//
//  MockServices.swift
//  swift_demoTests
//
//  Mock services for testing
//

import Foundation
import FirebaseFirestore
@testable import swift_demo

// Mock LocalStorageService for testing
class MockLocalStorageService {
    var messages: [MessageEntity] = []
    var queuedMessages: [QueuedMessageEntity] = []
    var conversations: [ConversationEntity] = []
    
    var shouldThrowError = false
    
    func saveMessage(_ message: MessageEntity) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        messages.append(message)
    }
    
    func messageExists(messageId: String) throws -> Bool {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        return messages.contains { $0.id == messageId }
    }
    
    func updateMessageStatus(messageId: String, status: MessageStatus) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
        }
    }
    
    func fetchMessages(for conversationId: String) throws -> [MessageEntity] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        return messages.filter { $0.conversationId == conversationId }
    }
    
    func queueMessage(_ message: QueuedMessageEntity) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        queuedMessages.append(message)
    }
    
    func getQueuedMessages() throws -> [QueuedMessageEntity] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        return queuedMessages
    }
    
    func removeQueuedMessage(_ messageId: String) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        queuedMessages.removeAll { $0.id == messageId }
    }
    
    func incrementRetryCount(messageId: String) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        if let index = queuedMessages.firstIndex(where: { $0.id == messageId }) {
            queuedMessages[index].retryCount += 1
        }
    }
    
    func findStaleMessages(olderThan date: Date, statuses: [MessageStatus]) throws -> [MessageEntity] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1)
        }
        return messages.filter { message in
            statuses.contains(message.status) && message.timestamp < date
        }
    }
}

// Mock User for testing
extension User {
    static func mockUser(id: String = "user123", email: String = "test@example.com") -> User {
        return User(
            id: id,
            email: email,
            displayName: "Test User",
            online: true,
            lastSeen: nil
        )
    }
}

// Mock MessageEntity for testing
extension MessageEntity {
    static func mockMessage(
        id: String = "msg123",
        conversationId: String = "conv123",
        senderId: String = "user123",
        text: String = "Test message",
        status: MessageStatus = .delivered
    ) -> MessageEntity {
        return MessageEntity(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            timestamp: Date(),
            status: status,
            readBy: []
        )
    }
}

// Mock QueuedMessageEntity for testing
extension QueuedMessageEntity {
    static func mockQueuedMessage(
        id: String = "queued123",
        conversationId: String = "conv123",
        text: String = "Queued message",
        retryCount: Int = 0
    ) -> QueuedMessageEntity {
        return QueuedMessageEntity(
            id: id,
            conversationId: conversationId,
            text: text,
            timestamp: Date(),
            retryCount: retryCount
        )
    }
}

