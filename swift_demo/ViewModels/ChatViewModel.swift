//
//  ChatViewModel.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine
import UIKit

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageEntity] = []
    @Published var recipientOnline = false
    @Published var recipientLastSeen: Date?
    @Published var errorMessage: String?
    @Published var isSending = false
    
    // Group-specific
    @Published var isGroup = false
    @Published var groupName: String?
    @Published var participants: [User] = []
    @Published var isStillMember = true // Track if current user is still in the group
    
    // Typing indicator (PR-3)
    @Published var typingText: String?
    
    // Image upload progress (PR-9)
    @Published var uploadProgress: [String: Double] = [:]
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    private let listenerService = FirestoreListenerService.shared
    private let queueService = MessageQueueService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let readReceiptService = ReadReceiptService.shared
    private let userService = UserService.shared
    private let notificationService = NotificationService.shared
    private let typingService = TypingService.shared // PR-3
    private let imageUploadService = ImageUploadService.shared // PR-9
    private let wordUsageTrackingService = WordUsageTrackingService.shared // PR-1 (Geo Suggestions)
    private var typingDebounceTimer: Timer? // PR-3
    private var cancellables = Set<AnyCancellable>()
    
    // Track when chat was opened to filter out old messages from triggering notifications
    private let chatOpenedAt = Date()
    
    init(recipientId: String, conversationId: String? = nil) {
        print("🚀 [ChatViewModel] Initializing with recipientId: \(recipientId)")
        self.recipientId = recipientId
        
        // Capture currentUserId immediately (before it can change)
        guard let authenticatedUserId = AuthenticationService.shared.currentUser?.id, !authenticatedUserId.isEmpty else {
            print("❌ [ChatViewModel] CRITICAL: Cannot initialize ChatViewModel - user is not authenticated!")
            print("❌ [ChatViewModel] AuthenticationService.shared.currentUser: \(String(describing: AuthenticationService.shared.currentUser))")
            fatalError("ChatViewModel requires authenticated user")
        }
        
        self.currentUserId = authenticatedUserId
        print("✅ [ChatViewModel] Current User ID captured: \(self.currentUserId)")
        
        // Use provided conversationId (for groups) or generate it (for one-on-one)
        if let conversationId = conversationId {
            self.conversationId = conversationId
        } else {
            self.conversationId = ConversationService.shared.generateConversationId(
                userId1: self.currentUserId,
                userId2: recipientId
            )
        }
        
        print("🚀 [ChatViewModel] Conversation ID: \(self.conversationId)")
        print("🚀 [ChatViewModel] Current User ID: \(self.currentUserId)")
        
        loadConversationDetails()
        loadLocalMessages()
        startListening()
        observeNetwork()
        markMessagesAsRead()
        setupTypingObserver() // PR-3
        
        print("🚀 [ChatViewModel] Initialization complete")
    }
    
    private func loadConversationDetails() {
        Task {
            do {
                if let conversation = try? localStorage.fetchConversation(byId: conversationId) {
                    isGroup = conversation.isGroup
                    groupName = conversation.groupName
                    
                    if isGroup {
                        // Verify current user is still a participant
                        let isParticipant = conversation.participantIds.contains(currentUserId)
                        await MainActor.run {
                            isStillMember = isParticipant
                        }
                        
                        if !isParticipant {
                            print("⚠️ Current user is no longer a member of this group")
                            return
                        }
                        
                        // Load all participant details for groups
                        print("👥 Loading group details for: \(conversationId)")
                        for participantId in conversation.participantIds {
                            if let user = try? await userService.fetchUser(byId: participantId) {
                                participants.append(user)
                                print("  ✓ Loaded participant: \(user.displayName)")
                            }
                        }
                        print("  Total participants: \(participants.count)")
                    } else {
                        // Only observe recipient status for one-on-one chats (but not self-chats)
                        if !recipientId.isEmpty && recipientId != currentUserId {
                            await MainActor.run {
                                observeRecipientStatus()
                            }
                        }
                    }
                } else {
                    // No conversation found in local storage (new chat)
                    // Assume one-on-one if recipientId is not empty (but not self-chats)
                    if !recipientId.isEmpty && recipientId != currentUserId {
                        await MainActor.run {
                            observeRecipientStatus()
                        }
                    }
                }
            } catch {
                print("⚠️ Error loading conversation details: \(error)")
            }
        }
        
        // Monitor for real-time participant changes
        if isGroup {
            observeGroupMembership()
        }
    }
    
    /// Monitor if current user is removed from the group in real-time
    private func observeGroupMembership() {
        guard isGroup else { return }
        
        Task {
            // Check periodically if we're still a member by watching the conversation
            ConversationService.shared.listenToUserConversations(userId: currentUserId) { [weak self] snapshot in
                guard let self = self else { return }
                
                // If this is our conversation, check if we're still in participants
                if snapshot.id == self.conversationId {
                    Task { @MainActor in
                        let isParticipant = snapshot.participantIds.contains(self.currentUserId)
                        self.isStillMember = isParticipant
                        
                        if !isParticipant {
                            print("🚫 User was removed from group - stopping listeners")
                            // Stop all listeners
                            self.listenerService.stopListening(conversationId: self.conversationId)
                            self.typingService.stopObservingTypingUsers(conversationId: self.conversationId)
                            self.errorMessage = "You have been removed from this group"
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        // PR-3: Cleanup typing service
        typingService.stopObservingTypingUsers(conversationId: conversationId)
        typingService.stopTyping(conversationId: conversationId, userId: currentUserId)
        typingDebounceTimer?.invalidate()
        
        listenerService.stopListening(conversationId: conversationId)
    }
    
    func getSenderName(for message: MessageEntity) -> String? {
        guard isGroup else { return nil }
        return participants.first { $0.id == message.senderId }?.displayName
    }
    
    func sendMessage(text: String) {
        print("📤 [ChatViewModel] sendMessage called with text: '\(text)'")
        guard !text.isEmpty else {
            print("⚠️ [ChatViewModel] Text is empty, not sending")
            return
        }
        
        // PR-3: Stop typing indicator immediately when sending message
        stopTypingIndicator()
        print("🛑 [Typing] Stopped typing indicator on send")
        
        // PR-1 (Geo Suggestions): Track Georgian word usage
        Task { @MainActor in
            wordUsageTrackingService.trackMessage(text)
        }
        
        let messageId = UUID().uuidString
        print("📤 [ChatViewModel] Generated message ID: \(messageId)")
        
        // Determine initial status based on network
        let initialStatus: MessageStatus = networkMonitor.isConnected ? .pending : .queued
        print("📤 [ChatViewModel] Network connected: \(networkMonitor.isConnected), status: \(initialStatus)")
        
        // 1. Optimistic insert - show immediately
        let optimisticMessage = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: initialStatus
        )
        
        print("📤 [ChatViewModel] Created optimistic text message:")
        print("   MessageId: \(messageId)")
        print("   SenderId: '\(currentUserId)'")
        print("   Text: '\(text.prefix(30))'")
        
        messages.append(optimisticMessage)
        print("📤 [ChatViewModel] Message appended to local array, total messages: \(messages.count)")
        
        // 2. Handle based on network status
        if networkMonitor.isConnected {
            print("📤 [ChatViewModel] Sending online...")
            sendOnline(messageId: messageId, text: text)
        } else {
            print("📤 [ChatViewModel] Sending offline (queuing)...")
            sendOffline(messageId: messageId, text: text)
        }
    }
    
    private func sendOnline(messageId: String, text: String) {
        Task {
            do {
                // Save locally first
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .pending
                )
                try await MainActor.run {
                    try localStorage.saveMessage(message)
                }
                updateMessageStatus(messageId: messageId, status: .sent)
                
                // Send to Firestore
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                // Eager translation request (non-blocking)
                let tsMs = Int64(Date().timeIntervalSince1970 * 1000)
                TranslationTransport.shared.requestTranslation(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    timestampMs: tsMs
                ) { result in
                    if let result = result {
                        // Store into local cache for instant UI access
                        TranslationCacheService.shared.store(
                            sourceText: text,
                            english: result.translations.en,
                            georgian: result.translations.ka,
                            confidence: 1.0
                        )
                        
                        // Save translation to local storage
                        Task { @MainActor in
                            do {
                                try await self.localStorage.updateMessageTranslation(
                                    messageId: messageId,
                                    translatedEn: result.translations.en,
                                    translatedKa: result.translations.ka,
                                    originalLang: GeorgianScriptDetector.containsGeorgian(text) ? "ka" : "en"
                                )
                                print("💾 [ChatViewModel] Saved translation for sent message")
                            } catch {
                                print("⚠️ [ChatViewModel] Failed to save translation: \(error)")
                            }
                        }
                    }
                }
                
                print("✅ Message sent successfully")
                
            } catch {
                // If send fails, queue it
                print("⚠️ Send failed, queueing message: \(error)")
                updateMessageStatus(messageId: messageId, status: .queued)
                try? queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text
                )
            }
        }
    }
    
    private func sendOffline(messageId: String, text: String) {
        Task {
            do {
                // Save locally with queued status
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .queued
                )
                try await MainActor.run {
                    try localStorage.saveMessage(message)
                }
                
                // Add to queue
                try queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text
                )
                
                print("📥 Message queued (offline)")
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Failed to queue message"
                print("❌ Failed to queue: \(error)")
            }
        }
    }
    
    // PR-11: Send image message (with offline queue support)
    func sendImage(_ image: UIImage) {
        print("📸 [ChatViewModel] sendImage called")
        let messageId = UUID().uuidString
        
        Task {
            do {
                // 1. Compress and save locally
                guard let imagePath = try? ImageFileManager.shared.saveImage(image, withId: messageId) else {
                    errorMessage = "Failed to process image"
                    print("❌ Failed to save image locally")
                    return
                }
                
                let dimensions = ImageCompressor.getDimensions(image)
                print("📸 Image dimensions: \(Int(dimensions.width))x\(Int(dimensions.height))")
                
                // 2. Determine initial status based on network
                let initialStatus: MessageStatus = networkMonitor.isConnected ? .pending : .queued
                print("📸 Network connected: \(networkMonitor.isConnected), status: \(initialStatus)")
                
                // 3. Create optimistic message (shows immediately with local path)
                print("📸 [ChatViewModel] Created optimistic image message:")
                print("   MessageId: \(messageId)")
                print("   SenderId: '\(currentUserId)'")
                
                let optimisticMessage = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: nil, // Image-only message
                    timestamp: Date(),
                    status: initialStatus,
                    imageLocalPath: imagePath.path,
                    imageWidth: dimensions.width,
                    imageHeight: dimensions.height
                )
                
                messages.append(optimisticMessage)
                print("✅ Optimistic image message added to UI")
                
                // 4. Save to local storage
                try await MainActor.run {
                    try localStorage.saveMessage(optimisticMessage)
                }
                print("✅ Image message saved to local storage")
                
                // 5. Handle based on network status
                if networkMonitor.isConnected {
                    // Online - upload immediately
                    print("☁️ Starting upload to Firebase Storage...")
                    let downloadUrl = try await imageUploadService.uploadImage(
                        image,
                        messageId: messageId,
                        conversationId: conversationId,
                        progressHandler: { [weak self] progress in
                            Task { @MainActor in
                                self?.uploadProgress[messageId] = progress.progress
                                print("📊 Upload progress: \(Int(progress.progress * 100))%")
                            }
                        }
                    )
                    
                    print("✅ Image uploaded, URL: \(downloadUrl)")
                    
                    // Send to Firestore
                    try await messageService.sendImageMessage(
                        messageId: messageId,
                        imageUrl: downloadUrl,
                        conversationId: conversationId,
                        senderId: currentUserId,
                        recipientId: recipientId,
                        imageWidth: dimensions.width,
                        imageHeight: dimensions.height
                    )
                    
                    print("✅ Image message sent to Firestore")
                    
                    // Update local message with URL
                    try await MainActor.run {
                        try localStorage.updateImageMessage(
                            messageId: messageId,
                            imageUrl: downloadUrl,
                            status: .delivered
                        )
                    }
                    
                    // Update UI
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].imageUrl = downloadUrl
                        messages[index].status = .delivered
                    }
                    
                    uploadProgress.removeValue(forKey: messageId)
                    print("✅ Image message flow complete")
                    
                } else {
                    // Offline - queue for later
                    print("📥 Offline, queueing image message")
                    try queueService.queueImageMessage(
                        id: messageId,
                        conversationId: conversationId,
                        imageLocalPath: imagePath.path,
                        imageWidth: dimensions.width,
                        imageHeight: dimensions.height
                    )
                    print("✅ Image message queued for upload when online")
                }
                
            } catch {
                print("❌ Image send failed: \(error)")
                errorMessage = "Failed to send image"
                updateMessageStatus(messageId: messageId, status: .failed)
                uploadProgress.removeValue(forKey: messageId)
            }
        }
    }
    
    func retryMessage(messageId: String) {
        guard let message = messages.first(where: { $0.id == messageId }) else { return }
        
        // Check if it's an image message or text message
        if message.isImageMessage {
            retryImageMessage(messageId: messageId)
        } else if let text = message.text {
            retryTextMessage(messageId: messageId, text: text)
        } else {
            print("⚠️ Cannot retry: message has no content")
        }
    }
    
    private func retryTextMessage(messageId: String, text: String) {
        updateMessageStatus(messageId: messageId, status: .pending)
        
        Task {
            do {
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                updateMessageStatus(messageId: messageId, status: .sent)
                print("✅ Text message retry successful")
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Retry failed"
                print("❌ Text retry failed: \(error)")
            }
        }
    }
    
    private func retryImageMessage(messageId: String) {
        guard let message = messages.first(where: { $0.id == messageId }) else { return }
        
        print("🔄 [ChatViewModel] Retrying image message: \(messageId)")
        
        // Load image from local storage
        guard let image = try? ImageFileManager.shared.loadImage(withId: messageId) else {
            print("❌ Failed to load image from local storage")
            errorMessage = "Cannot retry: image file not found"
            return
        }
        
        updateMessageStatus(messageId: messageId, status: .pending)
        
        Task {
            do {
                let dimensions = ImageCompressor.getDimensions(image)
                
                // Upload to Firebase Storage
                print("☁️ Retrying upload to Firebase Storage...")
                let downloadUrl = try await imageUploadService.uploadImage(
                    image,
                    messageId: messageId,
                    conversationId: conversationId,
                    progressHandler: { [weak self] progress in
                        Task { @MainActor in
                            self?.uploadProgress[messageId] = progress.progress
                            print("📊 Upload progress: \(Int(progress.progress * 100))%")
                        }
                    }
                )
                
                print("✅ Image uploaded, URL: \(downloadUrl)")
                
                // Send to Firestore
                try await messageService.sendImageMessage(
                    messageId: messageId,
                    imageUrl: downloadUrl,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId,
                    imageWidth: message.imageWidth ?? dimensions.width,
                    imageHeight: message.imageHeight ?? dimensions.height
                )
                
                print("✅ Image message sent to Firestore")
                
                // Update local message with URL
                try await MainActor.run {
                    try localStorage.updateImageMessage(
                        messageId: messageId,
                        imageUrl: downloadUrl,
                        status: .delivered
                    )
                }
                
                // Update UI
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].imageUrl = downloadUrl
                    messages[index].status = .delivered
                }
                
                uploadProgress.removeValue(forKey: messageId)
                print("✅ Image message retry successful")
                
            } catch {
                print("❌ Image retry failed: \(error)")
                errorMessage = "Failed to retry image"
                updateMessageStatus(messageId: messageId, status: .failed)
                uploadProgress.removeValue(forKey: messageId)
            }
        }
    }
    
    func deleteMessage(messageId: String) {
        messages.removeAll { $0.id == messageId }
        
        Task {
            do {
                try await MainActor.run {
                    // Try to delete from local storage
                    if let message = try? localStorage.fetchMessages(for: conversationId).first(where: { $0.id == messageId }) {
                        try localStorage.deleteMessage(messageId: messageId)
                    }
                }
            } catch {
                print("⚠️ Error deleting message: \(error)")
            }
        }
    }
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
            
            Task {
                try? await MainActor.run {
                    try? localStorage.updateMessageStatus(messageId: messageId, status: status)
                }
            }
        }
    }
    
    func loadLocalMessages() {
        do {
            let fetchedMessages = try localStorage.fetchMessages(for: conversationId)
            messages = fetchedMessages.map { $0 } // Force new array to trigger SwiftUI update
            print("📨 Loaded \(messages.count) messages from local storage")
            
            // Debug: Log sender IDs for all messages
            for msg in messages {
                let preview = msg.text?.prefix(30) ?? (msg.imageUrl != nil ? "Image" : "Empty")
                print("   Message \(msg.id.prefix(8)): senderId='\(msg.senderId)' | text/type: \(preview)")
            }
            
            // If local has messages but we suspect they're stale, the Firestore listener will sync them
            // For fresh installs, ConversationListViewModel already fetches messages
            
        } catch {
            print("⚠️ Error loading local messages: \(error)")
        }
    }
    
    private func observeRecipientStatus() {
        guard !recipientId.isEmpty else {
            print("⚠️ [ChatViewModel] Cannot observe recipient status: recipientId is empty")
            return
        }
        
        UserService.shared.observeUserStatus(userId: recipientId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.recipientOnline = user?.online ?? false
                self?.recipientLastSeen = user?.lastSeen
            }
            .store(in: &cancellables)
    }
    
    private func startListening() {
        print("🎧 [ChatViewModel] Setting up listener for conversation: \(conversationId)")
        
        listenerService.listenToMessages(conversationId: conversationId) { [weak self] snapshot in
            guard let self = self else { 
                print("⚠️ [ChatViewModel] Self is nil in listener callback")
                return 
            }
            
            print("📬 [ChatViewModel] Received message in callback: \(snapshot.text)")
            print("   From: \(snapshot.senderId)")
            print("   Current user: \(self.currentUserId)")
            
            // PR-3: Clear typing indicator for sender (they just sent a message, so they're not typing)
            // In Vue: typingUsers.value = typingUsers.value.filter(u => u.id !== message.senderId)
            if snapshot.senderId != self.currentUserId {
                print("🛑 [Typing] Clearing typing indicator for message sender: \(snapshot.senderId)")
                self.clearTypingIndicatorForUser(userId: snapshot.senderId)
            }
            
            Task {
                do {
                    print("💾 [ChatViewModel] Syncing message to local storage...")
                    try await self.messageService.syncMessageFromFirestore(snapshot)
                    
                    // Automatically translate received message
                    if let text = snapshot.text, !text.isEmpty {
                        let tsMs = Int64(Date().timeIntervalSince1970 * 1000)
                        TranslationTransport.shared.requestTranslation(
                            messageId: snapshot.id,
                            text: text,
                            conversationId: snapshot.conversationId,
                            timestampMs: tsMs
                        ) { result in
                            if let result = result {
                                // Store into local cache
                                TranslationCacheService.shared.store(
                                    sourceText: text,
                                    english: result.translations.en,
                                    georgian: result.translations.ka,
                                    confidence: 1.0
                                )
                                
                                // Save translation to local storage
                                Task { @MainActor in
                                    do {
                                        try await self.localStorage.updateMessageTranslation(
                                            messageId: snapshot.id,
                                            translatedEn: result.translations.en,
                                            translatedKa: result.translations.ka,
                                            originalLang: GeorgianScriptDetector.containsGeorgian(text) ? "ka" : "en"
                                        )
                                        print("💾 [ChatViewModel] Saved translation for received message")
                                    } catch {
                                        print("⚠️ [ChatViewModel] Failed to save translation: \(error)")
                                    }
                                }
                            }
                        }
                    }
                    
                    await MainActor.run {
                        print("🔄 [ChatViewModel] Triggering UI update...")
                        self.objectWillChange.send() // Explicitly trigger update
                        self.loadLocalMessages()
                        
                        // Only trigger notification for NEW messages that arrived AFTER chat was opened
                        // This prevents notifications for existing messages when opening the chat
                        if snapshot.senderId != self.currentUserId {
                            let messageTimestamp = snapshot.timestamp
                            let isNewMessage = messageTimestamp > self.chatOpenedAt
                            
                            print("🔔 [ChatViewModel] Message from someone else:")
                            print("   Message timestamp: \(messageTimestamp)")
                            print("   Chat opened at: \(self.chatOpenedAt)")
                            print("   Is new message: \(isNewMessage)")
                            
                            if isNewMessage {
                                print("✅ [ChatViewModel] NEW message - triggering notification")
                                self.showNotificationForMessage(snapshot)
                            } else {
                                print("⏭️ [ChatViewModel] OLD message - skipping notification")
                            }
                        } else {
                            print("ℹ️ [ChatViewModel] Message is from current user, skipping notification")
                        }
                    }
                } catch {
                    print("❌ [ChatViewModel] Error syncing message: \(error)")
                }
            }
        }
    }
    
    private func showNotificationForMessage(_ snapshot: MessageSnapshot) {
        // Fetch sender name asynchronously
        Task {
            let senderName: String
            
            if isGroup {
                // For groups, look up in participants array
                senderName = participants.first { $0.id == snapshot.senderId }?.displayName ?? "Unknown"
            } else {
                // For one-on-one, fetch the sender's User object to get displayName/username
                do {
                    let sender = try await userService.fetchUser(byId: snapshot.senderId)
                    senderName = sender.displayName
                    print("   Sender name: \(senderName) (@\(sender.username))")
                } catch {
                    senderName = "Someone"
                    print("   ⚠️ Could not fetch sender name: \(error)")
                }
            }
            
            await MainActor.run {
                // Show system notification (will be suppressed if user is viewing this conversation)
                notificationService.showMessageNotification(
                    conversationId: conversationId,
                    senderName: senderName,
                    messageText: snapshot.text ?? "Image",
                    isGroup: isGroup
                )
                
                // ✨ NEW: Show in-app notification (always, even if in conversation)
                let inAppNotification = InAppNotification(
                    conversationId: conversationId,
                    senderName: senderName,
                    messageText: snapshot.text ?? "Image",
                    isGroup: isGroup
                )
                InAppNotificationManager.shared.show(inAppNotification)
                print("🔔 [ChatViewModel] In-app notification triggered for: \(senderName)")
            }
        }
        
        // ✨ NEW: Increment unread count ONLY if user not viewing this conversation
        let isViewingThisConversation = notificationService.currentConversationId == conversationId
        print("📊 [ChatViewModel] Unread count check:")
        print("   Current conversation: \(notificationService.currentConversationId ?? "nil")")
        print("   Message conversation: \(conversationId)")
        print("   Is viewing: \(isViewingThisConversation)")
        
        if !isViewingThisConversation {
            print("📊 [ChatViewModel] User NOT viewing this conversation - incrementing unread count")
            Task {
                do {
                    try await localStorage.incrementUnreadCount(conversationId: conversationId)
                    print("✅ [ChatViewModel] Unread count incremented for: \(conversationId)")
                } catch {
                    print("❌ [ChatViewModel] Failed to increment unread count: \(error)")
                }
            }
        } else {
            print("ℹ️ [ChatViewModel] User IS viewing conversation - skipping unread count increment")
        }
    }
    
    private func observeNetwork() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                print(isConnected ? "🌐 Network connected" : "📵 Network disconnected")
                
                // Process queue when coming back online
                if isConnected {
                    Task {
                        await self.queueService.processQueue()
                        self.loadLocalMessages()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func markMessagesAsRead() {
        Task {
            do {
                try await readReceiptService.markMessagesAsRead(
                    conversationId: conversationId,
                    userId: currentUserId
                )
                loadLocalMessages()
            } catch {
                print("⚠️ Failed to mark messages as read: \(error)")
            }
        }
    }
    
    // MARK: - Typing Indicator (PR-3)
    
    /// In Vue: const { typingUsers } = useTypingIndicator(conversationId)
    /// Sets up observer for typing users and updates typingText reactively
    private func setupTypingObserver() {
        print("👂 [Typing] Setting up typing observer for conversation: \(conversationId)")
        typingService.observeTypingUsers(conversationId: conversationId, currentUserId: currentUserId)
        
        // Watch for changes in typingUsers and format the display text
        // In Vue: watch(typingUsers, (users) => { typingText.value = formatTypingText(users) })
        typingService.$typingUsers
            .map { [weak self] typingUsersDict -> String? in
                guard let self = self else { return nil }
                let users = typingUsersDict[self.conversationId] ?? []
                print("📝 [Typing] Users typing in \(self.conversationId): \(users.map { $0.displayName })")
                let formatted = self.typingService.formatTypingText(for: self.conversationId)
                print("📝 [Typing] Formatted text: \(formatted ?? "nil")")
                return formatted
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] formattedText in
                print("🎨 [Typing] Updating UI with text: \(formattedText ?? "nil")")
                self?.typingText = formattedText
            }
            .store(in: &cancellables)
    }
    
    /// Called when user types in the message input field
    /// In Vue: const handleTextChange = (text: string) => { ... }
    func handleTextFieldChange(text: String) {
        guard let currentUserName = AuthenticationService.shared.currentUser?.displayName else {
            print("⚠️ [Typing] No current user display name")
            return
        }
        
        print("⌨️ [Typing] Text changed: '\(text)' in conversation: \(conversationId)")
        
        // Cancel existing timer
        typingDebounceTimer?.invalidate()
        
        if !text.isEmpty {
            // User is typing - broadcast status
            print("✅ [Typing] Starting typing indicator for \(currentUserName)")
            typingService.startTyping(
                conversationId: conversationId,
                userId: currentUserId,
                displayName: currentUserName
            )
            
            // Set timer to stop typing after 2 seconds of no changes (prevents stuck indicators)
            // Reduced from 2.5s to 2s to be faster and sync with TypingService's 3s timeout
            typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("⏱️ [Typing] Auto-stopping typing after 2s of inactivity")
                self.typingService.stopTyping(
                    conversationId: self.conversationId,
                    userId: self.currentUserId
                )
            }
        } else {
            // Text field is empty - stop typing immediately
            print("🛑 [Typing] Stopping typing indicator (text cleared)")
            stopTypingIndicator()
        }
    }
    
    /// Explicitly stop typing indicator (called when leaving chat)
    func stopTypingIndicator() {
        typingDebounceTimer?.invalidate()
        typingService.stopTyping(
            conversationId: conversationId,
            userId: currentUserId
        )
    }
    
    /// Clear typing indicator for a specific user (called when they send a message)
    /// In Vue: typingUsers.value = typingUsers.value.filter(u => u.id !== userId)
    private func clearTypingIndicatorForUser(userId: String) {
        // Get current typing users for this conversation
        guard var users = typingService.typingUsers[conversationId] else {
            return
        }
        
        // Remove the specific user
        users.removeAll { $0.id == userId }
        
        // Update the published property on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.typingService.typingUsers[self.conversationId] = users
            print("✅ [Typing] Removed typing indicator for user: \(userId), remaining: \(users.count)")
        }
    }
    
}

