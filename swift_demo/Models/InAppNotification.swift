//
//  InAppNotification.swift
//  swift_demo
//
//  Created by ary on 10/21/25.
//

import Foundation

struct InAppNotification: Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderName: String
    let messageText: String
    let isGroup: Bool
    let timestamp: Date
    
    init(
        conversationId: String,
        senderName: String,
        messageText: String,
        isGroup: Bool
    ) {
        self.id = UUID().uuidString
        self.conversationId = conversationId
        self.senderName = senderName
        self.messageText = messageText
        self.isGroup = isGroup
        self.timestamp = Date()
    }
}

