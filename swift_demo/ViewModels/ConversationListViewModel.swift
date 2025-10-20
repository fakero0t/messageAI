//
//  ConversationListViewModel.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine

struct ConversationWithDetails: Identifiable {
    let conversation: ConversationEntity
    let participants: [User]
    
    var id: String { conversation.id }
    
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
        // For groups, return group ID; for one-on-one, return participant ID
        if conversation.isGroup {
            return conversation.id
        } else {
            return participants.first?.id ?? ""
        }
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
            
            // Reload conversations
            loadConversations()
            
        } catch {
            print("❌ Failed to handle conversation update: \(error)")
        }
    }
}

