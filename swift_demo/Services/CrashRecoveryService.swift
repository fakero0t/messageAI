//
//  CrashRecoveryService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
class CrashRecoveryService {
    static let shared = CrashRecoveryService()
    
    private let localStorage = LocalStorageService.shared
    private let queueService = MessageQueueService.shared
    
    // Messages older than this threshold are considered potentially failed
    private let staleThreshold: TimeInterval = 5.0 // 5 seconds
    
    private init() {}
    
    /// Perform crash recovery on app launch
    func performRecovery() async {
        print("🔄 Starting crash recovery check...")
        
        do {
            // Find stale messages that may have failed due to crash
            let staleMessages = try findStaleMessages()
            
            guard !staleMessages.isEmpty else {
                print("✅ No stale messages found - recovery complete")
                return
            }
            
            print("⚠️ Found \(staleMessages.count) potentially failed message(s)")
            
            // Recover each message
            for message in staleMessages {
                await recoverMessage(message)
            }
            
            print("✅ Crash recovery complete - processed \(staleMessages.count) message(s)")
            
        } catch {
            print("❌ Crash recovery failed: \(error.localizedDescription)")
        }
    }
    
    /// Find messages that are stuck in pending/sent state
    private func findStaleMessages() throws -> [MessageEntity] {
        let thresholdDate = Date().addingTimeInterval(-staleThreshold)
        
        return try localStorage.findStaleMessages(
            olderThan: thresholdDate,
            statuses: [.pending, .sent]
        )
    }
    
    /// Recover a single message
    private func recoverMessage(_ message: MessageEntity) async {
        print("🔄 Recovering message: \(message.id) (status: \(message.status.rawValue))")
        
        // Check if message already exists in Firestore
        let existsInFirestore = await checkFirestoreForMessage(message.id)
        
        if existsInFirestore {
            // Message made it to Firestore - just update local status
            print("✅ Message \(message.id) found in Firestore, updating local status")
            do {
                try localStorage.updateMessageStatus(messageId: message.id, status: .delivered)
            } catch {
                print("⚠️ Failed to update local status: \(error)")
            }
        } else {
            // Message didn't make it to Firestore - queue for retry
            print("⚠️ Message \(message.id) not in Firestore, queueing for retry")
            
            do {
                // Extract recipient ID from conversation ID
                let recipientId = extractRecipientId(from: message.conversationId)
                
                // Check if already queued to prevent duplicates
                let alreadyQueued = try isMessageQueued(message.id)
                
                if !alreadyQueued {
                    // Add to queue
                    try queueService.queueMessage(
                        id: message.id,
                        conversationId: message.conversationId,
                        text: message.text
                    )
                    
                    // Update status to queued
                    try localStorage.updateMessageStatus(messageId: message.id, status: .queued)
                    print("✅ Message \(message.id) queued for retry")
                } else {
                    print("ℹ️ Message \(message.id) already queued")
                    try localStorage.updateMessageStatus(messageId: message.id, status: .queued)
                }
                
            } catch {
                print("❌ Failed to queue message \(message.id): \(error)")
                // Mark as failed so user can manually retry
                try? localStorage.updateMessageStatus(messageId: message.id, status: .failed)
            }
        }
    }
    
    /// Check if a message exists in Firestore
    private func checkFirestoreForMessage(_ messageId: String) async -> Bool {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("messages").document(messageId).getDocument()
            return snapshot.exists
        } catch {
            print("⚠️ Error checking Firestore for message \(messageId): \(error)")
            // On error, assume it doesn't exist to be safe
            return false
        }
    }
    
    /// Check if message is already in the queue
    private func isMessageQueued(_ messageId: String) throws -> Bool {
        let queuedMessages = try localStorage.getQueuedMessages()
        return queuedMessages.contains { $0.id == messageId }
    }
    
    /// Extract recipient ID from conversation ID
    private func extractRecipientId(from conversationId: String) -> String {
        let participants = conversationId.split(separator: "_").map(String.init)
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        return participants.first { $0 != currentUserId } ?? ""
    }
}

