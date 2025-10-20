# PR-18: Foreground Push Notifications

## Overview
Implement foreground push notifications using Firebase Cloud Messaging (FCM). Show notifications when app is open but user is in different conversation or screen.

## Dependencies
- PR-8: Real-Time Message Receiving

## Tasks

### 1. Configure FCM in Firebase Console
- [ ] Enable Cloud Messaging in Firebase project
- [ ] Upload APNs authentication key or certificate
- [ ] Configure iOS app for push notifications

### 2. Configure Xcode Project
- [ ] Enable Push Notifications capability
- [ ] Add Background Modes: Remote notifications
- [ ] Update Info.plist if needed

### 3. Integrate Firebase Messaging SDK
- [ ] Already added in PR-1, verify FirebaseMessaging imported
- [ ] Configure messaging delegate
- [ ] Request notification permissions

### 4. Create Notification Service
- [ ] Create `Services/NotificationService.swift`
  - [ ] Request notification authorization
  - [ ] Register for remote notifications
  - [ ] Handle FCM token
  - [ ] Save token to Firestore user document

### 5. Implement Foreground Notification Handling
- [ ] Create `UNUserNotificationCenterDelegate`
  - [ ] Show banner when message received in foreground
  - [ ] Only show if user not in that conversation
  - [ ] Tap notification navigates to conversation

### 6. Send FCM Tokens to Firestore
- [ ] Update user document with FCM token
  - [ ] Store in `users/{userId}/fcmToken`
  - [ ] Update when token refreshes
  - [ ] Remove token on logout

### 7. Implement Background Notification Support (Optional)
- [ ] Handle notification when app backgrounded
- [ ] Update badge count
- [ ] Show notification banner

### 8. Test Notification Flow
- [ ] Send test notification from Firebase Console
- [ ] Verify foreground notifications work
- [ ] Verify tap navigation works

## Files to Create/Modify

### New Files
- `swift_demo/Services/NotificationService.swift`

### Modified Files
- `swift_demo/swift_demoApp.swift` - Setup notifications
- `swift_demo/Models/User.swift` - Add fcmToken field
- `swift_demo/Services/AuthenticationService.swift` - Update token on login

## Code Structure Examples

### NotificationService.swift
```swift
import Foundation
import FirebaseMessaging
import UserNotifications

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var notificationPermissionGranted = false
    private var fcmToken: String?
    
    override init() {
        super.init()
    }
    
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
            }
            
            if let error = error {
                print("Error requesting notification authorization: \(error)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func registerFCMToken(for userId: String) {
        guard let token = fcmToken else { return }
        
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("users").document(userId).updateData([
                    "fcmToken": token
                ])
                print("✅ FCM token registered for user: \(userId)")
            } catch {
                print("❌ Error registering FCM token: \(error)")
            }
        }
    }
    
    func removeFCMToken(for userId: String) {
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("users").document(userId).updateData([
                    "fcmToken": FieldValue.delete()
                ])
                print("✅ FCM token removed for user: \(userId)")
            } catch {
                print("❌ Error removing FCM token: \(error)")
            }
        }
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM Token: \(fcmToken ?? "nil")")
        self.fcmToken = fcmToken
        
        // Register token with Firestore
        if let userId = AuthenticationService.shared.currentUser?.id {
            registerFCMToken(for: userId)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Check if user is currently in the conversation
        if let conversationId = userInfo["conversationId"] as? String {
            // TODO: Check if current view is this conversation
            // For now, always show notification
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Navigate to conversation
        if let conversationId = userInfo["conversationId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let navigateToConversation = Notification.Name("navigateToConversation")
}
```

### swift_demoApp.swift (Updated)
```swift
import SwiftUI
import FirebaseCore

@main
struct swift_demoApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationService = NotificationService.shared
    
    init() {
        FirebaseApp.configure()
        NotificationService.shared.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    MainView()
                        .task {
                            // Request notification permissions
                            notificationService.requestAuthorization()
                            
                            // Perform crash recovery
                            await CrashRecoveryService.shared.performRecovery()
                            
                            // Process message queue
                            await MessageQueueService.shared.processQueue()
                        }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(notificationService)
            .modelContainer(PersistenceController.shared.container)
        }
    }
}
```

### AuthenticationService.swift (Updated)
```swift
import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: User?
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        setupAuthStateListener()
    }
    
    func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.loadUserData(userId: user.uid)
            } else {
                self?.currentUser = nil
            }
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        try await createUserDocument(userId: result.user.uid, email: email, displayName: displayName)
        
        // Register FCM token
        NotificationService.shared.registerFCMToken(for: result.user.uid)
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        
        // Register FCM token
        NotificationService.shared.registerFCMToken(for: result.user.uid)
    }
    
    func signOut() throws {
        // Remove FCM token
        if let userId = currentUser?.id {
            NotificationService.shared.removeFCMToken(for: userId)
        }
        
        try auth.signOut()
        currentUser = nil
    }
    
    // ... other methods ...
}
```

### User.swift (Updated)
```swift
import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    var fcmToken: String?
    
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
```

## Acceptance Criteria
- [ ] Notification permissions requested on login
- [ ] FCM token generated and saved to Firestore
- [ ] Foreground notifications show when message received
- [ ] Notifications don't show if user in that conversation (optional)
- [ ] Tapping notification navigates to conversation
- [ ] FCM token updates when refreshed
- [ ] FCM token removed on logout
- [ ] Notification shows sender and message preview
- [ ] Badge count updates (optional)

## Testing

### Test 1: Foreground Notification
1. Log in as User A on Device 1
2. Log in as User B on Device 2
3. On Device 1, navigate to conversation list (don't open chat)
4. Send message from Device 2 to User A
5. Verify notification banner appears on Device 1
6. Tap notification
7. Verify navigates to chat with User B

### Test 2: No Notification in Conversation
1. Open chat between User A and User B on Device 1
2. Send message from Device 2
3. Verify message appears in chat
4. Verify no notification banner (since user is viewing that conversation)

### Test 3: FCM Token Registration
1. Log in
2. Check Firestore → users/{userId}
3. Verify fcmToken field exists
4. Log out
5. Verify fcmToken removed

### Test 4: Background Notification (if implemented)
1. Background app on Device 1
2. Send message from Device 2
3. Verify notification appears
4. Tap notification
5. Verify app opens to conversation

## Notes
- FCM requires APNs certificates/keys from Apple Developer account
- Foreground notifications easier than background (no server needed for MVP)
- Background notifications require FCM server-side sending (optional for MVP)
- Notification payload should include conversationId, senderId, message
- Badge count management requires careful tracking
- Test on real device (notifications don't work in Simulator)
- FCM tokens can refresh - handle updates
- Privacy: don't include full message in notification if sensitive

## Next PR
PR-19: Testing & Bug Fixes (depends on ALL previous PRs)

