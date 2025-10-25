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
    private var lastProcessingTime: Date?
    private let minimumProcessingInterval: TimeInterval = 2.0 // Debounce: wait 2 seconds between processing attempts
    
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
    
    // PR-11: Queue image message for offline sending
    func queueImageMessage(
        id: String,
        conversationId: String,
        imageLocalPath: String,
        imageWidth: Double,
        imageHeight: Double
    ) throws {
        let queuedMessage = QueuedMessageEntity(
            id: id,
            conversationId: conversationId,
            text: nil,
            timestamp: Date(),
            imageLocalPath: imageLocalPath,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
        
        try localStorage.queueMessage(queuedMessage)
        updateQueueCount()
        print("📥 Image message queued: \(id)")
    }
    
    func processQueue() async {
        guard !isProcessing else {
            print("⚠️ Queue already processing")
            return
        }
        
        // Debounce: prevent rapid-fire processing
        if let lastTime = lastProcessingTime {
            let timeSinceLastProcessing = Date().timeIntervalSince(lastTime)
            if timeSinceLastProcessing < minimumProcessingInterval {
                print("⏱️ Debouncing: Last processed \(String(format: "%.1f", timeSinceLastProcessing))s ago, waiting...")
                return
            }
        }
        
        isProcessing = true
        lastProcessingTime = Date()
        defer { 
            isProcessing = false 
            print("🏁 Processing complete, isProcessing set to false")
        }
        
        print("🔄 Processing message queue...")
        
        do {
            let queuedMessages = try localStorage.getQueuedMessages()
            print("📋 Found \(queuedMessages.count) queued messages")
            
            guard !queuedMessages.isEmpty else {
                print("✅ Queue is empty")
                updateQueueCount()
                return
            }
            
            // Process messages one at a time to avoid overwhelming Firestore
            var successCount = 0
            var failedCount = 0
            
            for (index, queuedMessage) in queuedMessages.enumerated() {
                print("📤 Processing message \(index + 1)/\(queuedMessages.count): \(queuedMessage.id.prefix(8))")
                
                // Check retry count
                if queuedMessage.retryCount >= maxRetries {
                    print("❌ Max retries reached for message: \(queuedMessage.id)")
                    try markMessageAsFailed(queuedMessage)
                    failedCount += 1
                    continue
                }
                
                // PR-11: Handle image messages vs text messages
                let success: Bool
                if queuedMessage.isImageMessage {
                    success = await processImageMessage(queuedMessage)
                } else {
                    success = await processTextMessage(queuedMessage)
                }
                
                if success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
                
                // Update count after each message so UI shows progress
                updateQueueCount()
            }
            
            print("✅ Queue processing complete: \(successCount) sent, \(failedCount) failed")
            
        } catch {
            print("❌ Queue processing error: \(error)")
        }
    }
    
    // PR-11: Process text message from queue
    // Returns true if successful, false if failed
    private func processTextMessage(_ queuedMessage: QueuedMessageEntity) async -> Bool {
        guard let text = queuedMessage.text else {
            print("⚠️ Text message has no text content")
            try? markMessageAsFailed(queuedMessage)
            return false
        }
        
        do {
            let conversationId = queuedMessage.conversationId
            let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
            
            // Extract recipient ID from conversation ID
            // For one-on-one: conversationId = "userId1_userId2"
            // For groups: conversationId = custom group ID (doesn't follow pattern)
            var recipientId = ""
            let participants = conversationId.split(separator: "_").map(String.init)
            
            if participants.count == 2 {
                // One-on-one chat
                recipientId = participants.first { $0 != currentUserId } ?? ""
                print("📤 Sending queued message (1-on-1): \(queuedMessage.id.prefix(8))")
            } else {
                // Group chat - recipientId can be empty
                print("📤 Sending queued message (group): \(queuedMessage.id.prefix(8))")
            }
            
            // Attempt to send (use noRetry policy since queue has its own retry logic)
            try await messageService.sendToFirestore(
                messageId: queuedMessage.id,
                text: text,
                conversationId: queuedMessage.conversationId,
                senderId: currentUserId,
                recipientId: recipientId,
                retryPolicy: .noRetry
            )
            
            // Success - remove from queue
            try localStorage.removeQueuedMessage(queuedMessage.id)
            print("   ✅ Sent & removed from queue")
            
            // Update message status to delivered
            try localStorage.updateMessageStatus(
                messageId: queuedMessage.id,
                status: .delivered
            )
            
            return true
            
        } catch {
            // Failed - increment retry count
            print("   ❌ Failed: \(error.localizedDescription)")
            try? localStorage.incrementRetryCount(messageId: queuedMessage.id)
            return false
        }
    }
    
    // PR-11: Process image message from queue
    // Returns true if successful, false if failed
    private func processImageMessage(_ queuedMessage: QueuedMessageEntity) async -> Bool {
        guard let imageLocalPath = queuedMessage.imageLocalPath else {
            print("⚠️ Image message has no local path")
            try? markMessageAsFailed(queuedMessage)
            return false
        }
        
        print("📸 Processing queued image message: \(queuedMessage.id)")
        
        // Load image from local storage
        guard let image = try? ImageFileManager.shared.loadImage(withId: queuedMessage.id) else {
            print("❌ Failed to load image from local storage")
            try? markMessageAsFailed(queuedMessage)
            return false
        }
        
        do {
            // Get dimensions
            let dimensions = ImageCompressor.getDimensions(image)
            
            // Extract recipient ID
            let participants = queuedMessage.conversationId.split(separator: "_").map(String.init)
            let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
            let recipientId = participants.first { $0 != currentUserId } ?? ""
            
            print("☁️ Uploading queued image to Firebase Storage...")
            
            // Upload to Firebase Storage
            let downloadUrl = try await ImageUploadService.shared.uploadImage(
                image,
                messageId: queuedMessage.id,
                conversationId: queuedMessage.conversationId,
                progressHandler: { progress in
                    print("📊 Upload progress: \(Int(progress.progress * 100))%")
                }
            )
            
            print("✅ Image uploaded, sending to Firestore...")
            
            // Send to Firestore
            try await MessageService.shared.sendImageMessage(
                messageId: queuedMessage.id,
                imageUrl: downloadUrl,
                conversationId: queuedMessage.conversationId,
                senderId: currentUserId,
                recipientId: recipientId,
                imageWidth: queuedMessage.imageWidth ?? dimensions.width,
                imageHeight: queuedMessage.imageHeight ?? dimensions.height
            )
            
            // Success - remove from queue
            try localStorage.removeQueuedMessage(queuedMessage.id)
            print("✅ Queued image message sent successfully: \(queuedMessage.id)")
            
            // Update local message with URL
            try localStorage.updateImageMessage(
                messageId: queuedMessage.id,
                imageUrl: downloadUrl,
                status: .delivered
            )
            
            // Clean up local file
            try? ImageFileManager.shared.deleteImage(withId: queuedMessage.id)
            print("🗑️ Cleaned up local image file")
            
            return true
            
        } catch {
            print("❌ Failed to send queued image message \(queuedMessage.id): \(error)")
            try? localStorage.incrementRetryCount(messageId: queuedMessage.id)
            return false
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
    
    /// Force process the queue immediately (bypasses debouncing) - useful for manual retry
    func forceProcessQueue() async {
        guard !isProcessing else {
            print("⚠️ Queue already processing")
            return
        }
        
        print("🔄 Force processing queue (bypassing debounce)...")
        lastProcessingTime = nil // Reset debounce timer
        await processQueue()
    }
    
    /// Clear all stuck messages that have exceeded max retries
    func clearFailedMessages() throws {
        let queuedMessages = try localStorage.getQueuedMessages()
        var clearedCount = 0
        
        for message in queuedMessages where message.retryCount >= maxRetries {
            try markMessageAsFailed(message)
            clearedCount += 1
        }
        
        updateQueueCount()
        print("🗑️ Cleared \(clearedCount) failed messages from queue")
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

