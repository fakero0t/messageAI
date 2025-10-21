# MessageAI Feature Enhancement - Task Overview

## Document Purpose
This document provides a comprehensive overview of all PRs needed to implement the three core features from the Feature Enhancement PRD: Typing Indicators, Image Messages, and Profile Pictures.

## Implementation Strategy
- **Total PRs:** 20
- **Approach:** Sequential implementation with dependencies clearly marked
- **Testing:** Unit tests included for critical services

## PR Dependencies Chart

```
Setup Phase:
PR-1 (Firebase Realtime DB) → PR-2 (TypingService)
PR-4 (Firebase Storage) → PR-5 (Image Utils)

Typing Indicators:
PR-1 → PR-2 → PR-3 → PR-17 (Tests)

Image Messages:
PR-4 → PR-5 → PR-6 → PR-7 → PR-8 → PR-9 → PR-10 → PR-11 → PR-18 (Tests)

Profile Pictures:
PR-4 (shared) → PR-12 → PR-13 → PR-14 → PR-15 → PR-16

Documentation:
PR-19 (can be done anytime)
PR-20 (final)
```

## All PRs Summary

### Phase 1: Infrastructure Setup (PRs 1, 4)
- **PR-1:** Firebase Realtime Database Setup and Configuration
- **PR-4:** Firebase Storage Setup and Security Rules

### Phase 2: Typing Indicators (PRs 2-3, 17)
- **PR-2:** TypingService Implementation with Realtime Database
- **PR-3:** Typing Indicator UI Integration
- **PR-17:** TypingService Unit Tests

### Phase 3: Image Messages Foundation (PRs 5-7)
- **PR-5:** Image Compression and File Handling Utilities
- **PR-6:** ImageUploadService Implementation
- **PR-7:** MessageEntity Updates for Image Support

### Phase 4: Image Messages UI (PRs 8-11, 18)
- **PR-8:** Image Picker Integration (Camera + Photo Library)
- **PR-9:** Image Message Bubble and Display
- **PR-10:** Full-Screen Image Viewer with Zoom
- **PR-11:** Image Message Offline Queue Support
- **PR-18:** ImageUploadService Unit Tests

### Phase 5: Profile Pictures (PRs 12-16)
- **PR-12:** User Model and Profile Storage Updates
- **PR-13:** AvatarView Component with Initials Fallback
- **PR-14:** Profile Picture Upload in Settings
- **PR-15:** Avatar Display in Conversation List
- **PR-16:** Avatar Display in Chat Navigation Headers

### Phase 6: Documentation (PRs 19-20)
- **PR-19:** Firebase Setup Documentation
- **PR-20:** Feature Documentation and README Updates

---

## Detailed PR Breakdown

### PR-1: Firebase Realtime Database Setup and Configuration
**Dependencies:** None  
**Priority:** High (blocking for typing indicators)

**Objective:**
Enable Firebase Realtime Database for ephemeral typing indicator data with automatic cleanup on disconnect.

**Tasks:**
1. Enable Realtime Database in Firebase Console
2. Configure database region (same as Firestore for consistency)
3. Set up Realtime Database security rules
4. Add Firebase Realtime Database SDK to project
5. Create database reference utility in project
6. Test connection and basic read/write operations

**Files to Create:**
- None (configuration only)

**Files to Modify:**
- Project configuration
- Firebase setup documentation

**Acceptance Criteria:**
- Realtime Database enabled and accessible
- Security rules prevent unauthorized access
- Can read/write test data successfully
- Presence system works (onDisconnect handlers)

---

### PR-2: TypingService Implementation with Realtime Database
**Dependencies:** PR-1  
**Priority:** High

**Objective:**
Create a service that broadcasts typing status to conversation participants using Firebase Realtime Database with automatic cleanup.

**Implementation Details:**

**Database Structure:**
```
/typing
  /{conversationId}
    /{userId}
      timestamp: ServerValue.TIMESTAMP
      displayName: "Alice"
```

**Service Features:**
- Debounced typing updates (500ms delay)
- Automatic timeout after 5 seconds of inactivity
- OnDisconnect cleanup (removes typing status when user disconnects)
- Multi-user typing status aggregation
- Real-time listeners for other participants' typing status

**Files to Create:**
- `swift_demo/Services/TypingService.swift`

**Key Methods:**
```swift
class TypingService {
    static let shared = TypingService()
    
    // Start typing in a conversation
    func startTyping(conversationId: String, userId: String, displayName: String)
    
    // Stop typing in a conversation
    func stopTyping(conversationId: String, userId: String)
    
    // Listen to typing users in a conversation
    func observeTypingUsers(conversationId: String, currentUserId: String) -> AnyPublisher<[String], Never>
    
    // Clean up typing status (call when leaving chat)
    func cleanup(conversationId: String, userId: String)
}
```

**Technical Requirements:**
- Use Firebase Realtime Database SDK
- Implement debouncing to prevent flooding
- Set onDisconnect() handlers for automatic cleanup
- Return Combine publishers for reactive updates
- Handle network disconnections gracefully
- Aggregate multiple typing users into formatted strings

**Acceptance Criteria:**
- Typing status broadcasts within 500ms
- Automatic cleanup after 5s of inactivity
- OnDisconnect properly clears typing status
- Debouncing prevents excessive updates
- Multiple typing users handled correctly

---

### PR-3: Typing Indicator UI Integration
**Dependencies:** PR-2  
**Priority:** High

**Objective:**
Integrate typing indicators into chat UI showing who is currently typing.

**UI Specifications:**
- Display location: Chat header, below navigation title
- 1 user: "Alice is typing..."
- 2 users: "Alice and Bob are typing..."
- 3+ users: "Alice and 2 others are typing..."
- Animation: Subtle fade in/out with animated dots

**Files to Modify:**
- `swift_demo/ViewModels/ChatViewModel.swift` - Add typing state management
- `swift_demo/Views/Chat/ChatView.swift` - Display typing indicator in header
- `swift_demo/Views/Chat/MessageInputView.swift` - Trigger typing events

**ChatViewModel Changes:**
```swift
@Published var typingUsers: [String] = []
@Published var typingText: String?

private func setupTypingObserver() {
    typingService.observeTypingUsers(conversationId: conversationId, currentUserId: currentUserId)
        .sink { [weak self] users in
            self?.updateTypingDisplay(users)
        }
        .store(in: &cancellables)
}

func handleTextFieldChange(text: String) {
    if !text.isEmpty {
        typingService.startTyping(conversationId: conversationId, userId: currentUserId, displayName: currentUserName)
    } else {
        typingService.stopTyping(conversationId: conversationId, userId: currentUserId)
    }
}
```

**MessageInputView Changes:**
- Add onChange modifier to text field
- Debounce text changes (500ms)
- Call ChatViewModel.handleTextFieldChange

**ChatView Changes:**
- Add typing indicator view below navigation title
- Show/hide with animation
- Display formatted typing text

**Acceptance Criteria:**
- Typing indicator appears within 500ms of typing
- Disappears 5s after user stops typing
- Multiple users displayed correctly
- Smooth animations
- No performance impact on message input
- Works in both 1-on-1 and group chats

---

### PR-4: Firebase Storage Setup and Security Rules
**Dependencies:** None  
**Priority:** High (blocking for images and profiles)

**Objective:**
Configure Firebase Storage for hosting images and profile pictures with proper security rules.

**Tasks:**
1. Enable Firebase Storage in Firebase Console
2. Configure storage bucket and region
3. Implement security rules for images and profile pictures
4. Add Firebase Storage SDK to project
5. Test upload/download operations

**Storage Structure:**
```
/images
  /{conversationId}
    /{messageId}.jpg
/profile_pictures
  /{userId}.jpg
```

**Security Rules:**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures: Users can only write their own, anyone authenticated can read
    match /profile_pictures/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Message images: Sender can write, conversation participants can read
    match /images/{conversationId}/{messageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

**Files to Modify:**
- Project configuration
- Add Storage SDK references

**Acceptance Criteria:**
- Storage enabled and accessible
- Security rules deployed
- Can upload test image successfully
- Can download image successfully
- Unauthorized access blocked
- File size limits enforced (10MB max)

---

### PR-5: Image Compression and File Handling Utilities
**Dependencies:** PR-4  
**Priority:** High

**Objective:**
Create utilities for compressing images, managing local file storage, and handling image metadata.

**Files to Create:**
- `swift_demo/Utilities/ImageCompressor.swift`
- `swift_demo/Utilities/ImageFileManager.swift`

**ImageCompressor Features:**
- Compress images to ~1MB target size
- Maintain aspect ratio
- Constrain within square bounds (max width/height)
- Handle HEIC/PNG/JPEG formats
- Generate thumbnails for conversation list
- Preserve image quality while reducing size

**Implementation:**
```swift
struct ImageCompressor {
    static func compress(image: UIImage, targetSizeKB: Int = 1024) -> Data?
    static func resize(image: UIImage, maxDimension: CGFloat = 1024) -> UIImage
    static func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage?
}
```

**ImageFileManager Features:**
- Save compressed images to disk (for offline queue)
- Retrieve images from disk
- Clean up temporary files
- Manage cache directory
- Handle file path persistence

**Implementation:**
```swift
class ImageFileManager {
    static let shared = ImageFileManager()
    
    func saveImage(_ image: UIImage, withId id: String) throws -> URL
    func loadImage(withId id: String) throws -> UIImage?
    func deleteImage(withId id: String) throws
    func getImagePath(withId id: String) -> URL
    func cleanupOldImages(olderThan days: Int)
}
```

**Technical Requirements:**
- Use iOS image compression APIs
- Store in app's Documents directory
- Handle memory efficiently (don't load full images unnecessarily)
- Support background compression
- Async/await for compression operations

**Acceptance Criteria:**
- 5MB image compresses to ~1MB
- Compression maintains acceptable quality
- Aspect ratio preserved
- Images saved to disk successfully
- Images retrieved from disk successfully
- Temporary files cleaned up properly
- No memory leaks with large images

---

### PR-6: ImageUploadService Implementation
**Dependencies:** PR-4, PR-5  
**Priority:** High

**Objective:**
Create a service to handle image uploads to Firebase Storage with progress tracking, retry logic, and error handling.

**Files to Create:**
- `swift_demo/Services/ImageUploadService.swift`

**Service Features:**
- Upload images to Firebase Storage
- Progress tracking with callbacks
- Automatic retry on failure
- Generate download URLs
- Handle offline queueing
- Cleanup failed uploads

**Implementation:**
```swift
class ImageUploadService {
    static let shared = ImageUploadService()
    
    struct UploadProgress {
        let messageId: String
        let progress: Double // 0.0 to 1.0
        let status: UploadStatus
    }
    
    enum UploadStatus {
        case preparing
        case uploading
        case completed
        case failed(Error)
    }
    
    // Upload image and return download URL
    func uploadImage(
        _ image: UIImage,
        messageId: String,
        conversationId: String,
        progressHandler: @escaping (UploadProgress) -> Void
    ) async throws -> String // Returns download URL
    
    // Cancel ongoing upload
    func cancelUpload(messageId: String)
    
    // Retry failed upload
    func retryUpload(messageId: String) async throws -> String
}
```

**Technical Requirements:**
- Use Firebase Storage SDK
- Compress image before upload (use ImageCompressor)
- Track upload progress with publishProgress
- Generate secure download URLs
- Implement exponential backoff for retries
- Handle network errors gracefully
- Support cancellation
- Clean up on failure

**Storage Path:**
- Pattern: `/images/{conversationId}/{messageId}.jpg`
- Use message ID as filename for easy reference
- Store metadata (original size, compressed size, dimensions)

**Acceptance Criteria:**
- Successfully uploads images to Firebase Storage
- Progress updates work correctly (0-100%)
- Download URL returned on success
- Retry logic works for failed uploads
- Cancellation stops upload immediately
- Handles network errors gracefully
- No memory leaks with large uploads
- Concurrent uploads supported

---

### PR-7: MessageEntity Updates for Image Support
**Dependencies:** None (can be done early)  
**Priority:** High

**Objective:**
Update MessageEntity model to support image messages with optional text field.

**Files to Modify:**
- `swift_demo/Models/SwiftData/MessageEntity.swift`
- `swift_demo/Services/LocalStorageService.swift` (if needed)
- `swift_demo/Services/MessageService.swift`

**MessageEntity Changes:**
```swift
@Model
class MessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var text: String? // Make nullable for image-only messages
    var timestamp: Date
    var status: MessageStatus
    var readBy: [String]
    
    // NEW: Image support
    var imageUrl: String?
    var imageLocalPath: String? // For offline queue
    var imageWidth: Double?
    var imageHeight: Double?
    
    var isImageMessage: Bool {
        imageUrl != nil || imageLocalPath != nil
    }
    
    // Computed property for conversation list preview
    var displayText: String {
        if isImageMessage {
            return "Image"
        }
        return text ?? ""
    }
}
```

**Migration Considerations:**
- Add new optional fields to existing model
- SwiftData should handle migration automatically
- Test with existing messages to ensure no data loss

**LocalStorageService Updates:**
- Update save/fetch methods to handle image fields
- Add methods for querying image messages specifically
- Handle image path references

**MessageService Updates:**
- Update sendToFirestore to include image metadata
- Update syncMessageFromFirestore to handle images
- Add validation for image message structure

**Acceptance Criteria:**
- Model compiles and builds successfully
- Existing messages unaffected
- New image fields save/load correctly
- Migration works without data loss
- isImageMessage computed property works
- displayText shows "Image" for image messages

---

### PR-8: Image Picker Integration (Camera + Photo Library)
**Dependencies:** PR-5, PR-7  
**Priority:** Medium

**Objective:**
Integrate PHPickerViewController for selecting images from photo library and UIImagePickerController for camera, with permission handling.

**Files to Create:**
- `swift_demo/Views/Chat/ImagePickerView.swift`
- `swift_demo/Utilities/PermissionManager.swift`

**ImagePickerView Implementation:**
```swift
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    let sourceType: UIImagePickerController.SourceType // .camera or .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context)
    func makeCoordinator() -> Coordinator
}
```

**PermissionManager Implementation:**
```swift
class PermissionManager {
    static let shared = PermissionManager()
    
    func requestCameraPermission() async -> Bool
    func requestPhotoLibraryPermission() async -> Bool
    func checkCameraPermission() -> Bool
    func checkPhotoLibraryPermission() -> Bool
    
    // Show alert for denied permissions
    func showPermissionDeniedAlert(for permission: PermissionType)
}
```

**Files to Modify:**
- `swift_demo/Views/Chat/MessageInputView.swift` - Add image picker buttons
- `Info.plist` - Add camera and photo library usage descriptions

**Info.plist Additions:**
```xml
<key>NSCameraUsageDescription</key>
<string>MessageAI needs camera access to take photos for messages</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>MessageAI needs photo library access to share images in messages</string>
```

**MessageInputView Changes:**
- Add camera button (camera icon)
- Add photo library button (photo icon)
- Show action sheet: "Take Photo" or "Choose from Library"
- Handle image selection
- Display selected image preview before sending
- Show permission denied alerts gracefully

**UI Flow:**
1. User taps image button (+ or camera icon)
2. Action sheet appears: "Take Photo" / "Choose Photo" / "Cancel"
3. Check/request permissions
4. Show appropriate picker
5. User selects image
6. Show preview with "Send" / "Cancel" options
7. On send, compress and upload

**Acceptance Criteria:**
- Photo library picker works correctly
- Camera picker works correctly
- Permissions requested on first use
- Permission denied shows helpful alert
- Selected image displays in preview
- Cancel button works at all stages
- UI is intuitive and responsive
- Works on simulator (photo library) and device (both)

---

### PR-9: Image Message Bubble and Display
**Dependencies:** PR-6, PR-7, PR-8  
**Priority:** Medium

**Objective:**
Update message bubbles to display images with progressive loading, placeholders, and proper layout.

**Files to Create:**
- `swift_demo/Views/Chat/ImageMessageView.swift`

**Files to Modify:**
- `swift_demo/Views/Chat/MessageBubbleView.swift`
- `swift_demo/ViewModels/ChatViewModel.swift` - Add sendImage method
- `swift_demo/Views/Chat/MessageInputView.swift` - Connect image sending

**ImageMessageView Implementation:**
```swift
struct ImageMessageView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        // Async image loading with placeholder
        // Maintain aspect ratio within max bounds
        // Tap to open full screen
        // Show loading indicator
        // Handle load failures
    }
}
```

**Features:**
- Progressive image loading with placeholder
- Skeleton loading animation
- Aspect ratio preservation (constrained within square)
- Max dimensions: 300x300 points
- Tap gesture to open full screen viewer
- Loading indicator overlay
- Error state for failed loads
- Image caching to prevent re-downloads

**MessageBubbleView Updates:**
```swift
var body: some View {
    if message.isImageMessage {
        ImageMessageView(message: message, isFromCurrentUser: isFromCurrentUser)
            .onTapGesture {
                // Open full screen viewer
            }
    } else {
        // Existing text message view
    }
}
```

**ChatViewModel.sendImage Implementation:**
```swift
func sendImage(_ image: UIImage) {
    let messageId = UUID().uuidString
    
    // 1. Compress image
    guard let compressedData = ImageCompressor.compress(image: image) else {
        errorMessage = "Failed to process image"
        return
    }
    
    // 2. Save to disk (for offline queue)
    let imagePath = try? ImageFileManager.shared.saveImage(image, withId: messageId)
    
    // 3. Create optimistic message
    let optimisticMessage = MessageEntity(
        id: messageId,
        conversationId: conversationId,
        senderId: currentUserId,
        text: nil, // No text for image-only message
        timestamp: Date(),
        status: .pending,
        imageLocalPath: imagePath?.path
    )
    messages.append(optimisticMessage)
    
    // 4. Upload in background
    Task {
        do {
            let downloadUrl = try await ImageUploadService.shared.uploadImage(
                image,
                messageId: messageId,
                conversationId: conversationId
            ) { progress in
                // Update progress UI
            }
            
            // 5. Send message to Firestore with image URL
            try await messageService.sendImageMessage(
                messageId: messageId,
                imageUrl: downloadUrl,
                conversationId: conversationId,
                senderId: currentUserId,
                recipientId: recipientId
            )
            
            updateMessageStatus(messageId: messageId, status: .sent)
        } catch {
            // Queue for retry if upload fails
            updateMessageStatus(messageId: messageId, status: .queued)
        }
    }
}
```

**Acceptance Criteria:**
- Image messages display correctly in chat
- Images maintain aspect ratio
- Loading placeholder shows during fetch
- Images cached after first load
- Tap opens full screen viewer
- Works for both sent and received images
- Optimistic UI shows image immediately
- Failed images show retry option
- No layout issues with different aspect ratios

---

### PR-10: Full-Screen Image Viewer with Zoom
**Dependencies:** PR-9  
**Priority:** Medium

**Objective:**
Create a full-screen image viewer with zoom, pan, and dismiss gestures.

**Files to Create:**
- `swift_demo/Views/Chat/FullScreenImageView.swift`

**Features:**
- Full-screen image display
- Pinch to zoom (up to 3x)
- Pan to navigate zoomed image
- Double-tap to zoom in/out
- Swipe down to dismiss
- Dark overlay background
- Show sender name and timestamp
- Save to photo library button
- Share button

**Implementation:**
```swift
struct FullScreenImageView: View {
    let imageUrl: String
    let message: MessageEntity
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnificationGesture)
                    .gesture(dragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            scale = scale > 1 ? 1 : 2
                            offset = .zero
                        }
                    }
            } placeholder: {
                ProgressView()
            }
            
            VStack {
                HStack {
                    Button("Done") { dismiss() }
                    Spacer()
                    Menu {
                        Button("Save to Photos") { saveToPhotos() }
                        ShareLink(item: imageUrl)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .padding()
                Spacer()
            }
        }
    }
}
```

**Gestures:**
- Magnification gesture for pinch-to-zoom
- Drag gesture for panning
- Limit zoom (min: 1x, max: 3x)
- Reset offset when zoomed out
- Swipe down to dismiss (with threshold)

**Acceptance Criteria:**
- Opens in full screen from message bubble tap
- Pinch to zoom works smoothly
- Pan gesture works when zoomed
- Double-tap toggles zoom (1x <-> 2x)
- Swipe down dismisses viewer
- Save to photos works
- Share button works
- Smooth animations
- Works with different aspect ratios
- No performance issues with large images

---

### PR-11: Image Message Offline Queue Support
**Dependencies:** PR-6, PR-7, PR-9  
**Priority:** Medium

**Objective:**
Extend MessageQueueService to handle image uploads when device comes back online.

**Files to Modify:**
- `swift_demo/Models/SwiftData/QueuedMessageEntity.swift`
- `swift_demo/Services/MessageQueueService.swift`
- `swift_demo/Services/LocalStorageService.swift`

**QueuedMessageEntity Updates:**
```swift
@Model
class QueuedMessageEntity {
    // Existing fields
    @Attribute(.unique) var id: String
    var conversationId: String
    var text: String?  // Make nullable
    var timestamp: Date
    var retryCount: Int
    
    // NEW: Image support
    var imageLocalPath: String?
    var isImageMessage: Bool
    
    init(id: String, conversationId: String, text: String?, timestamp: Date, imageLocalPath: String? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.timestamp = timestamp
        self.retryCount = 0
        self.imageLocalPath = imageLocalPath
        self.isImageMessage = imageLocalPath != nil
    }
}
```

**MessageQueueService Updates:**
```swift
func queueImageMessage(
    id: String,
    conversationId: String,
    imageLocalPath: String
) throws {
    let queuedMessage = QueuedMessageEntity(
        id: id,
        conversationId: conversationId,
        text: nil,
        timestamp: Date(),
        imageLocalPath: imageLocalPath
    )
    try localStorage.queueMessage(queuedMessage)
    updateQueueCount()
}

func processQueue() async {
    // Existing logic for text messages
    
    // NEW: Handle image messages
    for queuedMessage in queuedMessages where queuedMessage.isImageMessage {
        await processImageMessage(queuedMessage)
    }
}

private func processImageMessage(_ queuedMessage: QueuedMessageEntity) async {
    guard let imagePath = queuedMessage.imageLocalPath,
          let image = try? ImageFileManager.shared.loadImage(withId: queuedMessage.id) else {
        // Image file missing, mark as failed
        try? markMessageAsFailed(queuedMessage)
        return
    }
    
    do {
        // Upload image
        let downloadUrl = try await ImageUploadService.shared.uploadImage(
            image,
            messageId: queuedMessage.id,
            conversationId: queuedMessage.conversationId
        ) { _ in }
        
        // Send message to Firestore
        try await messageService.sendImageMessage(
            messageId: queuedMessage.id,
            imageUrl: downloadUrl,
            conversationId: queuedMessage.conversationId,
            senderId: currentUserId,
            recipientId: recipientId
        )
        
        // Remove from queue
        try localStorage.removeQueuedMessage(queuedMessage.id)
        
        // Clean up local file
        try? ImageFileManager.shared.deleteImage(withId: queuedMessage.id)
        
        // Update message status
        try localStorage.updateMessageStatus(messageId: queuedMessage.id, status: .delivered)
        
    } catch {
        // Retry logic
        try? localStorage.incrementRetryCount(messageId: queuedMessage.id)
    }
}
```

**Acceptance Criteria:**
- Image messages queue when offline
- Queued images persist across app restarts
- Images upload when network restored
- Progress shown during upload
- Failed images show retry option
- Local files cleaned up after successful upload
- Queue processes images in order
- No duplicate uploads
- Works with existing text message queue

---

### PR-12: User Model and Profile Storage Updates
**Dependencies:** PR-4  
**Priority:** Medium

**Objective:**
Update User model to include profile picture URL and update UserService to handle profile uploads.

**Files to Modify:**
- `swift_demo/Models/User.swift`
- `swift_demo/Services/UserService.swift`
- `swift_demo/Services/AuthenticationService.swift`

**User Model Changes:**
```swift
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    var profileImageUrl: String? // NEW
    
    var initials: String {
        let components = displayName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return String(initials).uppercased()
    }
    
    // ... existing methods
}
```

**UserService Updates:**
```swift
func uploadProfileImage(userId: String, image: UIImage) async throws -> String {
    // 1. Compress image
    guard let compressedData = ImageCompressor.compress(image: image, targetSizeKB: 500) else {
        throw ImageError.compressionFailed
    }
    
    // 2. Upload to Firebase Storage
    let storageRef = Storage.storage().reference()
    let profileImageRef = storageRef.child("profile_pictures/\(userId).jpg")
    
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    
    _ = try await profileImageRef.putDataAsync(compressedData, metadata: metadata)
    
    // 3. Get download URL
    let downloadUrl = try await profileImageRef.downloadURL()
    
    // 4. Update Firestore user document
    try await Firestore.firestore()
        .collection("users")
        .document(userId)
        .updateData(["profileImageUrl": downloadUrl.absoluteString])
    
    // 5. Update local user object
    if var currentUser = AuthenticationService.shared.currentUser {
        currentUser.profileImageUrl = downloadUrl.absoluteString
        AuthenticationService.shared.currentUser = currentUser
    }
    
    return downloadUrl.absoluteString
}

func deleteProfileImage(userId: String) async throws {
    // 1. Delete from Storage
    let storageRef = Storage.storage().reference()
    let profileImageRef = storageRef.child("profile_pictures/\(userId).jpg")
    try await profileImageRef.delete()
    
    // 2. Update Firestore
    try await Firestore.firestore()
        .collection("users")
        .document(userId)
        .updateData(["profileImageUrl": FieldValue.delete()])
    
    // 3. Update local user
    if var currentUser = AuthenticationService.shared.currentUser {
        currentUser.profileImageUrl = nil
        AuthenticationService.shared.currentUser = currentUser
    }
}
```

**Acceptance Criteria:**
- User model includes profileImageUrl
- Existing users work without profile images
- Upload profile image function works
- Profile image URL saves to Firestore
- Delete profile image works
- Local user object updates correctly
- Initials computed property works

---

### PR-13: AvatarView Component with Initials Fallback
**Dependencies:** PR-12  
**Priority:** Medium

**Objective:**
Create a reusable avatar component that displays profile pictures or generated initials with colored backgrounds.

**Files to Create:**
- `swift_demo/Views/Components/AvatarView.swift`

**Implementation:**
```swift
struct AvatarView: View {
    let user: User?
    let size: CGFloat
    @State private var image: UIImage?
    
    private var backgroundColor: Color {
        // Generate consistent color based on user ID
        guard let user = user else { return .gray }
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal, .indigo]
        let index = abs(user.id.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let user = user {
                Text(user.initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let urlString = user?.profileImageUrl,
              let url = URL(string: urlString) else {
            return
        }
        
        // Load image with caching
        // Use URLCache or custom cache
    }
}
```

**Features:**
- Display profile picture if available
- Fall back to initials with colored background
- Consistent color per user (hash-based)
- Circular shape
- Configurable size
- Image caching
- Async image loading
- Placeholder for nil user

**Size Presets:**
```swift
extension AvatarView {
    static let sizeSmall: CGFloat = 32
    static let sizeMedium: CGFloat = 48
    static let sizeLarge: CGFloat = 80
    static let sizeExtraLarge: CGFloat = 120
}
```

**Acceptance Criteria:**
- Displays profile picture when available
- Shows initials when no picture
- Background color consistent per user
- Circular shape maintained
- Works with different sizes
- Images cached properly
- Smooth loading (no flicker)
- Works with nil user (shows placeholder)

---

### PR-14: Profile Picture Upload in Settings
**Dependencies:** PR-12, PR-13  
**Priority:** Medium

**Objective:**
Add profile picture upload functionality to the existing ProfileView with camera/photo library options.

**Files to Modify:**
- `swift_demo/Views/MainView.swift` (ProfileView section)

**ProfileView Updates:**
```swift
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingImageSource = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploading = false
    @State private var uploadError: String?
    
    var currentUser: User? {
        AuthenticationService.shared.currentUser
    }
    
    var body: some View {
        NavigationStack {
            List {
                // NEW: Profile Picture Section
                Section {
                    VStack(spacing: 16) {
                        AvatarView(user: currentUser, size: AvatarView.sizeExtraLarge)
                        
                        if isUploading {
                            ProgressView("Uploading...")
                        } else {
                            Button("Change Photo") {
                                showingImageSource = true
                            }
                            
                            if currentUser?.profileImageUrl != nil {
                                Button("Remove Photo", role: .destructive) {
                                    deleteProfileImage()
                                }
                            }
                        }
                        
                        if let error = uploadError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // Existing sections...
            }
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSource) {
                Button("Take Photo") {
                    imageSourceType = .camera
                    checkCameraPermission()
                }
                Button("Choose from Library") {
                    imageSourceType = .photoLibrary
                    checkPhotoLibraryPermission()
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage, sourceType: imageSourceType)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    uploadProfileImage(image)
                }
            }
            .navigationTitle("Profile")
        }
    }
    
    private func checkCameraPermission() {
        Task {
            let granted = await PermissionManager.shared.requestCameraPermission()
            if granted {
                showingImagePicker = true
            } else {
                PermissionManager.shared.showPermissionDeniedAlert(for: .camera)
            }
        }
    }
    
    private func checkPhotoLibraryPermission() {
        Task {
            let granted = await PermissionManager.shared.requestPhotoLibraryPermission()
            if granted {
                showingImagePicker = true
            } else {
                PermissionManager.shared.showPermissionDeniedAlert(for: .photoLibrary)
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let userId = currentUser?.id else { return }
        
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                _ = try await UserService.shared.uploadProfileImage(userId: userId, image: image)
                isUploading = false
                selectedImage = nil
            } catch {
                isUploading = false
                uploadError = "Failed to upload image"
                print("Upload error: \(error)")
            }
        }
    }
    
    private func deleteProfileImage() {
        guard let userId = currentUser?.id else { return }
        
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                try await UserService.shared.deleteProfileImage(userId: userId)
                isUploading = false
            } catch {
                isUploading = false
                uploadError = "Failed to delete image"
            }
        }
    }
}
```

**Acceptance Criteria:**
- Profile picture displays in Settings
- "Change Photo" button works
- Camera option available on device
- Photo library option works
- Upload progress shown
- Success updates UI immediately
- "Remove Photo" button works
- Error messages displayed clearly
- Permissions handled gracefully
- Works on both simulator and device

---

### PR-15: Avatar Display in Conversation List
**Dependencies:** PR-13  
**Priority:** Low

**Objective:**
Add avatar display to conversation rows in the conversation list.

**Files to Modify:**
- `swift_demo/Views/Conversations/ConversationRowView.swift`

**ConversationRowView Updates:**
```swift
struct ConversationRowView: View {
    let conversation: ConversationEntity
    let currentUserId: String
    @State private var otherUser: User?
    @State private var lastMessage: MessageEntity?
    
    var body: some View {
        HStack(spacing: 12) {
            // NEW: Avatar
            if conversation.isGroup {
                // Group icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.blue)
                }
            } else {
                // User avatar
                AvatarView(user: otherUser, size: AvatarView.sizeMedium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.headline)
                    Spacer()
                    if let timestamp = conversation.lastMessageTime {
                        Text(timestamp.chatTimestamp())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var lastMessagePreview: String {
        // Handle image messages
        if lastMessage?.isImageMessage == true {
            return "Image"
        }
        return lastMessage?.text ?? "No messages yet"
    }
}
```

**Acceptance Criteria:**
- Avatars display in conversation list
- 1-on-1 chats show other user's avatar
- Group chats show group icon
- Initials shown when no profile picture
- Image messages show "Image" in preview
- Layout looks clean and professional
- No performance issues with many conversations

---

### PR-16: Avatar Display in Chat Navigation Headers
**Dependencies:** PR-13  
**Priority:** Low

**Objective:**
Add avatar display to chat navigation bar showing recipient information.

**Files to Modify:**
- `swift_demo/Views/Chat/ChatView.swift`

**ChatView Navigation Updates:**
```swift
struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            MessageListView(messages: viewModel.messages, viewModel: viewModel)
            MessageInputView(onSend: viewModel.sendMessage)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatHeaderView(viewModel: viewModel)
            }
        }
    }
}

struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var recipientUser: User?
    
    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isGroup {
                // Group: Just name, no avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.groupName ?? "Group Chat")
                        .font(.headline)
                    Text("\(viewModel.participants.count) participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // 1-on-1: Show avatar + name + status
                AvatarView(user: recipientUser, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipientUser?.displayName ?? "User")
                        .font(.headline)
                    
                    if viewModel.typingText != nil {
                        Text(viewModel.typingText!)
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    } else {
                        OnlineStatusView(
                            isOnline: viewModel.recipientOnline,
                            lastSeen: viewModel.recipientLastSeen
                        )
                        .font(.caption)
                    }
                }
            }
        }
        .task {
            await loadRecipientUser()
        }
    }
    
    private func loadRecipientUser() async {
        do {
            recipientUser = try await UserService.shared.fetchUser(byId: viewModel.recipientId)
        } catch {
            print("Failed to load recipient user: \(error)")
        }
    }
}
```

**Acceptance Criteria:**
- Avatar displays in navigation bar for 1-on-1 chats
- Group chats show name only (no avatar)
- Online status shows below name
- Typing indicator replaces status when user typing
- Tap avatar to see user profile (optional)
- Layout looks clean in navigation bar
- Works with different device sizes

---

### PR-17: TypingService Unit Tests
**Dependencies:** PR-2  
**Priority:** Medium

**Objective:**
Write comprehensive unit tests for TypingService to ensure reliability.

**Files to Create:**
- `swift_demoTests/TypingServiceTests.swift`

**Test Coverage:**
```swift
class TypingServiceTests: XCTestCase {
    var typingService: TypingService!
    var mockDatabase: MockRealtimeDatabase!
    
    override func setUp() {
        super.setUp()
        mockDatabase = MockRealtimeDatabase()
        typingService = TypingService(database: mockDatabase)
    }
    
    // MARK: - Basic Functionality
    func testStartTyping_BroadcastsTypingStatus() async throws {
        // Given
        let conversationId = "test-conv-123"
        let userId = "user-1"
        let displayName = "Alice"
        
        // When
        try await typingService.startTyping(
            conversationId: conversationId,
            userId: userId,
            displayName: displayName
        )
        
        // Then
        XCTAssertTrue(mockDatabase.hasTypingStatus(conversationId: conversationId, userId: userId))
    }
    
    func testStopTyping_RemovesTypingStatus() async throws {
        // Given: User is typing
        let conversationId = "test-conv-123"
        let userId = "user-1"
        try await typingService.startTyping(conversationId: conversationId, userId: userId, displayName: "Alice")
        
        // When
        try await typingService.stopTyping(conversationId: conversationId, userId: userId)
        
        // Then
        XCTAssertFalse(mockDatabase.hasTypingStatus(conversationId: conversationId, userId: userId))
    }
    
    // MARK: - Debouncing
    func testStartTyping_DebouncesRapidCalls() async throws {
        // Given
        let conversationId = "test-conv-123"
        let userId = "user-1"
        
        // When: Multiple rapid calls
        for _ in 0..<10 {
            try await typingService.startTyping(conversationId: conversationId, userId: userId, displayName: "Alice")
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        // Then: Should have limited database writes
        XCTAssertLessThan(mockDatabase.writeCount, 3) // Debounced
    }
    
    // MARK: - Timeout
    func testTypingStatus_TimesOutAfter5Seconds() async throws {
        // Given: User starts typing
        let conversationId = "test-conv-123"
        let userId = "user-1"
        try await typingService.startTyping(conversationId: conversationId, userId: userId, displayName: "Alice")
        
        // When: Wait 6 seconds
        try await Task.sleep(nanoseconds: 6_000_000_000)
        
        // Then: Status should be cleared
        XCTAssertFalse(mockDatabase.hasTypingStatus(conversationId: conversationId, userId: userId))
    }
    
    // MARK: - Multiple Users
    func testObserveTypingUsers_ReturnsMultipleUsers() async throws {
        // Given: Multiple users typing
        let conversationId = "test-conv-123"
        try await typingService.startTyping(conversationId: conversationId, userId: "user-1", displayName: "Alice")
        try await typingService.startTyping(conversationId: conversationId, userId: "user-2", displayName: "Bob")
        
        // When: Observe typing users
        let typingUsers = await typingService.getTypingUsers(conversationId: conversationId, currentUserId: "user-3")
        
        // Then
        XCTAssertEqual(typingUsers.count, 2)
        XCTAssertTrue(typingUsers.contains("Alice"))
        XCTAssertTrue(typingUsers.contains("Bob"))
    }
    
    func testFormatTypingText_ShowsCorrectFormat() {
        // Given different numbers of typing users
        
        // When: 1 user
        let text1 = typingService.formatTypingText(users: ["Alice"])
        XCTAssertEqual(text1, "Alice is typing...")
        
        // When: 2 users
        let text2 = typingService.formatTypingText(users: ["Alice", "Bob"])
        XCTAssertEqual(text2, "Alice and Bob are typing...")
        
        // When: 3+ users
        let text3 = typingService.formatTypingText(users: ["Alice", "Bob", "Charlie"])
        XCTAssertEqual(text3, "Alice and 2 others are typing...")
    }
    
    // MARK: - Cleanup
    func testCleanup_RemovesTypingStatus() async throws {
        // Given: User typing in multiple conversations
        try await typingService.startTyping(conversationId: "conv-1", userId: "user-1", displayName: "Alice")
        try await typingService.startTyping(conversationId: "conv-2", userId: "user-1", displayName: "Alice")
        
        // When: Cleanup one conversation
        try await typingService.cleanup(conversationId: "conv-1", userId: "user-1")
        
        // Then: Only that conversation's status removed
        XCTAssertFalse(mockDatabase.hasTypingStatus(conversationId: "conv-1", userId: "user-1"))
        XCTAssertTrue(mockDatabase.hasTypingStatus(conversationId: "conv-2", userId: "user-1"))
    }
    
    // MARK: - Error Handling
    func testStartTyping_HandlesNetworkError() async {
        // Given: Mock network error
        mockDatabase.simulateNetworkError = true
        
        // When/Then: Should not crash
        do {
            try await typingService.startTyping(conversationId: "test", userId: "user-1", displayName: "Alice")
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
```

**Mock Objects:**
```swift
class MockRealtimeDatabase {
    var typingStatuses: [String: [String: Any]] = [:]
    var writeCount = 0
    var simulateNetworkError = false
    
    func hasTypingStatus(conversationId: String, userId: String) -> Bool {
        // Check if typing status exists
    }
    
    // Mock database operations
}
```

**Acceptance Criteria:**
- All tests pass
- Code coverage > 80%
- Tests are fast (< 5 seconds total)
- Mock objects work correctly
- Edge cases covered
- Error handling tested

---

### PR-18: ImageUploadService Unit Tests
**Dependencies:** PR-6  
**Priority:** Medium

**Objective:**
Write comprehensive unit tests for ImageUploadService.

**Files to Create:**
- `swift_demoTests/ImageUploadServiceTests.swift`
- `swift_demoTests/MockStorageService.swift`

**Test Coverage:**
```swift
class ImageUploadServiceTests: XCTestCase {
    var uploadService: ImageUploadService!
    var mockStorage: MockStorageService!
    var testImage: UIImage!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockStorageService()
        uploadService = ImageUploadService(storage: mockStorage)
        testImage = createTestImage()
    }
    
    // MARK: - Upload Success
    func testUploadImage_SuccessfullyUploadsAndReturnsURL() async throws {
        // Given
        let messageId = "msg-123"
        let conversationId = "conv-456"
        var progressUpdates: [Double] = []
        
        // When
        let url = try await uploadService.uploadImage(
            testImage,
            messageId: messageId,
            conversationId: conversationId
        ) { progress in
            progressUpdates.append(progress.progress)
        }
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.contains(messageId))
        XCTAssertTrue(progressUpdates.contains(1.0)) // Completed
    }
    
    // MARK: - Progress Tracking
    func testUploadImage_ReportsProgress() async throws {
        // Given
        var progressUpdates: [ImageUploadService.UploadProgress] = []
        
        // When
        _ = try await uploadService.uploadImage(
            testImage,
            messageId: "msg-123",
            conversationId: "conv-456"
        ) { progress in
            progressUpdates.append(progress)
        }
        
        // Then
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertEqual(progressUpdates.first?.status, .preparing)
        XCTAssertEqual(progressUpdates.last?.status, .completed)
        XCTAssertTrue(progressUpdates.contains { $0.status == .uploading })
    }
    
    // MARK: - Compression
    func testUploadImage_CompressesImageBeforeUpload() async throws {
        // Given: Large image
        let largeImage = createLargeTestImage(sizeKB: 5000) // 5MB
        
        // When
        _ = try await uploadService.uploadImage(
            largeImage,
            messageId: "msg-123",
            conversationId: "conv-456"
        ) { _ in }
        
        // Then
        let uploadedSize = mockStorage.lastUploadedDataSize
        XCTAssertLessThan(uploadedSize, 1500 * 1024) // ~1.5MB max after compression
    }
    
    // MARK: - Error Handling
    func testUploadImage_HandlesNetworkError() async {
        // Given
        mockStorage.simulateNetworkError = true
        
        // When/Then
        do {
            _ = try await uploadService.uploadImage(
                testImage,
                messageId: "msg-123",
                conversationId: "conv-456"
            ) { _ in }
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testUploadImage_RetriesOnFailure() async throws {
        // Given: Fail first 2 attempts, succeed on 3rd
        mockStorage.failureCount = 2
        
        // When
        let url = try await uploadService.uploadImage(
            testImage,
            messageId: "msg-123",
            conversationId: "conv-456"
        ) { _ in }
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(mockStorage.uploadAttempts, 3)
    }
    
    // MARK: - Cancellation
    func testCancelUpload_StopsOngoingUpload() async throws {
        // Given: Start upload
        let messageId = "msg-123"
        Task {
            try await uploadService.uploadImage(
                testImage,
                messageId: messageId,
                conversationId: "conv-456"
            ) { _ in }
        }
        
        // When: Cancel immediately
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        uploadService.cancelUpload(messageId: messageId)
        
        // Then
        XCTAssertTrue(mockStorage.uploadCancelled)
    }
    
    // MARK: - Concurrent Uploads
    func testUploadImage_SupportsConcurrentUploads() async throws {
        // Given: Multiple images
        let images = (0..<5).map { _ in createTestImage() }
        
        // When: Upload concurrently
        let urls = try await withThrowingTaskGroup(of: String.self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    try await self.uploadService.uploadImage(
                        image,
                        messageId: "msg-\(index)",
                        conversationId: "conv-456"
                    ) { _ in }
                }
            }
            
            var results: [String] = []
            for try await url in group {
                results.append(url)
            }
            return results
        }
        
        // Then
        XCTAssertEqual(urls.count, 5)
        XCTAssertEqual(Set(urls).count, 5) // All unique URLs
    }
    
    // MARK: - Storage Path
    func testUploadImage_UsesCorrectStoragePath() async throws {
        // Given
        let messageId = "msg-123"
        let conversationId = "conv-456"
        
        // When
        _ = try await uploadService.uploadImage(
            testImage,
            messageId: messageId,
            conversationId: conversationId
        ) { _ in }
        
        // Then
        let expectedPath = "images/\(conversationId)/\(messageId).jpg"
        XCTAssertEqual(mockStorage.lastUploadPath, expectedPath)
    }
    
    // MARK: - Helper Methods
    private func createTestImage() -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: 100, height: 100))
        defer { UIGraphicsEndImageContext() }
        UIColor.blue.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createLargeTestImage(sizeKB: Int) -> UIImage {
        // Create image of specified size
    }
}
```

**Mock Storage Service:**
```swift
class MockStorageService {
    var lastUploadedDataSize: Int = 0
    var lastUploadPath: String?
    var simulateNetworkError = false
    var failureCount = 0
    var uploadAttempts = 0
    var uploadCancelled = false
    
    func upload(data: Data, path: String) async throws -> String {
        uploadAttempts += 1
        lastUploadPath = path
        lastUploadedDataSize = data.count
        
        if uploadCancelled {
            throw CancellationError()
        }
        
        if simulateNetworkError || uploadAttempts <= failureCount {
            throw URLError(.networkConnectionLost)
        }
        
        return "https://storage.example.com/\(path)"
    }
}
```

**Acceptance Criteria:**
- All tests pass
- Code coverage > 80%
- Tests run in < 10 seconds
- Mock storage works correctly
- Edge cases covered (large images, failures, cancellation)
- Concurrent uploads tested

---

### PR-19: Firebase Setup Documentation
**Dependencies:** PR-1, PR-4  
**Priority:** Low

**Objective:**
Create comprehensive documentation for setting up Firebase Realtime Database and Storage.

**Files to Create:**
- `FIREBASE_SETUP.md`

**Content:**
```markdown
# Firebase Setup Guide

## Overview
This app uses three Firebase services:
1. **Firestore** - Message and conversation storage (already configured)
2. **Realtime Database** - Typing indicators (ephemeral data)
3. **Storage** - Image and profile picture hosting

## Prerequisites
- Firebase project created
- iOS app registered in Firebase Console
- `GoogleService-Info.plist` downloaded and added to project

---

## 1. Enable Firebase Realtime Database

### Step 1: Create Database
1. Go to Firebase Console → Your Project
2. Navigate to **Build** → **Realtime Database**
3. Click **Create Database**
4. Choose database location (use same region as Firestore)
5. Start in **test mode** (we'll add security rules next)

### Step 2: Security Rules
1. In Realtime Database console, go to **Rules** tab
2. Replace with the following:

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

3. Click **Publish**

### Step 3: Get Database URL
1. In Realtime Database overview, copy the database URL
2. Format: `https://YOUR-PROJECT.firebaseio.com`
3. This will be used in the app (already configured in Firebase SDK)

---

## 2. Enable Firebase Storage

### Step 1: Create Storage Bucket
1. Go to Firebase Console → Your Project
2. Navigate to **Build** → **Storage**
3. Click **Get Started**
4. Choose storage location (use same region as Firestore)
5. Start in **test mode** (we'll add security rules next)

### Step 2: Security Rules
1. In Storage console, go to **Rules** tab
2. Replace with the following:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures: Users can only write their own, anyone authenticated can read
    match /profile_pictures/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024 // Max 5MB
                   && request.resource.contentType.matches('image/.*');
    }
    
    // Message images: Authenticated users can write, participants can read
    match /images/{conversationId}/{messageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024 // Max 10MB
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

3. Click **Publish**

### Step 3: CORS Configuration (Optional, for web access)
If you need web access to images, configure CORS:

1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
2. Create `cors.json`:
```json
[
  {
    "origin": ["*"],
    "method": ["GET"],
    "maxAgeSeconds": 3600
  }
]
```
3. Run: `gsutil cors set cors.json gs://YOUR-BUCKET.appspot.com`

---

## 3. Update Xcode Project

### Step 1: Add Firebase Storage SDK
1. In Xcode, go to **File** → **Add Package Dependencies**
2. Search: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: 10.0.0 or later
4. Add libraries:
   - FirebaseStorage
   - FirebaseDatabase

### Step 2: Update Firebase Initialization
Already done in `swift_demoApp.swift`:
```swift
FirebaseApp.configure()
```

This automatically configures all Firebase services.

---

## 4. Verify Setup

### Test Realtime Database
Run this in any view to test:
```swift
import FirebaseDatabase

func testRealtimeDB() {
    let ref = Database.database().reference()
    ref.child("test").setValue("Hello Firebase!")
    ref.child("test").observe(.value) { snapshot in
        print("Value: \(snapshot.value ?? "nil")")
    }
}
```

### Test Storage
Run this to test image upload:
```swift
import FirebaseStorage

func testStorage() async throws {
    let storage = Storage.storage()
    let storageRef = storage.reference()
    let testRef = storageRef.child("test/test.txt")
    let data = "Hello Firebase Storage!".data(using: .utf8)!
    try await testRef.putDataAsync(data)
    print("Upload successful!")
}
```

---

## 5. Monitoring and Limits

### Usage Quotas (Free Tier)
- **Realtime Database**: 1GB storage, 10GB/month downloads
- **Storage**: 5GB storage, 1GB/day downloads

### Monitor Usage
1. Go to Firebase Console
2. Navigate to **Usage and billing**
3. Set up billing alerts (recommended)

### Rate Limiting
If you hit rate limits:
1. Implement client-side throttling
2. Cache aggressively
3. Consider upgrading to Blaze plan

---

## Troubleshooting

### Error: "Permission denied"
- Check security rules are published
- Verify user is authenticated
- Check file size limits

### Error: "Network request failed"
- Check internet connection
- Verify Firebase services enabled
- Check firewall/proxy settings

### Error: "Storage bucket not configured"
- Ensure GoogleService-Info.plist is up to date
- Re-download if you recently enabled Storage

---

## Security Best Practices

1. **Never use test mode in production**
2. **Implement proper authentication checks**
3. **Set file size limits** (already in rules)
4. **Validate file types** (already in rules)
5. **Monitor for abuse** (unusual activity patterns)
6. **Enable App Check** for additional security

---

## Additional Resources

- [Firebase Realtime Database Docs](https://firebase.google.com/docs/database)
- [Firebase Storage Docs](https://firebase.google.com/docs/storage)
- [Security Rules Guide](https://firebase.google.com/docs/rules)
```

**Acceptance Criteria:**
- Documentation is clear and comprehensive
- Step-by-step instructions provided
- Security rules included
- Troubleshooting section helpful
- Easy to follow for new developers

---

### PR-20: Feature Documentation and README Updates
**Dependencies:** All previous PRs  
**Priority:** Low

**Objective:**
Update README and create feature documentation for new capabilities.

**Files to Modify:**
- `README.md`

**Files to Create:**
- `FEATURES.md`

**README.md Updates:**
Add new features section:
```markdown
## Features

### Core Messaging
- ✅ One-on-one chat
- ✅ Group chat (3+ participants)
- ✅ Real-time message delivery (<200ms)
- ✅ Offline message queueing
- ✅ Message persistence (SwiftData)
- ✅ Optimistic UI updates
- ✅ Crash recovery

### Rich Media (NEW)
- ✅ Image messages (send/receive)
- ✅ Profile pictures
- ✅ Image compression (~1MB target)
- ✅ Progressive image loading
- ✅ Full-screen image viewer with zoom

### Real-Time Features
- ✅ Online/offline presence indicators
- ✅ Read receipts
- ✅ Typing indicators (NEW)
- ✅ Message delivery states

### UI/UX
- ✅ Avatars with initials fallback (NEW)
- ✅ Modern SwiftUI interface
- ✅ Smooth animations
- ✅ Dark mode support

### Infrastructure
- ✅ Firebase Authentication
- ✅ Firestore (messages/conversations)
- ✅ Realtime Database (typing) (NEW)
- ✅ Firebase Storage (images) (NEW)
- ✅ Network resilience
```

**FEATURES.md Content:**
```markdown
# Feature Documentation

## Typing Indicators
Users can see when someone is typing in real-time.

**Technical Details:**
- Uses Firebase Realtime Database for low latency
- Automatically clears after 5 seconds of inactivity
- Debounced to prevent network flooding
- Works in both 1-on-1 and group chats

**Display Format:**
- 1 user: "Alice is typing..."
- 2 users: "Alice and Bob are typing..."
- 3+ users: "Alice and 2 others are typing..."

---

## Image Messages
Users can send and receive images in conversations.

**Features:**
- Camera and photo library support
- Automatic compression to ~1MB
- Offline queue support
- Progressive loading with placeholders
- Full-screen viewer with zoom/pan
- Tap to view full size

**Technical Details:**
- Stored in Firebase Storage
- Local caching for performance
- Aspect ratio preserved (max 300x300pt)
- Queued when offline, uploads when online

**Permissions:**
App requests camera and photo library permissions when needed.

---

## Profile Pictures
Users can upload profile pictures visible throughout the app.

**Features:**
- Upload from camera or photo library
- Automatic compression
- Initials fallback (colored background)
- Cached for performance

**Where Displayed:**
- Conversation list
- Chat navigation header (1-on-1 only)
- User selection screens
- Settings/Profile tab

**Management:**
Upload or change via Settings → Profile → "Change Photo"

---

## Technical Architecture

### Services
- **TypingService**: Manages typing status broadcasts
- **ImageUploadService**: Handles image uploads to Storage
- **ImageCompressor**: Compresses images for optimal size
- **ImageFileManager**: Manages local image cache

### Models
- **MessageEntity**: Extended to support image messages
- **User**: Extended with profileImageUrl field

### Views
- **AvatarView**: Reusable avatar component
- **ImageMessageView**: Displays image messages
- **FullScreenImageView**: Full-screen image viewer
- **ChatHeaderView**: Shows recipient info with avatar

---

## Performance Characteristics

- **Typing indicator latency**: <500ms
- **Image upload time**: <10s for 3MB image (good network)
- **Image compression**: 5MB → ~1MB in <2s
- **Image caching**: Instant display on second view

---

## Known Limitations

1. **Image size**: Max 10MB (enforced by Firebase Storage rules)
2. **Video**: Not supported yet
3. **Image editing**: No built-in editing tools
4. **Multi-image**: One image per message
5. **GIFs**: Static images only (no animation)

---

## Future Enhancements

- Video messages
- Image editing (crop, filters)
- Multi-image messages
- GIF support
- Voice messages
```

**Acceptance Criteria:**
- README updated with new features
- FEATURES.md is comprehensive
- Technical details accurate
- Easy to understand for developers
- Known limitations documented

---

## Implementation Guidelines

### Code Quality Standards
- Follow Swift naming conventions
- Add inline comments for complex logic
- Use SwiftUI best practices
- Implement error handling
- Use async/await for async operations
- Avoid force unwrapping (use guard/if let)

### Testing Standards
- Write tests before implementation (TDD recommended)
- Aim for >80% code coverage for services
- Test edge cases and error conditions
- Use mocks for Firebase services
- Tests should run fast (<10s for full suite)

### Git Workflow
- Create feature branch from main
- Branch naming: `feature/pr-{number}-{description}`
- Commit messages: Clear and descriptive
- PR description: Include testing steps
- Request review before merging
- Squash commits when merging

### Performance Considerations
- Profile with Instruments before/after
- Watch for memory leaks (especially with images)
- Test on older devices (iPhone X, iOS 15)
- Monitor Firebase usage quotas
- Implement proper image caching

### Security Checklist
- Never commit API keys or secrets
- Validate all user inputs
- Check Firebase security rules
- Handle permissions properly
- Test unauthorized access scenarios

---

## Rollout Plan

### Phase 1: Foundation (PRs 1-7)
**Week 1-2**
- Set up infrastructure (Firebase services)
- Implement core services (Typing, ImageUpload)
- Update data models

**Deliverable:** Services and models ready, not yet in UI

### Phase 2: UI Integration (PRs 8-11)
**Week 3-4**
- Integrate image picker
- Add image message display
- Implement image viewer
- Add offline queue support

**Deliverable:** Users can send/receive images

### Phase 3: Profile Pictures (PRs 12-16)
**Week 5**
- Add profile picture upload
- Implement AvatarView
- Display avatars throughout app

**Deliverable:** Profile pictures visible everywhere

### Phase 4: Testing & Docs (PRs 17-20)
**Week 6**
- Write unit tests
- Create documentation
- Final testing and bug fixes

**Deliverable:** Production-ready with tests and docs

---

## Success Metrics

### Feature Adoption
- % of users who upload profile pictures
- % of messages that include images
- Typing indicator engagement

### Performance Metrics
- Average typing indicator latency
- Average image upload time
- Image cache hit rate
- App launch time impact

### Reliability Metrics
- Image upload success rate
- Typing indicator reliability
- Crash rate (should not increase)
- Firebase quota usage

### User Experience
- User surveys on new features
- Support ticket volume
- Feature usage analytics

---

## Risk Management

### High Risk
1. **Firebase costs** - Monitor usage, set billing alerts
2. **Large image uploads** - Enforce compression and limits
3. **Storage space** - Implement cleanup for old images

### Medium Risk
1. **Performance impact** - Profile with Instruments, optimize
2. **Network usage** - Compress aggressively, cache properly
3. **User privacy** - Clear permissions, secure rules

### Low Risk
1. **UI bugs** - Thorough testing on multiple devices
2. **Edge cases** - Unit tests cover edge cases
3. **Migration issues** - Test with existing data

### Mitigation Strategies
- Gradual rollout (beta testing)
- Feature flags for quick disable
- Monitoring and alerts
- Rollback plan for each PR

---

## Appendix: PR Checklist Template

Use this checklist for each PR:

```markdown
## PR Checklist

### Code Quality
- [ ] Code follows Swift style guide
- [ ] No force unwrapping
- [ ] Proper error handling
- [ ] Comments added for complex logic
- [ ] No hardcoded strings (use constants)

### Testing
- [ ] Unit tests written (if applicable)
- [ ] Manual testing completed
- [ ] Tested on device (not just simulator)
- [ ] Tested offline/online scenarios
- [ ] No regressions in existing features

### Documentation
- [ ] Code documented
- [ ] README updated (if needed)
- [ ] PR description complete
- [ ] Testing steps provided

### Firebase
- [ ] Security rules reviewed
- [ ] Usage quotas checked
- [ ] No API keys committed

### Performance
- [ ] No memory leaks
- [ ] No performance regressions
- [ ] Profiled with Instruments (if UI changes)

### Review
- [ ] Self-reviewed code
- [ ] Peer review requested
- [ ] All comments addressed
- [ ] CI checks passing
```

---

*End of Task Overview Document*

