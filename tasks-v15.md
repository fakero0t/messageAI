# PR-15: Conversation List with Unread Badges

## Overview
Complete the conversation list view with real conversations, unread message badges, last message preview, and proper sorting by recent activity.

## Dependencies
- PR-8: Real-Time Message Receiving
- PR-14: Timestamps & Formatting

## Tasks

### 1. Create Conversation List ViewModel
- [ ] Create `ViewModels/ConversationListViewModel.swift`
  - [ ] ObservableObject with @Published conversations
  - [ ] Load conversations from local storage
  - [ ] Listen to conversation updates
  - [ ] Fetch user details for participants
  - [ ] Sort by last message time

### 2. Implement Conversation Loading
- [ ] Load all conversations for current user
  - [ ] Query conversations where user is participant
  - [ ] Fetch from local SwiftData
  - [ ] Subscribe to Firestore updates
  - [ ] Handle real-time conversation additions

### 3. Fetch Participant Details
- [ ] For each conversation, fetch participant info
  - [ ] Get display names
  - [ ] Get online status
  - [ ] Cache user details
  - [ ] Handle missing users

### 4. Implement Unread Count Logic
- [ ] Calculate unread count per conversation
  - [ ] Count messages where senderId != currentUserId
  - [ ] Count messages where currentUserId not in readBy
  - [ ] Update count in real-time
  - [ ] Reset count when conversation opened

### 5. Update Conversation on New Message
- [ ] Listen to new messages
  - [ ] Update lastMessageText
  - [ ] Update lastMessageTime
  - [ ] Increment unread count (if not sender)
  - [ ] Re-sort conversation list

### 6. Implement Conversation List UI
- [ ] Complete `ConversationListView.swift`
  - [ ] List of conversations
  - [ ] Show participant name(s)
  - [ ] Show last message preview
  - [ ] Show timestamp
  - [ ] Show unread badge
  - [ ] Empty state ("No conversations")
  - [ ] Pull to refresh

### 7. Add Conversation Row Component
- [ ] Create `Views/Conversations/ConversationRowView.swift`
  - [ ] Avatar (initial letter)
  - [ ] Participant name
  - [ ] Last message text (truncated)
  - [ ] Timestamp
  - [ ] Unread badge
  - [ ] Online status indicator (optional)

### 8. Implement Sorting
- [ ] Sort conversations by lastMessageTime (most recent first)
  - [ ] Update sort when new message arrives
  - [ ] Maintain sort in real-time

### 9. Handle Conversation Creation
- [ ] Update `NewChatView.swift`
  - [ ] Create conversation when starting new chat
  - [ ] Add to conversation list
  - [ ] Navigate to chat view

### 10. Add Swipe Actions (Optional)
- [ ] Swipe to delete conversation (local only)
- [ ] Swipe to mark as read/unread
- [ ] Archive conversation

## Files to Create/Modify

### New Files
- `swift_demo/ViewModels/ConversationListViewModel.swift`
- `swift_demo/Views/Conversations/ConversationRowView.swift`

### Modified Files
- `swift_demo/Views/Conversations/ConversationListView.swift` - Complete implementation
- `swift_demo/Views/Conversations/NewChatView.swift` - Create conversation
- `swift_demo/Services/ConversationService.swift` - Add listener methods
- `swift_demo/Services/LocalStorageService.swift` - Conversation queries

## Code Structure Examples

### ConversationListViewModel.swift
```swift
import Foundation
import Combine

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ConversationWithDetails] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let localStorage = LocalStorageService.shared
    private let conversationService = ConversationService.shared
    private let userService = UserService.shared
    private let listenerService = FirestoreListenerService.shared
    
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
                
            } catch {
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
            if let user = try? await userService.fetchUser(byId: participantId) {
                participantUsers.append(user)
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
        
        conversationService.listenToUserConversations(userId: currentUserId) { [weak self] _ in
            self?.loadConversations()
        }
    }
}

struct ConversationWithDetails: Identifiable {
    let conversation: ConversationEntity
    let participants: [User]
    
    var id: String { conversation.id }
    
    var displayName: String {
        if conversation.isGroup {
            // Group name or participant names
            return participants.map { $0.displayName }.joined(separator: ", ")
        } else {
            // One-on-one: other participant's name
            return participants.first?.displayName ?? "Unknown"
        }
    }
    
    var displayAvatar: String {
        participants.first?.displayName.prefix(1).uppercased() ?? "?"
    }
}
```

### ConversationListView.swift (Complete)
```swift
import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showNewChat = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .refreshable {
                viewModel.loadConversations()
            }
        }
    }
    
    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conversationDetail in
                NavigationLink {
                    ChatView(
                        recipientId: getRecipientId(from: conversationDetail),
                        recipientName: conversationDetail.displayName
                    )
                } label: {
                    ConversationRowView(conversationDetail: conversationDetail)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Conversations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a new chat to begin messaging")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showNewChat = true
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private func getRecipientId(from detail: ConversationWithDetails) -> String {
        detail.participants.first?.id ?? ""
    }
}
```

### ConversationRowView.swift
```swift
import SwiftUI

struct ConversationRowView: View {
    let conversationDetail: ConversationWithDetails
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(conversationDetail.displayAvatar)
                        .foregroundColor(.white)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversationDetail.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessageTime = conversationDetail.conversation.lastMessageTime {
                        Text(lastMessageTime.conversationTimestamp())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    if let lastMessage = conversationDetail.conversation.lastMessageText {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Spacer()
                    
                    if conversationDetail.conversation.unreadCount > 0 {
                        Text("\(conversationDetail.conversation.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var avatarColor: Color {
        // Generate color based on conversation ID for consistency
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let index = abs(conversationDetail.id.hashValue) % colors.count
        return colors[index]
    }
}
```

### ConversationService.swift (Add Listener)
```swift
import Foundation
import FirebaseFirestore

class ConversationService {
    static let shared = ConversationService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    private var conversationListeners: [String: ListenerRegistration] = [:]
    
    // ... existing methods ...
    
    func listenToUserConversations(
        userId: String,
        onUpdate: @escaping (ConversationSnapshot) -> Void
    ) {
        let listener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to conversations: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                snapshot.documentChanges.forEach { change in
                    if change.type == .added || change.type == .modified {
                        do {
                            let data = change.document.data()
                            let conversationSnapshot = try self.parseConversation(from: data)
                            onUpdate(conversationSnapshot)
                        } catch {
                            print("Error parsing conversation: \(error)")
                        }
                    }
                }
            }
        
        conversationListeners[userId] = listener
    }
    
    func stopListeningToConversations(userId: String) {
        conversationListeners[userId]?.remove()
        conversationListeners.removeValue(forKey: userId)
    }
    
    private func parseConversation(from data: [String: Any]) throws -> ConversationSnapshot {
        // Parse Firestore conversation data
        ConversationSnapshot(
            id: data["id"] as? String ?? "",
            participantIds: data["participants"] as? [String] ?? [],
            isGroup: data["isGroup"] as? Bool ?? false,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageTime: (data["lastMessageTime"] as? Timestamp)?.dateValue()
        )
    }
}

struct ConversationSnapshot {
    let id: String
    let participantIds: [String]
    let isGroup: Bool
    let lastMessageText: String?
    let lastMessageTime: Date?
}
```

### LocalStorageService.swift (Add Methods)
```swift
@MainActor
class LocalStorageService {
    // ... existing methods ...
    
    func fetchAllConversations() throws -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            sortBy: [SortDescriptor(\.lastMessageTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchConversationsForUser(userId: String) throws -> [ConversationEntity] {
        let predicate = #Predicate<ConversationEntity> { conversation in
            conversation.participantIds.contains(userId)
        }
        
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastMessageTime, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
}
```

## Acceptance Criteria
- [ ] Conversation list shows all user's conversations
- [ ] Conversations sorted by most recent first
- [ ] Last message preview displayed
- [ ] Timestamp formatted appropriately
- [ ] Unread badge shows correct count
- [ ] Tapping conversation opens chat view
- [ ] New messages update conversation list
- [ ] Unread count updates in real-time
- [ ] Empty state shown when no conversations
- [ ] Pull to refresh works
- [ ] Participant names displayed correctly

## Testing
1. Log in and view conversation list
2. Verify any existing conversations appear
3. Start new chat
4. Verify new conversation added to list
5. Send message in conversation
6. Verify last message preview updates
7. Log in from second device
8. Send message to first device
9. Verify conversation list updates
10. Verify unread badge appears
11. Open conversation
12. Verify unread badge clears
13. Test with multiple conversations
14. Verify sorting by recent activity

## Notes
- Conversation list is primary navigation
- Keep UI responsive with local-first loading
- Firestore updates in background
- Unread badges critical for UX
- Avatar initials provide visual identity
- Consider caching user details
- Real-time updates essential
- Empty state encourages engagement

## Next PR
PR-16: Group Chat - Data Models & Creation (depends on PR-4, PR-8)

