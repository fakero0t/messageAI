# PR-3: Basic SwiftUI Structure & Navigation

## Overview
Create the app's navigation structure with conversation list and chat views. Set up proper navigation flow between screens.

## Dependencies
- PR-2: Authentication System

## Tasks

### 1. Create Main App Container
- [ ] Create `Views/MainView.swift`
  - [ ] TabView or NavigationStack for main navigation
  - [ ] Conversation list as primary view
  - [ ] Profile/settings tab (optional for MVP)
  - [ ] Logout button

### 2. Create Conversation List View
- [ ] Create `Views/Conversations/ConversationListView.swift`
  - [ ] NavigationStack wrapper
  - [ ] List of conversations (placeholder for now)
  - [ ] Navigation to chat view
  - [ ] "New Chat" button
  - [ ] Display user's display name in navigation title

### 3. Create New Chat View
- [ ] Create `Views/Conversations/NewChatView.swift`
  - [ ] TextField for entering user ID
  - [ ] Search/start chat button
  - [ ] Simple manual user ID entry for testing
  - [ ] Navigate to chat view when user found
  - [ ] Show error if user not found

### 4. Create Chat View
- [ ] Create `Views/Chat/ChatView.swift`
  - [ ] NavigationStack compatible
  - [ ] Display conversation partner name in nav title
  - [ ] Placeholder for messages list
  - [ ] Message input field at bottom
  - [ ] Send button
  - [ ] Keyboard handling basics

### 5. Create User Search Service (Basic)
- [ ] Create `Services/UserService.swift`
  - [ ] Method to fetch user by ID from Firestore
  - [ ] Method to get user display name
  - [ ] Handle user not found errors

### 6. Wire Up Navigation
- [ ] Update `swift_demoApp.swift`
  - [ ] Show MainView when authenticated
  - [ ] Show LoginView when not authenticated
- [ ] Implement navigation from ConversationListView → NewChatView
- [ ] Implement navigation from NewChatView → ChatView
- [ ] Implement navigation from ConversationListView → ChatView (when conversation exists)

### 7. Add Navigation Models
- [ ] Create navigation coordinator pattern or use NavigationPath
  - [ ] Handle deep linking structure
  - [ ] Maintain navigation state

## Files to Create/Modify

### New Files
- `swift_demo/Views/MainView.swift`
- `swift_demo/Views/Conversations/ConversationListView.swift`
- `swift_demo/Views/Conversations/NewChatView.swift`
- `swift_demo/Views/Chat/ChatView.swift`
- `swift_demo/Services/UserService.swift`

### Modified Files
- `swift_demo/swift_demoApp.swift` - Update to show MainView when authenticated
- `swift_demo/ContentView.swift` - Can repurpose or delete

## Code Structure Examples

### MainView.swift
```swift
import SwiftUI

struct MainView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}
```

### ConversationListView.swift
```swift
import SwiftUI

struct ConversationListView: View {
    @State private var showNewChat = false
    
    var body: some View {
        NavigationStack {
            List {
                // Placeholder conversations
                Text("No conversations yet")
                    .foregroundColor(.secondary)
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
        }
    }
}
```

### ChatView.swift
```swift
import SwiftUI

struct ChatView: View {
    let recipientName: String
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            // Messages list placeholder
            ScrollView {
                Text("Start chatting...")
                    .foregroundColor(.secondary)
            }
            
            // Message input
            HStack {
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func sendMessage() {
        // Placeholder
        messageText = ""
    }
}
```

### UserService.swift
```swift
import Foundation
import FirebaseFirestore

class UserService {
    static let shared = UserService()
    private let db = Firestore.firestore()
    
    func fetchUser(byId userId: String) async throws -> User {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data() else {
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return try Firestore.Decoder().decode(User.self, from: data)
    }
}
```

## Acceptance Criteria
- [ ] Main view displays after authentication
- [ ] Conversation list view accessible
- [ ] "New Chat" button opens new chat view
- [ ] User can enter user ID to start chat
- [ ] Chat view opens when user found
- [ ] Error shown if user not found
- [ ] Navigation works smoothly between all views
- [ ] Back navigation works correctly
- [ ] Message input field visible in chat view
- [ ] Keyboard shows/hides properly

## Testing
1. Log in to app
2. Verify main view appears with conversation list
3. Tap "New Chat" button
4. Enter valid user ID (create second test user first)
5. Verify chat view opens
6. Test back navigation
7. Test keyboard behavior in message input
8. Test entering invalid user ID (should show error)

## Notes
- Navigation structure should support deep linking later
- User ID entry is temporary for testing - will be replaced with proper user discovery
- Keep UI simple and clean following iOS design patterns
- Use SF Symbols for icons
- Chat view is placeholder - will be fully implemented in PR-6

## Next PR
PR-4: SwiftData Models & Local Persistence (parallel with PR-3)

