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
                
                // PR-11: Handle image messages vs text messages
                if queuedMessage.isImageMessage {
                    await processImageMessage(queuedMessage)
                } else {
                    await processTextMessage(queuedMessage)
                }
            }
            
            updateQueueCount()
            print("✅ Queue processing complete")
            
        } catch {
            print("❌ Queue processing error: \(error)")
        }
    }
    
    // PR-11: Process text message from queue
    private func processTextMessage(_ queuedMessage: QueuedMessageEntity) async {
        guard let text = queuedMessage.text else {
            print("⚠️ Text message has no text content")
            try? markMessageAsFailed(queuedMessage)
            return
        }
        
        do {
            // Extract recipient ID from conversation ID
            let conversationId = queuedMessage.conversationId
            let participants = conversationId.split(separator: "_").map(String.init)
            
            guard participants.count == 2 else {
                print("⚠️ Invalid conversation ID format")
                return
            }
            
            let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
            let recipientId = participants.first { $0 != currentUserId } ?? ""
            
            print("📤 Attempting to send queued text message: \(queuedMessage.id)")
            
            // Attempt to send
            try await messageService.sendToFirestore(
                messageId: queuedMessage.id,
                text: text,
                conversationId: queuedMessage.conversationId,
                senderId: currentUserId,
                recipientId: recipientId
            )
            
            // Success - remove from queue
            try localStorage.removeQueuedMessage(queuedMessage.id)
            print("✅ Queued text message sent successfully: \(queuedMessage.id)")
            
            // Update message status to delivered
            try localStorage.updateMessageStatus(
                messageId: queuedMessage.id,
                status: .delivered
            )
            
        } catch {
            // Failed - increment retry count
            print("❌ Failed to send queued text message \(queuedMessage.id): \(error)")
            try? localStorage.incrementRetryCount(messageId: queuedMessage.id)
        }
    }
    
    // PR-11: Process image message from queue
    private func processImageMessage(_ queuedMessage: QueuedMessageEntity) async {
        guard let imageLocalPath = queuedMessage.imageLocalPath else {
            print("⚠️ Image message has no local path")
            try? markMessageAsFailed(queuedMessage)
            return
        }
        
        print("📸 Processing queued image message: \(queuedMessage.id)")
        
        // Load image from local storage
        guard let image = try? ImageFileManager.shared.loadImage(withId: queuedMessage.id) else {
            print("❌ Failed to load image from local storage")
            try? markMessageAsFailed(queuedMessage)
            return
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
            
        } catch {
            print("❌ Failed to send queued image message \(queuedMessage.id): \(error)")
            try? localStorage.incrementRetryCount(messageId: queuedMessage.id)
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

