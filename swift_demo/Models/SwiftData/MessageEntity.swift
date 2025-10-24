//
//  MessageEntity.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import SwiftData

@Model
final class MessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var text: String? // PR-7: Made nullable for image-only messages
    var timestamp: Date
    var statusRaw: String
    var readBy: [String] = []
    
    // Read receipts: Delivery tracking
    var deliveredTo: [String] = [] // User IDs who received the message
    var deliveredAt: Date? = nil // When message was first delivered
    var readAt: Date? = nil // When message was first read (for 1-on-1)
    
    // PR-7: Image support
    var imageUrl: String? // Download URL from Firebase Storage
    var imageLocalPath: String? // Local file path for offline queue
    var imageWidth: Double? // Image dimensions for display
    var imageHeight: Double?

    // AI Translation fields
    var translatedEn: String?
    var translatedKa: String?
    var originalLang: String?
    var translatedAt: Date?
    
    @Relationship(deleteRule: .nullify, inverse: \ConversationEntity.messages)
    var conversation: ConversationEntity?
    
    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    /// Check if this is an image message
    /// In Vue: computed(() => !!message.imageUrl || !!message.imageLocalPath)
    var isImageMessage: Bool {
        imageUrl != nil || imageLocalPath != nil
    }
    
    /// Display text for conversation list preview
    /// In Vue: computed(() => message.isImageMessage ? 'Image' : message.text || '')
    var displayText: String {
        if isImageMessage {
            return "Image"
        }
        return text ?? ""
    }
    
    init(
        id: String,
        conversationId: String,
        senderId: String,
        text: String? = nil,
        timestamp: Date,
        status: MessageStatus,
        readBy: [String] = [],
        deliveredTo: [String] = [],
        deliveredAt: Date? = nil,
        readAt: Date? = nil,
        imageUrl: String? = nil,
        imageLocalPath: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        translatedEn: String? = nil,
        translatedKa: String? = nil,
        originalLang: String? = nil,
        translatedAt: Date? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.readBy = readBy
        self.deliveredTo = deliveredTo
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.imageUrl = imageUrl
        self.imageLocalPath = imageLocalPath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.translatedEn = translatedEn
        self.translatedKa = translatedKa
        self.originalLang = originalLang
        self.translatedAt = translatedAt
    }
}

