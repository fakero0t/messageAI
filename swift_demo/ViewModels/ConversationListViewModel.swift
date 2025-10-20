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
    
    init() {
        loadConversations()
        startListening()
    }
    
    func loadConversations() {
        isLoading = true
        
        Task {
            do {
                // Load from local storage
                let localConversations = try localStorage.fetchAllConversations()
                
                print("📂 Loaded \(localConversations.count) conversations from local storage")
                
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
                
                conversations = conversationsWithDetails
                isLoading = false
                
                print("✅ Loaded \(conversations.count) conversations with details")
                
            } catch {
                print("❌ Failed to load conversations: \(error)")
                errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadConversationDetails(_ conversation: ConversationEntity) async throws -> ConversationWithDetails {
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        
        // Get other participants (exclude current user)
        let otherParticipants = conversation.participantIds.filter { $0 != currentUserId }
        
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
                    displayName: "Unknown User"
                )
                participantUsers.append(placeholderUser)
            }
        }
        
        return ConversationWithDetails(
            conversation: conversation,
            participants: participantUsers
        )
    }
    
    private func startListening() {
        // Listen to all conversations for current user
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        
        conversationService.listenToUserConversations(userId: currentUserId) { [weak self] snapshot in
            print("📬 Conversation update received: \(snapshot.id)")
            Task {
                await self?.handleConversationUpdate(snapshot)
            }
        }
    }
    
    private func handleConversationUpdate(_ snapshot: ConversationSnapshot) async {
        do {
            // Sync to local storage
            try await conversationService.syncConversationFromFirestore(snapshot)
            
            // Fetch recent messages for this conversation
            // This ensures group messages appear even if user hasn't opened the chat yet
            await fetchRecentMessages(for: snapshot.id)
            
            // Reload conversations
            loadConversations()
            
        } catch {
            print("❌ Failed to handle conversation update: \(error)")
        }
    }
    
    private func fetchRecentMessages(for conversationId: String) async {
        do {
            print("📥 Fetching recent messages for conversation: \(conversationId)")
            
            // Query Firestore for recent messages
            let db = Firestore.firestore()
            let snapshot = try await db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            print("📨 Found \(snapshot.documents.count) messages")
            
            let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
            
            // Sync each message to local storage and trigger notifications
            for document in snapshot.documents {
                let data = document.data()
                if let messageSnapshot = try? parseMessage(from: data) {
                    // Sync to local storage
                    try? await MessageService.shared.syncMessageFromFirestore(messageSnapshot)
                    
                    // Trigger notification if message is from someone else and recent (last 10 seconds)
                    if messageSnapshot.senderId != currentUserId,
                       Date().timeIntervalSince(messageSnapshot.timestamp) < 10 {
                        await showNotificationForMessage(messageSnapshot, conversationId: conversationId)
                    }
                }
            }
            
        } catch {
            print("⚠️ Error fetching recent messages: \(error)")
        }
    }
    
    private func showNotificationForMessage(_ snapshot: MessageSnapshot, conversationId: String) async {
        // Get sender name
        let senderName: String
        do {
            let sender = try await userService.fetchUser(byId: snapshot.senderId)
            senderName = sender.displayName
        } catch {
            senderName = "Someone"
        }
        
        // Check if it's a group conversation
        let isGroup = try? await MainActor.run {
            try? localStorage.fetchConversation(byId: conversationId)?.isGroup ?? false
        } ?? false
        
        // Show notification
        await MainActor.run {
            NotificationService.shared.showMessageNotification(
                conversationId: conversationId,
                senderName: senderName,
                messageText: snapshot.text,
                isGroup: isGroup
            )
        }
    }
    
    private func parseMessage(from data: [String: Any]) throws -> MessageSnapshot {
        return MessageSnapshot(
            id: data["id"] as? String ?? "",
            conversationId: data["conversationId"] as? String ?? "",
            senderId: data["senderId"] as? String ?? "",
            text: data["text"] as? String ?? "",
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            status: data["status"] as? String ?? "delivered",
            readBy: data["readBy"] as? [String] ?? []
        )
    }
}

