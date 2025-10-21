# MessageAI v2 Tasks - Part 3: Profile Pictures

## Overview
This document covers PRs 12-16: Profile picture functionality including upload, display, and avatar components.

**Dependencies:** PR-4 completed (Firebase Storage)
**Focus:** User profile pictures with avatar display

---

## PR-12: User Model and Profile Storage Updates

### Meta Information
- **Dependencies:** PR-4
- **Priority:** Medium
- **Branch:** `feature/pr-12-user-model-profile-storage`

### Objective
Update User model to include profile picture URL and add UserService methods for profile uploads.

### Files to Modify

#### 1. User.swift

**File:** `swift_demo/Models/User.swift`

```swift
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    var profileImageUrl: String? // NEW
    
    var statusText: String {
        if online {
            return "Online"
        } else if let lastSeen = lastSeen {
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
    
    // NEW: Generate initials for avatar fallback
    var initials: String {
        let components = displayName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return String(initials).uppercased()
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

#### 2. UserService.swift

**File:** `swift_demo/Services/UserService.swift`

Add these methods:

```swift
import FirebaseStorage

// MARK: - Profile Picture Management

/// Upload profile picture to Firebase Storage
/// - Parameters:
///   - userId: User ID
///   - image: UIImage to upload
/// - Returns: Download URL string
/// - Throws: Upload or compression errors
func uploadProfileImage(userId: String, image: UIImage) async throws -> String {
    print("📸 Uploading profile picture for user: \(userId)")
    
    // 1. Compress image (smaller target for profile pics)
    guard let compressedData = ImageCompressor.compress(image: image, targetSizeKB: 500) else {
        throw ProfileImageError.compressionFailed
    }
    
    // 2. Upload to Firebase Storage
    let storageRef = Storage.storage().reference()
    let profileImageRef = storageRef.child("profile_pictures/\(userId).jpg")
    
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    
    _ = try await profileImageRef.putDataAsync(compressedData, metadata: metadata)
    
    // 3. Get download URL
    let downloadUrl = try await profileImageRef.downloadURL()
    let urlString = downloadUrl.absoluteString
    
    // 4. Update Firestore user document
    try await db.collection("users").document(userId).updateData([
        "profileImageUrl": urlString
    ])
    
    // 5. Update local user object if current user
    if var currentUser = AuthenticationService.shared.currentUser,
       currentUser.id == userId {
        currentUser.profileImageUrl = urlString
        AuthenticationService.shared.currentUser = currentUser
    }
    
    print("✅ Profile picture uploaded: \(urlString)")
    return urlString
}

/// Delete profile picture from Firebase Storage
/// - Parameter userId: User ID
/// - Throws: Deletion errors
func deleteProfileImage(userId: String) async throws {
    print("🗑️ Deleting profile picture for user: \(userId)")
    
    // 1. Delete from Storage
    let storageRef = Storage.storage().reference()
    let profileImageRef = storageRef.child("profile_pictures/\(userId).jpg")
    
    do {
        try await profileImageRef.delete()
    } catch {
        // Ignore if file doesn't exist
        print("⚠️ Profile picture may not exist: \(error)")
    }
    
    // 2. Update Firestore (remove field)
    try await db.collection("users").document(userId).updateData([
        "profileImageUrl": FieldValue.delete()
    ])
    
    // 3. Update local user object if current user
    if var currentUser = AuthenticationService.shared.currentUser,
       currentUser.id == userId {
        currentUser.profileImageUrl = nil
        AuthenticationService.shared.currentUser = currentUser
    }
    
    print("✅ Profile picture deleted")
}

enum ProfileImageError: LocalizedError {
    case compressionFailed
    case uploadFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress profile picture"
        case .uploadFailed:
            return "Failed to upload profile picture"
        case .deleteFailed:
            return "Failed to delete profile picture"
        }
    }
}
```

### Files Modified
- `swift_demo/Models/User.swift`
- `swift_demo/Services/UserService.swift`

### Acceptance Criteria
- [ ] User model includes profileImageUrl field
- [ ] Existing users work without profile images
- [ ] uploadProfileImage function works
- [ ] Profile image URL saves to Firestore
- [ ] deleteProfileImage works
- [ ] Local user object updates correctly
- [ ] initials computed property works correctly
- [ ] No breaking changes to existing functionality

### Testing Steps

**Manual Test:**
Create test buttons to:
- Upload a test profile image
- Verify upload success with URL
- Delete profile image
- Verify delete success

**Verification:**
1. Upload image → Check Firebase Console Storage
2. Check Firestore users collection → profileImageUrl field present
3. Delete image → Field removed from Firestore
4. Test with existing users → No errors

---

## PR-13: AvatarView Component with Initials Fallback

### Meta Information
- **Dependencies:** PR-12
- **Priority:** Medium
- **Branch:** `feature/pr-13-avatar-view-component`

### Objective
Create a reusable avatar component that displays profile pictures or generated initials with colored backgrounds.

### File to Create

**File:** `swift_demo/Views/Components/AvatarView.swift`

```swift
//
//  AvatarView.swift
//  swift_demo
//
//  Created for PR-13: Reusable avatar component
//

import SwiftUI

struct AvatarView: View {
    let user: User?
    let size: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    // Generate consistent color based on user ID
    private var backgroundColor: Color {
        guard let user = user else { return .gray }
        
        let colors: [Color] = [
            .blue, .green, .orange, .purple, 
            .pink, .red, .teal, .indigo
        ]
        
        let index = abs(user.id.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
            
            if let image = image {
                // Profile picture
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let user = user {
                // Initials
                Text(user.initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
            } else {
                // Placeholder (no user)
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: user?.profileImageUrl) { _, _ in
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        guard let urlString = user?.profileImageUrl,
              let url = URL(string: urlString) else {
            image = nil
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: urlString) {
            image = cachedImage
            return
        }
        
        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                ImageCache.shared.set(downloadedImage, forKey: urlString)
                image = downloadedImage
            }
        } catch {
            print("Failed to load profile image: \(error)")
            image = nil
        }
    }
}

// MARK: - Size Presets

extension AvatarView {
    static let sizeSmall: CGFloat = 32
    static let sizeMedium: CGFloat = 48
    static let sizeLarge: CGFloat = 80
    static let sizeExtraLarge: CGFloat = 120
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}
```

### Features
- Displays profile picture if available
- Falls back to initials with colored background
- Consistent color per user (hash-based)
- Circular shape
- Configurable size
- Image caching (NSCache)
- Async image loading
- Placeholder for nil user
- Loading indicator during fetch

### Usage Examples

Use AvatarView with different size presets:
- Small (32pt): `AvatarView.sizeSmall`
- Medium (48pt): `AvatarView.sizeMedium`
- Large (80pt): `AvatarView.sizeLarge`
- Extra Large (120pt): `AvatarView.sizeExtraLarge`
- Custom size: Pass any CGFloat value
- Nil user: Shows placeholder icon

### Files Created
- `swift_demo/Views/Components/AvatarView.swift`

### Acceptance Criteria
- [ ] Displays profile picture when available
- [ ] Shows initials when no picture
- [ ] Background color consistent per user
- [ ] Circular shape maintained
- [ ] Works with different sizes
- [ ] Images cached properly (no re-downloads)
- [ ] Smooth loading (no flicker)
- [ ] Works with nil user (shows placeholder)
- [ ] Loading indicator shows during fetch
- [ ] Refreshes when profileImageUrl changes

### Testing Steps

**Test View:**
Create a test view that displays:
- AvatarView in all size presets
- Avatar with nil user (placeholder)
- Buttons to add/remove profile picture URL

**Verify:**
1. Initials display correctly (JD for John Doe)
2. Background color is consistent across sizes
3. Profile picture loads when URL added
4. Falls back to initials when URL removed
5. Nil user shows person icon
6. No memory leaks with many avatars

---

## PR-14: Profile Picture Upload in Settings

### Meta Information
- **Dependencies:** PR-12, PR-13
- **Priority:** Medium
- **Branch:** `feature/pr-14-profile-upload-settings`

### Objective
Add profile picture upload functionality to the existing ProfileView with camera/photo library options.

### File to Modify

**File:** `swift_demo/Views/MainView.swift` (ProfileView section)

Update the ProfileView struct:

```swift
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingImageSource = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showingDeleteConfirmation = false
    
    var currentUser: User? {
        AuthenticationService.shared.currentUser
    }
    
    var body: some View {
        NavigationStack {
            List {
                // NEW: Profile Picture Section
                Section {
                    VStack(spacing: 16) {
                        // Large avatar
                        AvatarView(user: currentUser, size: AvatarView.sizeExtraLarge)
                        
                        // Upload state
                        if isUploading {
                            ProgressView("Uploading...")
                        } else {
                            // Change Photo button
                            Button("Change Photo") {
                                showingImageSource = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Remove Photo button (only if has photo)
                            if currentUser?.profileImageUrl != nil {
                                Button("Remove Photo", role: .destructive) {
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                        
                        // Error message
                        if let error = uploadError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // User Information Section
                Section("Profile Information") {
                    if let user = currentUser {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.displayName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            OnlineStatusView(isOnline: user.online, lastSeen: user.lastSeen)
                        }
                        
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(user.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Test Notifications Section (keep existing)
                Section("Notifications") {
                    Button(action: {
                        NotificationService.shared.showMessageNotification(
                            conversationId: "test-123",
                            senderName: "Test User",
                            messageText: "This is a test notification!",
                            isGroup: false
                        )
                    }) {
                        HStack {
                            Spacer()
                            Text("Test System Notification")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        let notification = InAppNotification(
                            conversationId: "test-123",
                            senderName: "Test User",
                            messageText: "This is a test in-app notification banner!",
                            isGroup: false
                        )
                        InAppNotificationManager.shared.show(notification)
                    }) {
                        HStack {
                            Spacer()
                            Text("Test In-App Banner")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
                
                // Logout Section (keep existing)
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            // Image source selection
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSource) {
                Button("Take Photo") {
                    checkCameraPermission()
                }
                Button("Choose from Library") {
                    checkPhotoLibraryPermission()
                }
                Button("Cancel", role: .cancel) { }
            }
            // Image picker sheet
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage, sourceType: imageSourceType)
            }
            // Handle selected image
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    uploadProfileImage(image)
                }
            }
            // Delete confirmation
            .alert("Remove Profile Picture", isPresented: $showingDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    deleteProfileImage()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove your profile picture?")
            }
        }
    }
    
    // MARK: - Permission Checks
    
    private func checkCameraPermission() {
        Task {
            let granted = await PermissionManager.shared.requestCameraPermission()
            await MainActor.run {
                if granted {
                    imageSourceType = .camera
                    showingImagePicker = true
                } else {
                    PermissionManager.shared.showPermissionDeniedAlert(for: .camera)
                }
            }
        }
    }
    
    private func checkPhotoLibraryPermission() {
        Task {
            let granted = await PermissionManager.shared.requestPhotoLibraryPermission()
            await MainActor.run {
                if granted {
                    imageSourceType = .photoLibrary
                    showingImagePicker = true
                } else {
                    PermissionManager.shared.showPermissionDeniedAlert(for: .photoLibrary)
                }
            }
        }
    }
    
    // MARK: - Upload/Delete
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let userId = currentUser?.id else { return }
        
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                _ = try await UserService.shared.uploadProfileImage(userId: userId, image: image)
                
                await MainActor.run {
                    isUploading = false
                    selectedImage = nil
                    
                    // Force refresh current user
                    if let updatedUser = try? await UserService.shared.fetchUser(byId: userId) {
                        AuthenticationService.shared.currentUser = updatedUser
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = "Failed to upload image"
                    print("Upload error: \(error)")
                }
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
                
                await MainActor.run {
                    isUploading = false
                    
                    // Force refresh current user
                    if let updatedUser = try? await UserService.shared.fetchUser(byId: userId) {
                        AuthenticationService.shared.currentUser = updatedUser
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = "Failed to delete image"
                    print("Delete error: \(error)")
                }
            }
        }
    }
}
```

### Files Modified
- `swift_demo/Views/MainView.swift`

### Acceptance Criteria
- [ ] Profile picture displays in Settings
- [ ] "Change Photo" button works
- [ ] Camera option available on device
- [ ] Photo library option works
- [ ] Upload progress shown
- [ ] Success updates UI immediately
- [ ] "Remove Photo" button works
- [ ] Confirmation dialog for removal
- [ ] Error messages displayed clearly
- [ ] Permissions handled gracefully
- [ ] Works on both simulator and device

### Testing Steps
1. Open app → Settings tab
2. Tap "Change Photo" → Choose Library
3. Select image → Verify upload progress
4. Verify avatar updates immediately
5. Tap "Remove Photo" → Confirm
6. Verify avatar shows initials again
7. Test camera on device
8. Test permission denials (deny in Settings)

---

## PR-15: Avatar Display in Conversation List

### Meta Information
- **Dependencies:** PR-13
- **Priority:** Low
- **Branch:** `feature/pr-15-avatar-conversation-list`

### Objective
Add avatar display to conversation rows in the conversation list.

### File to Modify

**File:** `swift_demo/Views/Conversations/ConversationRowView.swift`

Update the view:

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
                // Group icon (no avatar, just colored circle with icon)
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
        .task {
            await loadConversationData()
        }
    }
    
    private var displayName: String {
        if conversation.isGroup {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "Unknown"
        }
    }
    
    private var lastMessagePreview: String {
        if lastMessage?.isImageMessage == true {
            return "📷 Image"
        }
        return lastMessage?.text ?? "No messages yet"
    }
    
    private func loadConversationData() async {
        // Load other user (for 1-on-1)
        if !conversation.isGroup {
            let otherUserId = conversation.participantIds.first { $0 != currentUserId } ?? ""
            otherUser = try? await UserService.shared.fetchUser(byId: otherUserId)
        }
        
        // Load last message
        do {
            let messages = try await MainActor.run {
                try LocalStorageService.shared.fetchMessages(for: conversation.id)
            }
            lastMessage = messages.last
        } catch {
            print("Failed to load last message: \(error)")
        }
    }
}
```

### Files Modified
- `swift_demo/Views/Conversations/ConversationRowView.swift`

### Acceptance Criteria
- [ ] Avatars display in conversation list
- [ ] 1-on-1 chats show other user's avatar
- [ ] Group chats show group icon (no avatar)
- [ ] Initials shown when no profile picture
- [ ] Image messages show "📷 Image" in preview
- [ ] Layout looks clean and professional
- [ ] No performance issues with many conversations

---

## PR-16: Avatar Display in Chat Navigation Headers

### Meta Information
- **Dependencies:** PR-13
- **Priority:** Low
- **Branch:** `feature/pr-16-avatar-chat-header`

### Objective
Add avatar display to chat navigation bar showing recipient information (1-on-1 only, not groups).

### File to Modify

**File:** `swift_demo/Views/Chat/ChatView.swift`

Update ChatHeaderView (created in PR-3):

```swift
struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var recipientUser: User?
    
    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isGroup {
                // Group: Just name, NO avatar
                VStack(alignment: .center, spacing: 2) {
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
                    
                    // Typing indicator or status
                    if let typingText = viewModel.typingText {
                        HStack(spacing: 4) {
                            Text(typingText)
                                .font(.caption)
                                .foregroundColor(.green)
                            TypingDotsView()
                        }
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
        guard !viewModel.isGroup else { return }
        
        do {
            recipientUser = try await UserService.shared.fetchUser(byId: viewModel.recipientId)
        } catch {
            print("Failed to load recipient user: \(error)")
        }
    }
}
```

### Files Modified
- `swift_demo/Views/Chat/ChatView.swift`

### Acceptance Criteria
- [ ] Avatar displays in navigation bar for 1-on-1 chats
- [ ] Group chats show name only (no avatar)
- [ ] Online status shows below name
- [ ] Typing indicator replaces status when typing
- [ ] Layout looks clean in navigation bar
- [ ] Works with different device sizes
- [ ] Avatar updates when profile picture changes

### Testing Steps
1. Open 1-on-1 chat → Verify avatar in header
2. Open group chat → Verify no avatar, just name
3. Have other user start typing → Verify typing replaces status
4. Update profile picture → Verify header avatar updates
5. Test on different devices (iPhone SE, iPhone 14 Pro Max)

---

## Summary

Part 3 covered PRs 12-16 for profile picture functionality:
- ✅ User model updates for profile storage
- ✅ AvatarView reusable component
- ✅ Profile picture upload in Settings
- ✅ Avatar display in conversation list
- ✅ Avatar display in chat headers

**Next:** `tasks_v2_4.md` for Testing & Documentation (PRs 17-20)

