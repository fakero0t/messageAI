# PR-16: Group Chat - Data Models & Creation

## Overview
Extend data models and services to support group conversations with 3+ participants. Implement group creation UI and backend logic.

## Dependencies
- PR-4: SwiftData Models & Local Persistence
- PR-8: Real-Time Message Receiving

## Tasks

### 1. Update Data Models for Groups
- [ ] Verify `ConversationEntity` supports groups
  - [ ] `isGroup` flag already exists
  - [ ] `participantIds` array supports 3+
  - [ ] Add group name field
  - [ ] Add creator ID field

### 2. Update Firestore Schema for Groups
- [ ] Extend conversations collection
  - [ ] `isGroup: boolean`
  - [ ] `groupName: string` (optional)
  - [ ] `createdBy: string` (creator user ID)
  - [ ] `createdAt: timestamp`
  - [ ] `participants: array<string>` (3+ user IDs)

### 3. Create Group Creation Service
- [ ] Update `Services/ConversationService.swift`
  - [ ] Method to create group conversation
  - [ ] Add initial participants
  - [ ] Store group metadata
  - [ ] Generate group ID

### 4. Implement Group Management Service
- [ ] Create `Services/GroupService.swift`
  - [ ] Add participant to group
  - [ ] Remove participant from group
  - [ ] Check if user is creator
  - [ ] Update group name
  - [ ] Fetch group details

### 5. Create Group Creation UI
- [ ] Create `Views/Group/CreateGroupView.swift`
  - [ ] Group name input
  - [ ] Participant selection (user IDs for now)
  - [ ] Create button
  - [ ] Navigate to group chat on creation

### 6. Create Participant Selector
- [ ] Create `Views/Group/ParticipantSelectorView.swift`
  - [ ] List of user IDs to add
  - [ ] Simple text input for MVP
  - [ ] Show selected participants
  - [ ] Remove participant option

### 7. Update New Chat View
- [ ] Modify `NewChatView.swift`
  - [ ] Option to create one-on-one or group
  - [ ] Button to open group creation
  - [ ] Navigation to CreateGroupView

### 8. Handle Group Conversation ID
- [ ] Generate unique group ID
  - [ ] Use UUID instead of sorted user IDs
  - [ ] Store in Firestore and SwiftData

### 9. Update Conversation List for Groups
- [ ] Modify `ConversationListView.swift`
  - [ ] Show group name (or participant names)
  - [ ] Show group icon/avatar
  - [ ] Indicate group vs one-on-one

## Files to Create/Modify

### New Files
- `swift_demo/Services/GroupService.swift`
- `swift_demo/Views/Group/CreateGroupView.swift`
- `swift_demo/Views/Group/ParticipantSelectorView.swift`

### Modified Files
- `swift_demo/Models/SwiftData/ConversationEntity.swift` - Add group fields
- `swift_demo/Services/ConversationService.swift` - Group methods
- `swift_demo/Views/Conversations/NewChatView.swift` - Group option
- `swift_demo/Views/Conversations/ConversationListView.swift` - Group display

## Code Structure Examples

### ConversationEntity.swift (Updated)
```swift
import Foundation
import SwiftData

@Model
final class ConversationEntity {
    @Attribute(.unique) var id: String
    var participantIds: [String]
    var isGroup: Bool
    var groupName: String?
    var createdBy: String?
    var lastMessageText: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]
    
    init(id: String, participantIds: [String], isGroup: Bool = false, groupName: String? = nil, createdBy: String? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.isGroup = isGroup
        self.groupName = groupName
        self.createdBy = createdBy
        self.unreadCount = 0
        self.messages = []
    }
}
```

### GroupService.swift
```swift
import Foundation
import FirebaseFirestore

class GroupService {
    static let shared = GroupService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    func createGroup(
        name: String?,
        participantIds: [String],
        creatorId: String
    ) async throws -> String {
        guard participantIds.count >= 2 else {
            throw NSError(domain: "GroupService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Group must have at least 3 participants (including creator)"
            ])
        }
        
        // Ensure creator is in participants
        var allParticipants = participantIds
        if !allParticipants.contains(creatorId) {
            allParticipants.append(creatorId)
        }
        
        // Generate unique group ID
        let groupId = UUID().uuidString
        
        // Create in Firestore
        let groupData: [String: Any] = [
            "id": groupId,
            "participants": allParticipants,
            "isGroup": true,
            "groupName": name ?? "",
            "createdBy": creatorId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("conversations").document(groupId).setData(groupData)
        
        // Create in local storage
        try await MainActor.run {
            let conversation = ConversationEntity(
                id: groupId,
                participantIds: allParticipants,
                isGroup: true,
                groupName: name,
                createdBy: creatorId
            )
            try localStorage.saveConversation(conversation)
        }
        
        return groupId
    }
    
    func addParticipant(groupId: String, userId: String, requesterId: String) async throws {
        // Verify requester is creator
        let snapshot = try await db.collection("conversations").document(groupId).getDocument()
        guard let data = snapshot.data(),
              let createdBy = data["createdBy"] as? String,
              createdBy == requesterId else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Only group creator can add participants"
            ])
        }
        
        // Add to Firestore
        try await db.collection("conversations").document(groupId).updateData([
            "participants": FieldValue.arrayUnion([userId])
        ])
        
        // Update local storage
        try await MainActor.run {
            if let conversation = try? localStorage.fetchConversation(id: groupId) {
                if !conversation.participantIds.contains(userId) {
                    conversation.participantIds.append(userId)
                    try localStorage.saveConversation(conversation)
                }
            }
        }
    }
    
    func removeParticipant(groupId: String, userId: String, requesterId: String) async throws {
        // Verify requester is creator
        let snapshot = try await db.collection("conversations").document(groupId).getDocument()
        guard let data = snapshot.data(),
              let createdBy = data["createdBy"] as? String,
              createdBy == requesterId else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Only group creator can remove participants"
            ])
        }
        
        // Remove from Firestore
        try await db.collection("conversations").document(groupId).updateData([
            "participants": FieldValue.arrayRemove([userId])
        ])
        
        // Update local storage
        try await MainActor.run {
            if let conversation = try? localStorage.fetchConversation(id: groupId) {
                conversation.participantIds.removeAll { $0 == userId }
                try localStorage.saveConversation(conversation)
            }
        }
    }
    
    func isCreator(groupId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection("conversations").document(groupId).getDocument()
        guard let data = snapshot.data(),
              let createdBy = data["createdBy"] as? String else {
            return false
        }
        return createdBy == userId
    }
}
```

### CreateGroupView.swift
```swift
import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var participantIds: [String] = []
    @State private var newParticipantId = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("Enter group name (optional)", text: $groupName)
                }
                
                Section("Participants") {
                    TextField("Enter User ID", text: $newParticipantId)
                    
                    Button("Add Participant") {
                        addParticipant()
                    }
                    .disabled(newParticipantId.isEmpty)
                    
                    ForEach(participantIds, id: \.self) { participantId in
                        HStack {
                            Text(participantId)
                            Spacer()
                            Button {
                                removeParticipant(participantId)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(participantIds.count < 2 || isCreating)
                }
            }
        }
    }
    
    private func addParticipant() {
        let trimmed = newParticipantId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !participantIds.contains(trimmed) else { return }
        
        participantIds.append(trimmed)
        newParticipantId = ""
    }
    
    private func removeParticipant(_ id: String) {
        participantIds.removeAll { $0 == id }
    }
    
    private func createGroup() {
        guard participantIds.count >= 2 else {
            errorMessage = "Group must have at least 2 other participants (3 total including you)"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                
                let groupId = try await GroupService.shared.createGroup(
                    name: groupName.isEmpty ? nil : groupName,
                    participantIds: participantIds,
                    creatorId: currentUserId
                )
                
                print("✅ Group created: \(groupId)")
                
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create group: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}
```

### NewChatView.swift (Updated)
```swift
import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userId = ""
    @State private var errorMessage: String?
    @State private var showCreateGroup = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("One-on-One Chat") {
                    TextField("Enter User ID", text: $userId)
                    
                    Button("Start Chat") {
                        startChat()
                    }
                    .disabled(userId.isEmpty)
                }
                
                Section("Group Chat") {
                    Button {
                        showCreateGroup = true
                    } label: {
                        Label("Create Group", systemImage: "person.3")
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView()
            }
        }
    }
    
    private func startChat() {
        // Existing one-on-one chat logic
        Task {
            do {
                let user = try await UserService.shared.fetchUser(byId: userId)
                // Navigate to chat
                dismiss()
            } catch {
                errorMessage = "User not found"
            }
        }
    }
}
```

### LocalStorageService.swift (Add Methods)
```swift
@MainActor
class LocalStorageService {
    // ... existing methods ...
    
    func fetchConversation(id: String) throws -> ConversationEntity? {
        let predicate = #Predicate<ConversationEntity> { $0.id == id }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}
```

## Acceptance Criteria
- [ ] Can create group with 3+ participants
- [ ] Group stored in Firestore with proper schema
- [ ] Group stored in local SwiftData
- [ ] Group name optional but stored if provided
- [ ] Creator ID tracked
- [ ] Only creator can add/remove participants
- [ ] Group appears in conversation list
- [ ] Group distinguished from one-on-one chats
- [ ] Group creation UI functional
- [ ] Participant management works

## Testing
1. Open app and tap new chat
2. Select "Create Group"
3. Enter group name
4. Add 2+ user IDs
5. Tap Create
6. Verify group appears in conversation list
7. Open group
8. Verify can send messages (will test in PR-17)
9. Verify Firestore has group conversation
10. Test adding participant (as creator)
11. Test removing participant (as creator)
12. Test non-creator trying to add participant (should fail)

## Notes
- Groups use UUID for ID (not sorted user IDs)
- Minimum 3 participants (creator + 2 others)
- Creator-only management for MVP
- Group name optional but recommended
- UI simplified for testing (user ID input)
- Full participant selector with user search in future
- Group metadata extensible for future features

## Next PR
PR-17: Group Chat - Messaging & UI (depends on this PR)

