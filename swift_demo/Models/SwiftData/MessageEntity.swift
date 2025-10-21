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
    var readBy: [String]
    
    // PR-7: Image support
    var imageUrl: String? // Download URL from Firebase Storage
    var imageLocalPath: String? // Local file path for offline queue
    var imageWidth: Double? // Image dimensions for display
    var imageHeight: Double?
    
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
        imageUrl: String? = nil,
        imageLocalPath: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.readBy = readBy
        self.imageUrl = imageUrl
        self.imageLocalPath = imageLocalPath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

