//
//  ConversationEntity.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import SwiftData

@Model
final class ConversationEntity {
    @Attribute(.unique) var id: String
    var participantIds: [String]
    var isGroup: Bool
    var lastMessageText: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]
    
    init(id: String, participantIds: [String], isGroup: Bool = false) {
        self.id = id
        self.participantIds = participantIds
        self.isGroup = isGroup
        self.unreadCount = 0
        self.messages = []
    }
}

