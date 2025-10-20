//
//  QueuedMessageEntity.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import SwiftData

@Model
final class QueuedMessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var text: String
    var timestamp: Date
    var retryCount: Int
    var lastRetryTime: Date?
    
    init(id: String, conversationId: String, text: String, timestamp: Date) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.timestamp = timestamp
        self.retryCount = 0
    }
}

