//
//  PersistenceController.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import SwiftData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: ModelContainer
    
    private init() {
        let schema = Schema([
            MessageEntity.self,
            ConversationEntity.self,
            QueuedMessageEntity.self,
            TranslationCacheEntity.self,
            WordUsageEntity.self,
            DefinitionCacheEntity.self,
            EnglishUsageEntity.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
}

