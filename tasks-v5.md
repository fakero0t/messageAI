# PR-5: User Profile & Online Status

## Overview
Implement user profile management and online/offline status tracking using Firebase Firestore presence system.

## Dependencies
- PR-2: Authentication System

## Tasks

### 1. Update User Model
- [ ] Extend `Models/User.swift`
  - [ ] Add `online: Bool` property
  - [ ] Add `lastSeen: Date?` property
  - [ ] Add helper methods for status display

### 2. Create Presence Service
- [ ] Create `Services/PresenceService.swift`
  - [ ] Track user online status
  - [ ] Update Firestore when app becomes active
  - [ ] Update Firestore when app goes to background
  - [ ] Listen to app lifecycle events
  - [ ] Set online = true when active
  - [ ] Set online = false with lastSeen timestamp when inactive

### 3. Implement Online Status Updates
- [ ] Update user document in Firestore on app state changes
  - [ ] App launch → set online = true
  - [ ] App background → set online = false, update lastSeen
  - [ ] App terminate → set online = false (via Firebase onDisconnect if possible)

### 4. Create Status Display Components
- [ ] Create `Views/Components/OnlineStatusView.swift`
  - [ ] Show green dot for online
  - [ ] Show gray dot for offline
  - [ ] Show "last seen" text for offline users
  - [ ] Real-time updates

### 5. Update User Service
- [ ] Extend `Services/UserService.swift`
  - [ ] Method to fetch user with online status
  - [ ] Method to listen to user status changes (real-time)
  - [ ] Method to get multiple users' statuses

### 6. Create Profile View
- [ ] Create `Views/Profile/ProfileView.swift`
  - [ ] Display current user info
  - [ ] Display name
  - [ ] Email
  - [ ] User ID (for testing)
  - [ ] Online status
  - [ ] Logout button

### 7. Integrate Status into Chat Views
- [ ] Update `ChatView.swift` to show recipient online status
- [ ] Update conversation list to show user statuses (future)

### 8. Handle App Lifecycle
- [ ] Create lifecycle observer
  - [ ] Listen to UIApplication state changes
  - [ ] Update presence accordingly
  - [ ] Handle proper cleanup

## Files to Create/Modify

### New Files
- `swift_demo/Services/PresenceService.swift`
- `swift_demo/Views/Components/OnlineStatusView.swift`
- `swift_demo/Views/Profile/ProfileView.swift`

### Modified Files
- `swift_demo/Models/User.swift` - Add online status properties
- `swift_demo/Services/UserService.swift` - Add status methods
- `swift_demo/Views/Chat/ChatView.swift` - Show recipient status
- `swift_demo/swift_demoApp.swift` - Initialize presence service

## Code Structure Examples

### User.swift (Updated)
```swift
import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    
    var statusText: String {
        if online {
            return "Online"
        } else if let lastSeen = lastSeen {
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
}

extension Date {
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
```

### PresenceService.swift
```swift
import Foundation
import FirebaseFirestore
import UIKit
import Combine

class PresenceService: ObservableObject {
    static let shared = PresenceService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    func startTracking(for userId: String) {
        setUserOnline(userId: userId)
        setupLifecycleObservers(userId: userId)
    }
    
    func stopTracking(for userId: String) {
        setUserOffline(userId: userId)
    }
    
    private func setUserOnline(userId: String) {
        db.collection("users").document(userId).updateData([
            "online": true,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }
    
    private func setUserOffline(userId: String) {
        db.collection("users").document(userId).updateData([
            "online": false,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }
    
    private func setupLifecycleObservers(userId: String) {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.setUserOnline(userId: userId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.setUserOffline(userId: userId)
            }
            .store(in: &cancellables)
    }
}
```

### OnlineStatusView.swift
```swift
import SwiftUI

struct OnlineStatusView: View {
    let isOnline: Bool
    let lastSeen: Date?
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOnline ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusText: String {
        if isOnline {
            return "Online"
        } else if let lastSeen = lastSeen {
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
}
```

### ProfileView.swift
```swift
import SwiftUI

struct ProfileView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authService.currentUser {
                        LabeledContent("Display Name", value: user.displayName)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("User ID", value: user.id)
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            OnlineStatusView(isOnline: user.online, lastSeen: user.lastSeen)
                        }
                    }
                }
                
                Section {
                    Button("Logout", role: .destructive) {
                        logout()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
    
    func logout() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
```

## Acceptance Criteria
- [ ] User online status updates in Firestore when app state changes
- [ ] User set to online when app opens
- [ ] User set to offline when app backgrounds
- [ ] Last seen timestamp updated correctly
- [ ] Online status displays in profile view
- [ ] Online status displays in chat view
- [ ] Status updates in real-time
- [ ] Green dot shows for online users
- [ ] Gray dot shows for offline users
- [ ] "Last seen" text shows for offline users
- [ ] Presence tracking starts on login
- [ ] Presence tracking stops on logout

## Testing
1. Log in to app
2. Check Firestore → users/{userId} → verify online = true
3. Background the app
4. Check Firestore → verify online = false, lastSeen updated
5. Bring app to foreground
6. Verify online = true again
7. Open profile view → verify status displays correctly
8. Log in from second device with different user
9. Open chat with that user
10. Verify online status shows in chat
11. Background second device
12. Verify status updates to offline in first device

## Notes
- Firebase doesn't have true presence API for mobile (unlike Realtime Database)
- We're using app lifecycle events as proxy for presence
- Not perfect (app crashes won't update status immediately)
- Status updates are best-effort
- Consider Firebase Realtime Database for production presence system
- lastSeen is important for offline users

## Next PR
PR-6: One-on-One Chat UI (depends on PR-3, PR-5)

