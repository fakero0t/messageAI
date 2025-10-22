//
//  ConversationListViewModel.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine
import FirebaseFirestore

struct ConversationWithDetails: Identifiable, Hashable {
    let conversation: ConversationEntity
    let participants: [User]
    let isSelfChat: Bool
    
    var id: String { conversation.id }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(conversation.id)
    }
    
    static func == (lhs: ConversationWithDetails, rhs: ConversationWithDetails) -> Bool {
        lhs.conversation.id == rhs.conversation.id
    }
    
    var displayName: String {
        if conversation.isGroup {
            // Show group name if available, otherwise participant names
            if let groupName = conversation.groupName, !groupName.isEmpty {
                return groupName
            } else {
                let names = participants.map { $0.displayName }
                return names.isEmpty ? "Group Chat" : names.joined(separator: ", ")
            }
        } else if isSelfChat {
            // Self-chat: show special label
            return "You (Notes to Self)"
        } else {
            // One-on-one: other participant's name
            return participants.first?.displayName ?? "Unknown"
        }
    }
    
    var displayAvatar: String {
        if conversation.isGroup {
            // Show group icon
            return "👥"
        } else {
            return participants.first?.displayName.prefix(1).uppercased() ?? "?"
        }
    }
    
    var recipientId: String {
        // For one-on-one, return participant ID; for groups, return empty (not used)
        if conversation.isGroup {
            return "" // Not used for groups
        } else {
            return participants.first?.id ?? ""
        }
    }
    
    var isGroup: Bool { // Added for PR-17
        conversation.isGroup
    }
}

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ConversationWithDetails] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let localStorage = LocalStorageService.shared
    private let conversationService = ConversationService.shared
    private let userService = UserService.shared
    private let notificationService = NotificationService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var authCancellable: AnyCancellable?
    private var listeningUserId: String?
    
    init() {
        observeAuthAndBootstrap()
    }
    
    private func observeAuthAndBootstrap() {
        // If already authenticated, bootstrap immediately
        if let id = AuthenticationService.shared.currentUser?.id, !id.isEmpty {
            loadConversations()
            startListening(for: id)
        }
        
        // Re-bootstrap when the authenticated user changes
        authCancellable = AuthenticationService.shared.$currentUser
            .compactMap { $0?.id }
            .removeDuplicates()
            .sink { [weak self] userId in
                guard let self = self else { return }
                self.loadConversations()
                self.startListening(for: userId)
            }
    }

    deinit {
        if let id = listeningUserId {
            conversationService.stopListeningToConversations(userId: id)
        }
        authCancellable?.cancel()
    }

    func loadConversations() {
        isLoading = true
        
        Task {
            do {
                guard let currentUserId = AuthenticationService.shared.currentUser?.id else {
                    print("⚠️ [ConversationListViewModel] No current user ID - cannot load conversations")
                    isLoading = false
                    return
                }
                
                // Load from local storage - ONLY conversations where current user is a participant
                var localConversations = try localStorage.fetchConversationsForUser(userId: currentUserId)
                
                print("📂 [ConversationListViewModel] Loaded \(localConversations.count) conversations from local storage for user \(currentUserId)")
                
                // If local storage is empty (fresh install), fetch from Firestore
                if localConversations.isEmpty {
                    print("🌐 [ConversationListViewModel] Local storage empty - fetching from Firestore...")
                    await fetchConversationsFromFirestore()
                    localConversations = try localStorage.fetchConversationsForUser(userId: currentUserId)
                    print("📂 [ConversationListViewModel] Loaded \(localConversations.count) conversations after Firestore sync")
                }
                
                // Sort by last message time
                let sorted = localConversations.sorted {
                    ($0.lastMessageTime ?? Date.distantPast) > ($1.lastMessageTime ?? Date.distantPast)
                }
                
                // Fetch participant details
                var conversationsWithDetails: [ConversationWithDetails] = []
                
                for conversation in sorted {
                    let details = try await loadConversationDetails(conversation)
                    conversationsWithDetails.append(details)
                }
                
                // Force UI update by creating new array
                await MainActor.run {
                    let oldCount = conversations.count
                    conversations = conversationsWithDetails
                    isLoading = false
                    
                    print("✅ [ConversationListViewModel] Updated UI with \(conversations.count) conversations (was \(oldCount))")
                    
                    // Log first conversation's last message for debugging
                    if let first = conversations.first {
                        print("   Top conversation: \(first.displayName)")
                        print("   Last message: \(first.conversation.lastMessageText ?? "none")")
                        print("   Last message time: \(first.conversation.lastMessageTime?.description ?? "none")")
                    }
                }
                
            } catch {
                print("❌ [ConversationListViewModel] Failed to load conversations: \(error)")
                errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func fetchConversationsFromFirestore() async {
        do {
            let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
            
            let db = Firestore.firestore()
            let snapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: currentUserId)
                .getDocuments()
            
            print("📥 Fetched \(snapshot.documents.count) conversations from Firestore")
            
            for document in snapshot.documents {
                let data = document.data()
                if let conversationSnapshot = try? parseConversation(from: data) {
                    try await conversationService.syncConversationFromFirestore(conversationSnapshot)
                    // Also fetch messages for this conversation
                    await fetchRecentMessages(for: conversationSnapshot.id)
                }
            }
            
        } catch {
            print("❌ Error fetching conversations from Firestore: \(error)")
        }
    }
    
    private func parseConversation(from data: [String: Any]) throws -> ConversationSnapshot {
        return ConversationSnapshot(
            id: data["id"] as? String ?? "",
            participantIds: data["participants"] as? [String] ?? [],
            isGroup: data["isGroup"] as? Bool ?? false,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageTime: (data["lastMessageTime"] as? Timestamp)?.dateValue()
        )
    }
    
    private func loadConversationDetails(_ conversation: ConversationEntity) async throws -> ConversationWithDetails {
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        
        // Check if this is a self-chat (conversation with yourself)
        let uniqueParticipants = Set(conversation.participantIds)
        let isSelfChat = uniqueParticipants.count == 1 && uniqueParticipants.first == currentUserId
        
        // Get other participants (exclude current user, unless it's a self-chat)
        let otherParticipants: [String]
        if isSelfChat {
            // For self-chats, include the current user
            otherParticipants = [currentUserId]
        } else {
            // Normal behavior: exclude current user
            otherParticipants = conversation.participantIds.filter { $0 != currentUserId }
        }
        
        // Fetch user details
        var participantUsers: [User] = []
        for participantId in otherParticipants {
            do {
                let user = try await userService.fetchUser(byId: participantId)
                participantUsers.append(user)
                print("👤 Fetched user: \(user.displayName)")
            } catch {
                print("⚠️ Failed to fetch user \(participantId): \(error)")
                // Create placeholder user
                let placeholderUser = User(
                    id: participantId,
                    email: "unknown@example.com",
                    username: "unknown",
                    displayName: "Unknown User"
                )
                participantUsers.append(placeholderUser)
            }
        }
        
        return ConversationWithDetails(
            conversation: conversation,
            participants: participantUsers,
            isSelfChat: isSelfChat
        )
    }
    
    private func startListening(for userId: String) {
        guard !userId.isEmpty else { return }
        
        // If we were listening for a different user, stop it first
        if let prev = listeningUserId, prev != userId {
            conversationService.stopListeningToConversations(userId: prev)
        }
        listeningUserId = userId
        
        print("🎧 [ConversationListViewModel] Starting conversation listener for user: \(userId)")
        conversationService.listenToUserConversations(userId: userId) { [weak self] snapshot in
            print("📬 [ConversationListViewModel] Conversation update received: \(snapshot.id)")
            print("   Last message: \(snapshot.lastMessageText ?? "none")")
            Task {
                await self?.handleConversationUpdate(snapshot)
            }
        }
    }
    
    private func handleConversationUpdate(_ snapshot: ConversationSnapshot) async {
        print("🔄 [ConversationListViewModel] Handling conversation update for: \(snapshot.id)")
        print("   Last message: \(snapshot.lastMessageText ?? "none")")
        print("   Last message time: \(snapshot.lastMessageTime?.description ?? "none")")
        
        // Check if current user is still a participant
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        if !snapshot.participantIds.contains(currentUserId) {
            print("🚫 [ConversationListViewModel] Current user removed from conversation \(snapshot.id) - deleting from local storage")
            await MainActor.run {
                try? localStorage.deleteConversation(byId: snapshot.id)
            }
            // Reload conversations to update UI
            loadConversations()
            return
        }
        
        do {
            // Sync to local storage
            try await conversationService.syncConversationFromFirestore(snapshot)
            print("✅ [ConversationListViewModel] Conversation synced to local storage")
            
            // Fetch recent messages for this conversation
            // This ensures group messages appear even if user hasn't opened the chat yet
            print("📥 [ConversationListViewModel] Fetching recent messages...")
            await fetchRecentMessages(for: snapshot.id)
            
            // Reload conversations to update UI
            print("🔄 [ConversationListViewModel] Reloading conversations to update UI...")
            loadConversations()
            
        } catch {
            print("❌ [ConversationListViewModel] Failed to handle conversation update: \(error)")
        }
    }
    
    private func fetchRecentMessages(for conversationId: String) async {
        do {
            print("📥 [ConversationListViewModel] Fetching recent messages for conversation: \(conversationId)")
            
            // Query Firestore for recent messages
            let db = Firestore.firestore()
            let snapshot = try await db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            print("📨 [ConversationListViewModel] Found \(snapshot.documents.count) messages")
            
            let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
            
            // Sync each message to local storage and trigger notifications
            for document in snapshot.documents {
                let data = document.data()
                if let messageSnapshot = try? parseMessage(from: data) {
                    let messageAge = Date().timeIntervalSince(messageSnapshot.timestamp)
                    print("   Message: \(messageSnapshot.text) (age: \(Int(messageAge))s)")
                    
                    // Sync to local storage
                    try? await MessageService.shared.syncMessageFromFirestore(messageSnapshot)
                    
                    // Trigger notification if message is from someone else and recent (last 10 seconds)
                    if messageSnapshot.senderId != currentUserId {
                        if messageAge < 10 {
                            print("🔔 [ConversationListViewModel] Message is recent (\(Int(messageAge))s old), triggering notification")
                            await showNotificationForMessage(messageSnapshot, conversationId: conversationId)
                        } else {
                            print("ℹ️ [ConversationListViewModel] Message is old (\(Int(messageAge))s), skipping notification")
                        }
                    }
                }
            }
            
        } catch {
            print("⚠️ [ConversationListViewModel] Error fetching recent messages: \(error)")
        }
    }
    
        private func showNotificationForMessage(_ snapshot: MessageSnapshot, conversationId: String) async {
            print("🔔 [ConversationListViewModel] Preparing notification for message: \(snapshot.text)")
            print("   From: \(snapshot.senderId)")
            print("   Conversation: \(conversationId)")
            
            // Get sender name
            let senderName: String
            do {
                let sender = try await userService.fetchUser(byId: snapshot.senderId)
                senderName = sender.displayName
                print("   Sender name: \(senderName)")
            } catch {
                senderName = "Someone"
                print("   ⚠️ Could not fetch sender name, using 'Someone'")
            }
            
            // Check if it's a group conversation
            let isGroup = await MainActor.run {
                (try? localStorage.fetchConversation(byId: conversationId))?.isGroup ?? false
            }
            print("   Is group: \(isGroup)")
            
            // Show system notification
            await MainActor.run {
                print("🔔 [ConversationListViewModel] Calling NotificationService.showMessageNotification...")
                NotificationService.shared.showMessageNotification(
                    conversationId: conversationId,
                    senderName: senderName,
                    messageText: snapshot.text ?? "Image",
                    isGroup: isGroup
                )
                
                // ✨ NEW: Show in-app notification (always)
                let inAppNotification = InAppNotification(
                    conversationId: conversationId,
                    senderName: senderName,
                    messageText: snapshot.text ?? "Image",
                    isGroup: isGroup
                )
                InAppNotificationManager.shared.show(inAppNotification)
                print("🔔 [ConversationListViewModel] In-app notification triggered for: \(senderName)")
            }
            
            // ✨ NEW: Increment unread count if user not viewing this conversation
            let isViewingThisConversation = await MainActor.run {
                NotificationService.shared.currentConversationId == conversationId
            }
            
            print("📊 [ConversationListViewModel] Unread count check:")
            print("   Current conversation: \(await MainActor.run { NotificationService.shared.currentConversationId ?? "nil" })")
            print("   Message conversation: \(conversationId)")
            print("   Is viewing: \(isViewingThisConversation)")
            
            if !isViewingThisConversation {
                print("📊 [ConversationListViewModel] User NOT viewing this conversation - incrementing unread count")
                await MainActor.run {
                    do {
                        try localStorage.incrementUnreadCount(conversationId: conversationId)
                        print("✅ [ConversationListViewModel] Unread count incremented for: \(conversationId)")
                    } catch {
                        print("❌ [ConversationListViewModel] Failed to increment unread count: \(error)")
                    }
                }
            } else {
                print("ℹ️ [ConversationListViewModel] User IS viewing conversation - skipping unread count increment")
            }
        }
    
    private func parseMessage(from data: [String: Any]) throws -> MessageSnapshot {
        return MessageSnapshot(
            id: data["id"] as? String ?? "",
            conversationId: data["conversationId"] as? String ?? "",
            senderId: data["senderId"] as? String ?? "",
            text: data["text"] as? String,
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            status: data["status"] as? String ?? "delivered",
            readBy: data["readBy"] as? [String] ?? [],
            imageUrl: data["imageUrl"] as? String,
            imageWidth: data["imageWidth"] as? Double,
            imageHeight: data["imageHeight"] as? Double
        )
    }
}

