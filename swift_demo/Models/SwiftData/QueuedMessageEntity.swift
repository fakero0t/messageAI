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
    var text: String?
    var timestamp: Date
    var retryCount: Int
    var lastRetryTime: Date?
    
    // PR-11: Image support
    var imageLocalPath: String?
    var isImageMessage: Bool
    var imageWidth: Double?
    var imageHeight: Double?
    
    init(
        id: String,
        conversationId: String,
        text: String?,
        timestamp: Date,
        imageLocalPath: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.timestamp = timestamp
        self.retryCount = 0
        self.imageLocalPath = imageLocalPath
        self.isImageMessage = imageLocalPath != nil
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

