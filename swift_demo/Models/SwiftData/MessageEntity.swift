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
    var text: String
    var timestamp: Date
    var statusRaw: String
    var readBy: [String]
    
    @Relationship(deleteRule: .nullify, inverse: \ConversationEntity.messages)
    var conversation: ConversationEntity?
    
    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    init(id: String, conversationId: String, senderId: String, text: String, 
         timestamp: Date, status: MessageStatus, readBy: [String] = []) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.readBy = readBy
    }
}

