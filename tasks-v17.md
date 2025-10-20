# PR-17: Group Chat - Messaging & UI

## Overview
Implement group messaging functionality with proper UI for group conversations, including participant list, group-specific read receipts, and message delivery to all members.

## Dependencies
- PR-16: Group Chat - Data Models & Creation
- PR-9: Optimistic UI & Message Status

## Tasks

### 1. Extend Message Service for Groups
- [ ] Update `Services/MessageService.swift`
  - [ ] Support group conversation IDs
  - [ ] Send message to all group participants
  - [ ] Handle group message delivery

### 2. Update ChatViewModel for Groups
- [ ] Modify `ChatViewModel.swift`
  - [ ] Detect if conversation is group
  - [ ] Load group details
  - [ ] Handle multiple recipients
  - [ ] Show participant count

### 3. Create Group Chat Header
- [ ] Create `Views/Group/GroupChatHeaderView.swift`
  - [ ] Group name
  - [ ] Participant count ("3 members")
  - [ ] Tap to view participants
  - [ ] Group settings button

### 4. Create Participant List View
- [ ] Create `Views/Group/ParticipantListView.swift`
  - [ ] List all participants
  - [ ] Show online/offline status
  - [ ] Display names
  - [ ] Add participant button (creator only)
  - [ ] Remove participant button (creator only)

### 5. Update Message Display for Groups
- [ ] Modify `MessageBubbleView.swift`
  - [ ] Show sender name for received messages
  - [ ] Different layout for group vs one-on-one
  - [ ] Sender avatar/initial

### 6. Implement Group Read Receipts
- [ ] Update read receipt logic for groups
  - [ ] Track which participants have read
  - [ ] Show read count ("Read by 2/3")
  - [ ] Simple display for MVP

### 7. Handle Group Message Delivery
- [ ] Ensure messages delivered to all participants
  - [ ] Firestore real-time updates handle this
  - [ ] All participants listening to same conversation
  - [ ] Verify each participant receives message

### 8. Create Group Info View
- [ ] Create `Views/Group/GroupInfoView.swift`
  - [ ] Group name
  - [ ] Created by
  - [ ] Participant list
  - [ ] Leave group button
  - [ ] Edit group (creator only)

### 9. Update Navigation
- [ ] Update `ChatView.swift` for groups
  - [ ] Show group header instead of one-on-one
  - [ ] Navigation to group info
  - [ ] Handle group-specific actions

### 10. Add Group Management Actions
- [ ] Leave group (remove self from participants)
- [ ] Delete group (creator only, optional)
- [ ] Mute group notifications (optional)

## Files to Create/Modify

### New Files
- `swift_demo/Views/Group/GroupChatHeaderView.swift`
- `swift_demo/Views/Group/ParticipantListView.swift`
- `swift_demo/Views/Group/GroupInfoView.swift`

### Modified Files
- `swift_demo/Services/MessageService.swift` - Group support
- `swift_demo/ViewModels/ChatViewModel.swift` - Group logic
- `swift_demo/Views/Chat/ChatView.swift` - Group UI
- `swift_demo/Views/Chat/MessageBubbleView.swift` - Sender names

## Code Structure Examples

### ChatViewModel.swift (Updated for Groups)
```swift
import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageEntity] = []
    @Published var recipientOnline = false
    @Published var recipientLastSeen: Date?
    @Published var errorMessage: String?
    @Published var isSending = false
    @Published var isOffline = false
    
    // Group-specific
    @Published var isGroup = false
    @Published var groupName: String?
    @Published var participants: [User] = []
    
    let conversationId: String
    let currentUserId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    private let listenerService = FirestoreListenerService.shared
    private let queueService = MessageQueueService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let readReceiptService = ReadReceiptService.shared
    private let userService = UserService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // One-on-one init
    init(recipientId: String) {
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = ConversationService.shared.generateConversationId(
            userId1: currentUserId,
            userId2: recipientId
        )
        self.isGroup = false
        
        loadLocalMessages()
        startListening()
        observeNetwork()
        markMessagesAsRead()
    }
    
    // Group init
    init(groupId: String) {
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = groupId
        self.isGroup = true
        
        loadGroupDetails()
        loadLocalMessages()
        startListening()
        observeNetwork()
        markMessagesAsRead()
    }
    
    private func loadGroupDetails() {
        Task {
            do {
                if let conversation = try localStorage.fetchConversation(id: conversationId) {
                    groupName = conversation.groupName
                    
                    // Load participant details
                    for participantId in conversation.participantIds {
                        if let user = try? await userService.fetchUser(byId: participantId) {
                            participants.append(user)
                        }
                    }
                }
            } catch {
                print("Error loading group details: \(error)")
            }
        }
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty else { return }
        
        let messageId = UUID().uuidString
        let initialStatus: MessageStatus = networkMonitor.isConnected ? .pending : .queued
        
        let optimisticMessage = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: initialStatus
        )
        
        messages.append(optimisticMessage)
        
        if networkMonitor.isConnected {
            sendOnline(messageId: messageId, text: text)
        } else {
            sendOffline(messageId: messageId, text: text)
        }
    }
    
    private func sendOnline(messageId: String, text: String) {
        Task {
            do {
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .pending
                )
                try localStorage.saveMessage(message)
                updateMessageStatus(messageId: messageId, status: .sent)
                
                // Get all participant IDs for group
                let recipientIds = isGroup ? 
                    participants.map { $0.id }.filter { $0 != currentUserId } :
                    [conversationId.split(separator: "_").map(String.init).first { $0 != currentUserId } ?? ""]
                
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientIds: recipientIds
                )
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .queued)
                try? queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text,
                    recipientId: "" // Not used for groups
                )
            }
        }
    }
    
    // ... other methods ...
}
```

### MessageService.swift (Updated)
```swift
import Foundation
import FirebaseFirestore

class MessageService {
    static let shared = MessageService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    private let retryService = FirestoreRetryService.shared
    
    func sendToFirestore(
        messageId: String,
        text: String,
        conversationId: String,
        senderId: String,
        recipientIds: [String]
    ) async throws {
        try await retryService.executeWithRetry(policy: .default) {
            let messageData: [String: Any] = [
                "id": messageId,
                "conversationId": conversationId,
                "senderId": senderId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "delivered",
                "readBy": [senderId]
            ]
            
            try await self.db.collection("messages").document(messageId).setData(messageData)
            
            // Update conversation
            try await ConversationService.shared.updateConversation(
                conversationId: conversationId,
                lastMessage: text,
                participants: [senderId] + recipientIds
            )
        }
    }
}
```

### ChatView.swift (Updated for Groups)
```swift
import SwiftUI

struct ChatView: View {
    let conversationId: String?
    let recipientId: String?
    let recipientName: String?
    let isGroup: Bool
    
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var showGroupInfo = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    
    // One-on-one init
    init(recipientId: String, recipientName: String) {
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.conversationId = nil
        self.isGroup = false
        _viewModel = StateObject(wrappedValue: ChatViewModel(recipientId: recipientId))
    }
    
    // Group init
    init(groupId: String) {
        self.conversationId = groupId
        self.recipientId = nil
        self.recipientName = nil
        self.isGroup = true
        _viewModel = StateObject(wrappedValue: ChatViewModel(groupId: groupId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                messages: viewModel.messages,
                currentUserId: viewModel.currentUserId,
                isGroup: isGroup,
                participants: viewModel.participants
            )
            
            MessageInputView(text: $messageText) {
                sendMessage()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if isGroup {
                    Button {
                        showGroupInfo = true
                    } label: {
                        VStack(spacing: 2) {
                            Text(viewModel.groupName ?? "Group Chat")
                                .font(.headline)
                            Text("\(viewModel.participants.count) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 2) {
                        Text(recipientName ?? "Chat")
                            .font(.headline)
                        OnlineStatusView(
                            isOnline: viewModel.recipientOnline,
                            lastSeen: viewModel.recipientLastSeen
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            if let conversationId = conversationId {
                GroupInfoView(groupId: conversationId)
            }
        }
        .onAppear {
            viewModel.markMessagesAsRead()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.markMessagesAsRead()
            }
        }
    }
    
    private var navigationTitle: String {
        if isGroup {
            return viewModel.groupName ?? "Group Chat"
        } else {
            return recipientName ?? "Chat"
        }
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
}
```

### MessageBubbleView.swift (Updated for Groups)
```swift
import SwiftUI

struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    let isGroup: Bool
    let senderName: String?
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name for group messages
                if isGroup && !isFromCurrentUser, let senderName = senderName {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                Text(message.text)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp.chatTimestamp())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        statusIndicator
                    }
                }
                
                if message.status == .failed && isFromCurrentUser {
                    FailedMessageActionsView(onRetry: onRetry, onDelete: onDelete)
                }
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    // ... rest of implementation ...
}
```

### GroupInfoView.swift
```swift
import SwiftUI

struct GroupInfoView: View {
    let groupId: String
    @Environment(\.dismiss) private var dismiss
    @State private var conversation: ConversationEntity?
    @State private var participants: [User] = []
    @State private var isCreator = false
    @State private var showAddParticipant = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Group Details") {
                    if let conversation = conversation {
                        LabeledContent("Name", value: conversation.groupName ?? "Unnamed Group")
                        LabeledContent("Members", value: "\(conversation.participantIds.count)")
                    }
                }
                
                Section("Participants") {
                    ForEach(participants) { participant in
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Text(participant.displayName.prefix(1).uppercased())
                                        .foregroundColor(.white)
                                }
                            
                            VStack(alignment: .leading) {
                                Text(participant.displayName)
                                    .font(.headline)
                                
                                OnlineStatusView(
                                    isOnline: participant.online,
                                    lastSeen: participant.lastSeen
                                )
                            }
                            
                            Spacer()
                            
                            if isCreator && participant.id != conversation?.createdBy {
                                Button(role: .destructive) {
                                    removeParticipant(participant.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    if isCreator {
                        Button {
                            showAddParticipant = true
                        } label: {
                            Label("Add Participant", systemImage: "person.badge.plus")
                        }
                    }
                }
                
                Section {
                    Button("Leave Group", role: .destructive) {
                        leaveGroup()
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadGroupInfo()
            }
        }
    }
    
    private func loadGroupInfo() {
        Task {
            do {
                conversation = try LocalStorageService.shared.fetchConversation(id: groupId)
                
                if let conversation = conversation {
                    for participantId in conversation.participantIds {
                        if let user = try? await UserService.shared.fetchUser(byId: participantId) {
                            participants.append(user)
                        }
                    }
                    
                    let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                    isCreator = try await GroupService.shared.isCreator(groupId: groupId, userId: currentUserId)
                }
            } catch {
                print("Error loading group info: \(error)")
            }
        }
    }
    
    private func removeParticipant(_ userId: String) {
        Task {
            do {
                let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                try await GroupService.shared.removeParticipant(
                    groupId: groupId,
                    userId: userId,
                    requesterId: currentUserId
                )
                loadGroupInfo()
            } catch {
                print("Error removing participant: \(error)")
            }
        }
    }
    
    private func leaveGroup() {
        Task {
            do {
                let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                try await GroupService.shared.removeParticipant(
                    groupId: groupId,
                    userId: currentUserId,
                    requesterId: currentUserId
                )
                dismiss()
            } catch {
                print("Error leaving group: \(error)")
            }
        }
    }
}
```

## Acceptance Criteria
- [ ] Can send messages in group chats
- [ ] All participants receive messages
- [ ] Sender name shown for group messages
- [ ] Group header shows participant count
- [ ] Can view participant list
- [ ] Creator can add/remove participants
- [ ] All members can leave group
- [ ] Read receipts work in groups
- [ ] Group info view functional
- [ ] Navigation works properly

## Testing
1. Create group with 3 users
2. Send message from User A
3. Verify appears for Users B and C
4. Verify sender name shows
5. Send messages from each user
6. Verify all receive all messages
7. Tap group header
8. Verify participant list appears
9. As creator, add participant
10. Verify new participant receives future messages
11. As creator, remove participant
12. Verify removed participant no longer receives messages
13. As non-creator, verify cannot add/remove
14. Test leave group

## Notes
- Group messages delivered via Firestore real-time listeners
- All participants listen to same conversation ID
- Sender name critical for group context
- Creator-only management keeps permissions simple
- Read receipts simplified for MVP (count vs individual)
- Consider message grouping by sender for UX
- Group chat more complex than one-on-one - test thoroughly

## Next PR
PR-18: Foreground Push Notifications (depends on PR-8)

