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
    var groupName: String?
    var createdBy: String?
    var lastMessageText: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]
    
    init(id: String, participantIds: [String], isGroup: Bool = false, groupName: String? = nil, createdBy: String? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.isGroup = isGroup
        self.groupName = groupName
        self.createdBy = createdBy
        self.unreadCount = 0
        self.messages = []
    }
}

