//
//  EnglishUsageEntity.swift
//  swift_demo
//
//  Created for AI V3: English→Georgian Translation Suggestions
//

import Foundation
import SwiftData

@Model
final class EnglishUsageEntity {
    @Attribute(.unique) var wordKey: String
    var count7d: Int
    var lastUsedAt: Date
    var firstUsedAt: Date
    var userVelocity: Double
    
    init(
        wordKey: String,
        count7d: Int = 1,
        lastUsedAt: Date = Date(),
        firstUsedAt: Date = Date(),
        userVelocity: Double = 0.0
    ) {
        self.wordKey = wordKey
        self.count7d = count7d
        self.lastUsedAt = lastUsedAt
        self.firstUsedAt = firstUsedAt
        self.userVelocity = userVelocity
    }
}

