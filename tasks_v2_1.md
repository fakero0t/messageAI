# MessageAI v2 Tasks - Part 1: Setup & Typing Indicators

## Overview
This document covers PRs 1-5: Firebase infrastructure setup and typing indicator implementation.

**Dependencies:** None (starting point)
**Focus:** Foundation for real-time features

---

## PR-1: Firebase Realtime Database Setup and Configuration

### Meta Information
- **Dependencies:** None
- **Priority:** High (blocking for typing indicators)
- **Branch:** `feature/pr-1-realtime-database-setup`

### Objective
Enable Firebase Realtime Database for ephemeral typing indicator data with automatic cleanup on disconnect.

### Why Realtime Database?
- Lower latency than Firestore for rapid state changes
- Built-in presence system (automatic disconnect handling)
- Optimized for ephemeral data that doesn't need to persist
- Better for the "sub-200ms" performance target in the rubric

### Tasks Checklist
- [ ] Enable Realtime Database in Firebase Console
- [ ] Configure database region (same as Firestore for consistency)
- [ ] Set up Realtime Database security rules
- [ ] Add Firebase Realtime Database SDK to project
- [ ] Create database reference utility in project
- [ ] Test connection and basic read/write operations

### Step-by-Step Implementation

#### Step 1: Enable in Firebase Console
1. Go to Firebase Console → Your Project
2. Navigate to **Build** → **Realtime Database**
3. Click **Create Database**
4. Choose database location (use same region as Firestore)
5. Start in **test mode** temporarily

#### Step 2: Security Rules
In Realtime Database console, go to **Rules** tab and add:

```json
{
  "rules": {
    "typing": {
      "$conversationId": {
        "$userId": {
          ".read": true,
          ".write": "$userId === auth.uid"
        }
      }
    }
  }
}
```

**Rules Explanation:**
- `/typing/{conversationId}/{userId}` structure
- Anyone can read typing status (`.read: true`)
- Users can only write their own status (`.write: "$userId === auth.uid"`)

#### Step 3: Add SDK to Project
1. In Xcode, go to **File** → **Add Package Dependencies**
2. Search: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: 10.0.0 or later
4. Add library: **FirebaseDatabase**

#### Step 4: Test Connection
Write test code to verify Realtime Database connection works. Test should:
- Write a test value to the database
- Read the value back
- Verify no errors occur
- Print success messages

### Files Modified
- `swift_demo.xcodeproj/project.pbxproj` (package dependencies)
- Firebase Console (configuration)

### Acceptance Criteria
- [ ] Realtime Database enabled and accessible
- [ ] Security rules prevent unauthorized access
- [ ] Can read/write test data successfully
- [ ] Presence system works (onDisconnect handlers)
- [ ] No compilation errors
- [ ] Test code prints success messages

### Testing Steps
1. Run test function in simulator
2. Check Firebase Console → Realtime Database to see test data
3. Try writing with unauthenticated user (should fail)
4. Try writing to another user's path (should fail)
5. Verify automatic cleanup on app termination

### Documentation
- Update `FIREBASE_SETUP.md` with Realtime Database setup steps
- Document security rules rationale
- Add troubleshooting section

---

## PR-2: TypingService Implementation with Realtime Database

### Meta Information
- **Dependencies:** PR-1
- **Priority:** High
- **Branch:** `feature/pr-2-typing-service`

### Objective
Create a service that broadcasts typing status to conversation participants using Firebase Realtime Database with automatic cleanup.

### Database Structure
```
/typing
  /{conversationId}
    /{userId}
      timestamp: ServerValue.TIMESTAMP
      displayName: "Alice"
```

### Service Requirements
- Debounced typing updates (500ms delay)
- Automatic timeout after 5 seconds of inactivity
- OnDisconnect cleanup (removes typing status when user disconnects)
- Multi-user typing status aggregation
- Real-time listeners for other participants' typing status
- Combine publishers for reactive updates

### Implementation

#### Create TypingService.swift

**File:** `swift_demo/Services/TypingService.swift`

```swift
//
//  TypingService.swift
//  swift_demo
//
//  Created for PR-2: Typing indicators
//

import Foundation
import FirebaseDatabase
import Combine

class TypingService {
    static let shared = TypingService()
    
    private let database = Database.database().reference()
    private var typingTimeoutTasks: [String: Task<Void, Never>] = [:]
    private var debounceTimers: [String: Timer] = [:]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start broadcasting typing status for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: Current user ID
    ///   - displayName: Current user display name
    func startTyping(conversationId: String, userId: String, displayName: String) {
        let key = "\(conversationId)_\(userId)"
        
        // Cancel existing debounce timer
        debounceTimers[key]?.invalidate()
        
        // Debounce: Only broadcast after 500ms of continued typing
        debounceTimers[key] = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.broadcastTypingStatus(conversationId: conversationId, userId: userId, displayName: displayName)
        }
    }
    
    /// Stop broadcasting typing status
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: Current user ID
    func stopTyping(conversationId: String, userId: String) {
        let key = "\(conversationId)_\(userId)"
        
        // Cancel debounce timer
        debounceTimers[key]?.invalidate()
        debounceTimers[key] = nil
        
        // Cancel timeout task
        typingTimeoutTasks[key]?.cancel()
        typingTimeoutTasks[key] = nil
        
        // Remove from database
        removeTypingStatus(conversationId: conversationId, userId: userId)
    }
    
    /// Observe typing users in a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - currentUserId: Current user ID (to exclude from results)
    /// - Returns: Publisher emitting array of typing user names
    func observeTypingUsers(conversationId: String, currentUserId: String) -> AnyPublisher<[String], Never> {
        let subject = CurrentValueSubject<[String], Never>([])
        
        let typingRef = database.child("typing").child(conversationId)
        
        typingRef.observe(.value) { snapshot in
            var typingUsers: [String] = []
            
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let data = childSnapshot.value as? [String: Any],
                      let displayName = data["displayName"] as? String,
                      childSnapshot.key != currentUserId else {
                    continue
                }
                
                typingUsers.append(displayName)
            }
            
            subject.send(typingUsers)
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Clean up typing status when leaving conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: Current user ID
    func cleanup(conversationId: String, userId: String) {
        stopTyping(conversationId: conversationId, userId: userId)
    }
    
    // MARK: - Private Methods
    
    private func broadcastTypingStatus(conversationId: String, userId: String, displayName: String) {
        let typingRef = database.child("typing").child(conversationId).child(userId)
        
        let data: [String: Any] = [
            "timestamp": ServerValue.timestamp(),
            "displayName": displayName
        ]
        
        // Set typing status
        typingRef.setValue(data)
        
        // Set up onDisconnect to auto-remove when user disconnects
        typingRef.onDisconnectRemoveValue()
        
        // Set up 5-second timeout
        let key = "\(conversationId)_\(userId)"
        typingTimeoutTasks[key]?.cancel()
        typingTimeoutTasks[key] = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                removeTypingStatus(conversationId: conversationId, userId: userId)
            }
        }
    }
    
    private func removeTypingStatus(conversationId: String, userId: String) {
        let typingRef = database.child("typing").child(conversationId).child(userId)
        typingRef.removeValue()
    }
    
    /// Format typing text based on number of users
    /// - Parameter users: Array of typing user display names
    /// - Returns: Formatted string ("Alice is typing...")
    func formatTypingText(users: [String]) -> String? {
        guard !users.isEmpty else { return nil }
        
        switch users.count {
        case 1:
            return "\(users[0]) is typing..."
        case 2:
            return "\(users[0]) and \(users[1]) are typing..."
        default:
            return "\(users[0]) and \(users.count - 1) others are typing..."
        }
    }
}
```

### Key Features Explained

**1. Debouncing:**
- Prevents flooding the network with updates on every keystroke
- Only broadcasts after 500ms of continued typing
- Uses Timer for simple debouncing

**2. Timeout Mechanism:**
- Automatically removes typing status after 5 seconds
- Uses Swift Concurrency (Task.sleep)
- Cancellable if user continues typing

**3. OnDisconnect:**
- Firebase Realtime DB feature
- Automatically removes typing status if app crashes/disconnects
- Ensures stale data doesn't persist

**4. Combine Integration:**
- Returns `AnyPublisher` for reactive SwiftUI updates
- Uses `CurrentValueSubject` to emit updates
- Integrates seamlessly with ChatViewModel

### Files Created
- `swift_demo/Services/TypingService.swift`

### Acceptance Criteria
- [ ] Service compiles without errors
- [ ] startTyping broadcasts to database within 500ms
- [ ] stopTyping removes status immediately
- [ ] Typing status auto-removes after 5 seconds
- [ ] onDisconnect handlers work (test by killing app)
- [ ] observeTypingUsers returns correct list
- [ ] formatTypingText returns correct formats
- [ ] Debouncing prevents excessive updates
- [ ] No memory leaks (test with Instruments)

### Testing Steps
1. Call startTyping and verify in Firebase Console
2. Wait 5 seconds without calling again → should auto-remove
3. Call startTyping rapidly 10 times → should only broadcast once
4. Kill app while typing → status should auto-remove
5. Multiple users typing → observeTypingUsers returns all
6. Test formatTypingText with 1, 2, 3+ users

### Manual Testing
Create buttons in a test view to:
- Call `startTyping` with test conversation and user IDs
- Call `stopTyping` with same IDs
- Verify status appears/disappears in Firebase Console

---

## PR-3: Typing Indicator UI Integration

### Meta Information
- **Dependencies:** PR-2
- **Priority:** High
- **Branch:** `feature/pr-3-typing-indicator-ui`

### Objective
Integrate typing indicators into chat UI showing who is currently typing, displayed in the chat header below the navigation title.

### UI Specifications
- **Location:** Chat header, below navigation title/recipient name
- **Animation:** Subtle fade in/out with animated dots
- **Display Format:**
  - 1 user: "Alice is typing..."
  - 2 users: "Alice and Bob are typing..."
  - 3+ users: "Alice and 2 others are typing..."

### Files to Modify

#### 1. ChatViewModel.swift

Add typing state management:

```swift
// Add to existing ChatViewModel

@Published var typingUsers: [String] = []
@Published var typingText: String?

private let typingService = TypingService.shared
private var typingDebounceTimer: Timer?

// Call in init
private func setupTypingObserver() {
    typingService.observeTypingUsers(conversationId: conversationId, currentUserId: currentUserId)
        .sink { [weak self] users in
            guard let self = self else { return }
            self.typingUsers = users
            self.typingText = self.typingService.formatTypingText(users: users)
        }
        .store(in: &cancellables)
}

// Add method to handle text field changes
func handleTextFieldChange(text: String) {
    guard let currentUserName = AuthenticationService.shared.currentUser?.displayName else { return }
    
    // Cancel existing timer
    typingDebounceTimer?.invalidate()
    
    if !text.isEmpty {
        // User is typing
        typingService.startTyping(
            conversationId: conversationId,
            userId: currentUserId,
            displayName: currentUserName
        )
        
        // Set timer to stop typing after 3 seconds of no changes
        typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.typingService.stopTyping(
                conversationId: self.conversationId,
                userId: self.currentUserId
            )
        }
    } else {
        // User cleared text
        typingService.stopTyping(
            conversationId: conversationId,
            userId: currentUserId
        )
    }
}

// Call in deinit
deinit {
    typingService.cleanup(conversationId: conversationId, userId: currentUserId)
    typingDebounceTimer?.invalidate()
    listenerService.stopListening(conversationId: conversationId)
}
```

**Update init() to call setupTypingObserver:**

```swift
init(recipientId: String, conversationId: String? = nil) {
    // ... existing code ...
    
    loadConversationDetails()
    loadLocalMessages()
    startListening()
    observeNetwork()
    markMessagesAsRead()
    setupTypingObserver() // ADD THIS
}
```

#### 2. ChatView.swift

Update navigation header to show typing indicator:

```swift
// Modify ChatView to use custom header

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            MessageListView(messages: viewModel.messages, viewModel: viewModel)
            MessageInputView(
                onSend: viewModel.sendMessage,
                onTextChange: viewModel.handleTextFieldChange // NEW
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatHeaderView(viewModel: viewModel)
            }
        }
        .onDisappear {
            // Ensure cleanup when leaving chat
            viewModel.typingService.stopTyping(
                conversationId: viewModel.conversationId,
                userId: viewModel.currentUserId
            )
        }
    }
}

struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            // Title (recipient name or group name)
            if viewModel.isGroup {
                Text(viewModel.groupName ?? "Group Chat")
                    .font(.headline)
            } else {
                Text(viewModel.recipientId) // Will show actual name when fetched
                    .font(.headline)
            }
            
            // Status or typing indicator
            if let typingText = viewModel.typingText {
                // Typing indicator
                HStack(spacing: 4) {
                    Text(typingText)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    // Animated dots
                    TypingDotsView()
                }
                .transition(.opacity)
            } else if !viewModel.isGroup {
                // Online status (only for 1-on-1)
                OnlineStatusView(
                    isOnline: viewModel.recipientOnline,
                    lastSeen: viewModel.recipientLastSeen
                )
                .font(.caption)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.typingText)
    }
}

// Animated typing dots
struct TypingDotsView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                    .opacity(animating ? 0.3 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}
```

#### 3. MessageInputView.swift

Add onChange handler to track typing:

```swift
struct MessageInputView: View {
    let onSend: (String) -> Void
    let onTextChange: ((String) -> Void)? // NEW - optional callback
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Image picker button (will add in PR-8)
            
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .onChange(of: messageText) { oldValue, newValue in
                    // NEW: Notify about text changes
                    onTextChange?(newValue)
                }
            
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func send() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        onSend(text)
        messageText = ""
        
        // Stop typing when sending message
        onTextChange?("")
    }
}
```

**Update existing usages** in ChatView:

```swift
// OLD:
MessageInputView(onSend: viewModel.sendMessage)

// NEW:
MessageInputView(
    onSend: viewModel.sendMessage,
    onTextChange: viewModel.handleTextFieldChange
)
```

### Acceptance Criteria
- [ ] Typing indicator appears when user types
- [ ] Indicator shows within 500ms of typing
- [ ] Animated dots display correctly
- [ ] Multiple users shown correctly ("Alice and Bob...")
- [ ] Indicator disappears 5s after typing stops
- [ ] Indicator disappears when message sent
- [ ] Works in both 1-on-1 and group chats
- [ ] No performance impact on text input
- [ ] Smooth fade in/out animations
- [ ] No UI layout issues

### Testing Steps

**Manual Testing:**
1. Open chat between two test accounts
2. Type on device 1 → see indicator on device 2 within 500ms
3. Stop typing → indicator disappears after 5s
4. Type rapidly → should not flood (check Firebase Console)
5. Send message → indicator disappears immediately
6. Test with 3 users in group chat → "Alice and 1 other..."

**Edge Cases:**
- Type, delete all text → indicator stops
- Type, kill app → indicator auto-removes
- Type, switch to another app → indicator stops
- Multiple users typing at once

### UI Polish
- Fade in/out animation: 0.3s duration
- Typing dot animation: 0.6s cycle
- Green color for typing indicator (distinguishable)
- Font size: .caption
- Proper spacing in header

---

## PR-4: Firebase Storage Setup and Security Rules

### Meta Information
- **Dependencies:** None (can be done early)
- **Priority:** High (blocking for images and profiles)
- **Branch:** `feature/pr-4-firebase-storage-setup`

### Objective
Configure Firebase Storage for hosting images and profile pictures with proper security rules.

### Storage Structure
```
/images
  /{conversationId}
    /{messageId}.jpg
/profile_pictures
  /{userId}.jpg
```

### Tasks Checklist
- [ ] Enable Firebase Storage in Firebase Console
- [ ] Configure storage bucket and region
- [ ] Implement security rules for images and profile pictures
- [ ] Add Firebase Storage SDK to project
- [ ] Test upload/download operations
- [ ] Document setup process

### Step-by-Step Implementation

#### Step 1: Enable Storage in Firebase Console
1. Go to Firebase Console → Your Project
2. Navigate to **Build** → **Storage**
3. Click **Get Started**
4. Choose storage location (use same region as Firestore/Realtime DB)
5. Start in **test mode** temporarily

#### Step 2: Security Rules
In Storage console, go to **Rules** tab and replace with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check file size
    function isValidSize(maxSizeMB) {
      return request.resource.size < maxSizeMB * 1024 * 1024;
    }
    
    // Helper function to check if file is an image
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    // Profile pictures: Users can only write their own, anyone authenticated can read
    match /profile_pictures/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() 
                   && request.auth.uid == userId
                   && isValidSize(5)
                   && isImage();
    }
    
    // Message images: Sender can write, conversation participants can read
    match /images/{conversationId}/{messageId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()
                   && isValidSize(10)
                   && isImage();
    }
  }
}
```

**Rules Explanation:**
- **Profile pictures:** Max 5MB, only owner can upload, all authenticated users can view
- **Message images:** Max 10MB, any authenticated user can upload/view
- **Content type validation:** Only image/* MIME types allowed
- **Size limits:** Enforced at Firebase level (backend validation)

#### Step 3: Add Firebase Storage SDK
1. In Xcode, go to **File** → **Add Package Dependencies**
2. Search: `https://github.com/firebase/firebase-ios-sdk` (if not already added)
3. Add library: **FirebaseStorage**

#### Step 4: Test Upload/Download

Create a test file to verify Storage upload/download/delete operations:
- Create a test image
- Upload to Firebase Storage
- Retrieve download URL
- Delete test file
- Verify all operations complete successfully

Run the test from a button in a test view to verify setup.

### Files Modified
- `swift_demo.xcodeproj/project.pbxproj` (add FirebaseStorage)
- Firebase Console (Storage configuration and rules)

### Files Created
- `swift_demo/Tests/StorageTest.swift` (temporary test file)

### Acceptance Criteria
- [ ] Storage enabled and accessible
- [ ] Security rules deployed and active
- [ ] Can upload test image successfully
- [ ] Can download image successfully
- [ ] Can delete image successfully
- [ ] Unauthorized access blocked (test without auth)
- [ ] File size limits enforced (test with >10MB file)
- [ ] Content type validation works (test with .txt file)

### Testing Steps

**Success Cases:**
1. Authenticated user uploads image <5MB → Success
2. Download uploaded image → Success
3. Delete uploaded image → Success

**Failure Cases:**
1. Unauthenticated user uploads → "Permission denied"
2. Upload image >10MB → "Permission denied"
3. Upload non-image file (.txt) → "Permission denied"
4. User A tries to write User B's profile picture → "Permission denied"

### Documentation
Create or update `FIREBASE_SETUP.md`:
- Storage setup instructions
- Security rules explanation
- Usage quotas and limits
- Troubleshooting common issues

### Security Notes
- Never use test mode in production
- Monitor usage in Firebase Console
- Set up billing alerts
- Consider enabling App Check for additional security

---

## PR-5: Image Compression and File Handling Utilities

### Meta Information
- **Dependencies:** PR-4
- **Priority:** High
- **Branch:** `feature/pr-5-image-utilities`

### Objective
Create utilities for compressing images, managing local file storage, and handling image metadata for optimal performance.

### Requirements
- Compress images to ~1MB target size
- Maintain aspect ratio
- Constrain within square bounds (max width/height)
- Handle HEIC/PNG/JPEG formats
- Generate thumbnails for conversation list
- Preserve image quality while reducing size
- Local file management for offline queue

### Files to Create

#### 1. ImageCompressor.swift

**File:** `swift_demo/Utilities/ImageCompressor.swift`

```swift
//
//  ImageCompressor.swift
//  swift_demo
//
//  Created for PR-5: Image compression utilities
//

import UIKit
import AVFoundation

struct ImageCompressor {
    
    // MARK: - Compression
    
    /// Compress image to target size in KB
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - targetSizeKB: Target size in kilobytes (default: 1024 = 1MB)
    /// - Returns: Compressed JPEG data, or nil if compression fails
    static func compress(image: UIImage, targetSizeKB: Int = 1024) -> Data? {
        // First, resize if too large
        let resizedImage = resize(image: image, maxDimension: 2048)
        
        // Start with high quality
        var compression: CGFloat = 1.0
        var imageData = resizedImage.jpegData(compressionQuality: compression)
        
        let targetBytes = targetSizeKB * 1024
        
        // Iteratively reduce quality until under target size
        while let data = imageData, data.count > targetBytes && compression > 0.1 {
            compression -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    // MARK: - Resizing
    
    /// Resize image maintaining aspect ratio, constrained within max dimension
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - maxDimension: Maximum width or height (default: 1024)
    /// - Returns: Resized UIImage
    static func resize(image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        
        // If already smaller, return as-is
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            // Landscape
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Resize
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    /// Resize image to fit within square bounds while maintaining aspect ratio
    /// Used for message bubbles
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - maxSize: Maximum width/height (default: 300)
    /// - Returns: Resized UIImage
    static func resizeForDisplay(image: UIImage, maxSize: CGFloat = 300) -> UIImage {
        return resize(image: image, maxDimension: maxSize)
    }
    
    // MARK: - Thumbnails
    
    /// Generate thumbnail for conversation list preview
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - size: Thumbnail size (default: 100x100)
    /// - Returns: Thumbnail UIImage
    static func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // Calculate rect to maintain aspect ratio (aspect fill)
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = size.width / size.height
        
        var drawRect = CGRect(origin: .zero, size: size)
        
        if aspectRatio > targetAspectRatio {
            // Image is wider
            let scaledWidth = size.height * aspectRatio
            drawRect.origin.x = -(scaledWidth - size.width) / 2
            drawRect.size.width = scaledWidth
        } else {
            // Image is taller
            let scaledHeight = size.width / aspectRatio
            drawRect.origin.y = -(scaledHeight - size.height) / 2
            drawRect.size.height = scaledHeight
        }
        
        image.draw(in: drawRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Metadata
    
    /// Get image dimensions
    /// - Parameter image: UIImage
    /// - Returns: (width, height) tuple
    static func getDimensions(_ image: UIImage) -> (width: Double, height: Double) {
        return (Double(image.size.width), Double(image.size.height))
    }
    
    /// Calculate aspect ratio
    /// - Parameter image: UIImage
    /// - Returns: Aspect ratio (width/height)
    static func getAspectRatio(_ image: UIImage) -> Double {
        return Double(image.size.width) / Double(image.size.height)
    }
}
```

#### 2. ImageFileManager.swift

**File:** `swift_demo/Utilities/ImageFileManager.swift`

```swift
//
//  ImageFileManager.swift
//  swift_demo
//
//  Created for PR-5: Local image file management
//

import UIKit

class ImageFileManager {
    static let shared = ImageFileManager()
    
    private let fileManager = FileManager.default
    private lazy var imagesDirectory: URL = {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesURL = documentsURL.appendingPathComponent("QueuedImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: imagesURL.path) {
            try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        }
        
        return imagesURL
    }()
    
    private init() {}
    
    // MARK: - Save
    
    /// Save image to disk and return file path
    /// - Parameters:
    ///   - image: UIImage to save
    ///   - id: Unique identifier (message ID)
    /// - Returns: File URL
    /// - Throws: File system errors
    func saveImage(_ image: UIImage, withId id: String) throws -> URL {
        let fileURL = getImagePath(withId: id)
        
        // Compress and save as JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageFileError.compressionFailed
        }
        
        try imageData.write(to: fileURL)
        
        print("💾 Image saved to: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Load
    
    /// Load image from disk
    /// - Parameter id: Unique identifier (message ID)
    /// - Returns: UIImage if found, nil otherwise
    /// - Throws: File system errors
    func loadImage(withId id: String) throws -> UIImage? {
        let fileURL = getImagePath(withId: id)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let imageData = try Data(contentsOf: fileURL)
        return UIImage(data: imageData)
    }
    
    // MARK: - Delete
    
    /// Delete image from disk
    /// - Parameter id: Unique identifier (message ID)
    /// - Throws: File system errors
    func deleteImage(withId id: String) throws {
        let fileURL = getImagePath(withId: id)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // Already deleted
        }
        
        try fileManager.removeItem(at: fileURL)
        print("🗑️ Image deleted: \(fileURL.path)")
    }
    
    // MARK: - Path
    
    /// Get file path for image
    /// - Parameter id: Unique identifier (message ID)
    /// - Returns: File URL
    func getImagePath(withId id: String) -> URL {
        return imagesDirectory.appendingPathComponent("\(id).jpg")
    }
    
    // MARK: - Cleanup
    
    /// Clean up old images
    /// - Parameter days: Delete images older than this many days
    func cleanupOldImages(olderThan days: Int = 7) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        
        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date,
                  creationDate < cutoffDate else {
                continue
            }
            
            try? fileManager.removeItem(at: fileURL)
            print("🗑️ Cleaned up old image: \(fileURL.lastPathComponent)")
        }
    }
    
    /// Get total size of cached images
    /// - Returns: Size in bytes
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? Int64 else {
                continue
            }
            totalSize += fileSize
        }
        
        return totalSize
    }
}

enum ImageFileError: LocalizedError {
    case compressionFailed
    case fileNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .fileNotFound:
            return "Image file not found"
        case .saveFailed:
            return "Failed to save image to disk"
        }
    }
}
```

### Files Created
- `swift_demo/Utilities/ImageCompressor.swift`
- `swift_demo/Utilities/ImageFileManager.swift`

### Acceptance Criteria
- [ ] ImageCompressor compresses 5MB image to ~1MB
- [ ] Compression maintains acceptable quality
- [ ] Aspect ratio preserved in all operations
- [ ] Thumbnails generated correctly
- [ ] Images saved to disk successfully
- [ ] Images loaded from disk successfully
- [ ] Images deleted from disk successfully
- [ ] Cleanup removes old files
- [ ] No memory leaks with large images
- [ ] All functions handle errors gracefully

### Testing Steps

Create test file for ImageCompressor and ImageFileManager:
- Test compression reduces 5MB image to ~1MB
- Test aspect ratio preserved after resize
- Test thumbnail generation
- Test save/load/delete cycle
- Test cleanup of old images
- Verify files stored in correct directory

Manual testing:
1. Select large image (5MB+) → compress → verify ~1MB
2. Save image → restart app → load image → verify same
3. Save 10 images → cleanup old → verify deleted
4. Check Documents directory → verify images in QueuedImages folder

### Performance Testing
- Profile with Instruments (Time Profiler)
- Compress 10 images consecutively → should complete in <20s
- No memory leaks when compressing 100 images
- Check memory usage during compression of large images

---

## Summary

This document covered the first 5 PRs:
1. ✅ Firebase Realtime Database setup
2. ✅ TypingService implementation
3. ✅ Typing indicator UI integration
4. ✅ Firebase Storage setup and security rules
5. ✅ Image compression and file handling utilities

**Next:** Continue with `tasks_v2_2.md` for Image Messages (PRs 6-11)

