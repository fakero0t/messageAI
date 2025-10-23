//
//  DefinitionCacheEntity.swift
//  swift_demo
//
//  Created for AI V3: Word Definition Lookup
//

import Foundation
import SwiftData

@Model
final class DefinitionCacheEntity {
    @Attribute(.unique) var wordKey: String
    var definition: String
    var example: String
    var cachedAt: Date
    var lastAccessedAt: Date
    var accessCount: Int
    
    init(
        wordKey: String,
        definition: String,
        example: String,
        cachedAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        accessCount: Int = 1
    ) {
        self.wordKey = wordKey
        self.definition = definition
        self.example = example
        self.cachedAt = cachedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
    }
}

