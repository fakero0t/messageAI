//
//  MessageQueueService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine

@MainActor
class MessageQueueService: ObservableObject {
    static let shared = MessageQueueService()
    
    @Published var queueCount = 0
    @Published var isProcessing = false
    
    private let localStorage = LocalStorageService.shared
    private let messageService = MessageService.shared
    private let retryPolicy = RetryPolicy.default
    private var cancellables = Set<AnyCancellable>()
    
    private let maxRetries = 5
    
    private init() {
        setupNetworkObserver()
        updateQueueCount()
    }
    
    func queueMessage(
        id: String,
        conversationId: String,
        text: String
    ) throws {
        let queuedMessage = QueuedMessageEntity(
            id: id,
            conversationId: conversationId,
            text: text,
            timestamp: Date()
        )
        
        try localStorage.queueMessage(queuedMessage)
        updateQueueCount()
        print("📥 Message queued: \(id)")
    }
    
    func processQueue() async {
        guard !isProcessing else {
            print("⚠️ Queue already processing")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        print("🔄 Processing message queue...")
        
        do {
            let queuedMessages = try localStorage.getQueuedMessages()
            print("📋 Found \(queuedMessages.count) queued messages")
            
            for queuedMessage in queuedMessages {
                // Check retry count
                if queuedMessage.retryCount >= maxRetries {
                    print("❌ Max retries reached for message: \(queuedMessage.id)")
                    try markMessageAsFailed(queuedMessage)
                    continue
                }
                
                do {
                    // Extract recipient ID from conversation ID
                    let conversationId = queuedMessage.conversationId
                    let participants = conversationId.split(separator: "_").map(String.init)
                    
                    guard participants.count == 2 else {
                        print("⚠️ Invalid conversation ID format")
                        continue
                    }
                    
                    let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                    let recipientId = participants.first { $0 != currentUserId } ?? ""
                    
                    print("📤 Attempting to send queued message: \(queuedMessage.id)")
                    
                    // Attempt to send
                    try await messageService.sendToFirestore(
                        messageId: queuedMessage.id,
                        text: queuedMessage.text,
                        conversationId: queuedMessage.conversationId,
                        senderId: currentUserId,
                        recipientId: recipientId
                    )
                    
                    // Success - remove from queue
                    try localStorage.removeQueuedMessage(queuedMessage.id)
                    print("✅ Queued message sent successfully: \(queuedMessage.id)")
                    
                    // Update message status to delivered
                    try localStorage.updateMessageStatus(
                        messageId: queuedMessage.id,
                        status: .delivered
                    )
                    
                } catch {
                    // Failed - increment retry count with backoff
                    print("❌ Failed to send queued message \(queuedMessage.id): \(error)")
                    try localStorage.incrementRetryCount(messageId: queuedMessage.id)
                    
                    // Apply backoff delay before next queue processing
                    let delay = retryPolicy.delay(forAttempt: queuedMessage.retryCount)
                    print("⏳ Will retry queue processing after \(String(format: "%.1f", delay))s")
                }
            }
            
            updateQueueCount()
            print("✅ Queue processing complete")
            
        } catch {
            print("❌ Error processing queue: \(error)")
        }
    }
    
    private func markMessageAsFailed(_ queuedMessage: QueuedMessageEntity) throws {
        try localStorage.updateMessageStatus(
            messageId: queuedMessage.id,
            status: .failed
        )
        try localStorage.removeQueuedMessage(queuedMessage.id)
        print("🚫 Message marked as failed: \(queuedMessage.id)")
    }
    
    private func updateQueueCount() {
        do {
            let queued = try localStorage.getQueuedMessages()
            queueCount = queued.count
        } catch {
            queueCount = 0
        }
    }
    
    private func setupNetworkObserver() {
        NotificationCenter.default.publisher(for: .networkRestored)
            .sink { [weak self] _ in
                print("🌐 Network restored - processing queue")
                Task {
                    await self?.processQueue()
                }
            }
            .store(in: &cancellables)
    }
}

