//
//  WordUsageEntity.swift
//  swift_demo
//
//  Created for PR-1: Word Usage Tracking & Georgian Detection Foundation
//

import Foundation
import SwiftData

@Model
final class WordUsageEntity {
    @Attribute(.unique) var wordKey: String
    var count30d: Int
    var lastUsedAt: Date
    
    init(wordKey: String, count30d: Int = 1, lastUsedAt: Date = Date()) {
        self.wordKey = wordKey
        self.count30d = count30d
        self.lastUsedAt = lastUsedAt
    }
}

