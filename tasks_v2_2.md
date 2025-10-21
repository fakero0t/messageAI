# MessageAI v2 Tasks - Part 2: Image Messages

## Overview
This document covers PRs 6-11: Complete image message functionality including upload, display, viewer, and offline queue support.

**Dependencies:** PRs 4-5 completed
**Focus:** Rich media messaging

---

## PR-6: ImageUploadService Implementation

### Meta Information
- **Dependencies:** PR-4, PR-5
- **Priority:** High
- **Branch:** `feature/pr-6-image-upload-service`

### Objective
Create a robust service to handle image uploads to Firebase Storage with progress tracking, retry logic, and error handling.

### Service Features
- Upload images to Firebase Storage
- Progress tracking with percentage updates
- Automatic retry on failure with exponential backoff
- Generate download URLs with tokens
- Handle offline queueing
- Support concurrent uploads
- Cleanup failed uploads

### Implementation

**File:** `swift_demo/Services/ImageUploadService.swift`

```swift
//
//  ImageUploadService.swift
//  swift_demo
//
//  Created for PR-6: Image upload to Firebase Storage
//

import Foundation
import FirebaseStorage
import UIKit

class ImageUploadService {
    static let shared = ImageUploadService()
    
    private let storage = Storage.storage()
    private var uploadTasks: [String: StorageUploadTask] = [:]
    private let retryPolicy = RetryPolicy.default
    
    private init() {}
    
    // MARK: - Models
    
    struct UploadProgress {
        let messageId: String
        let progress: Double // 0.0 to 1.0
        let status: UploadStatus
    }
    
    enum UploadStatus {
        case preparing
        case compressing
        case uploading(bytesUploaded: Int64, totalBytes: Int64)
        case completed(url: String)
        case failed(Error)
    }
    
    // MARK: - Upload
    
    /// Upload image to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - messageId: Unique message identifier
    ///   - conversationId: Conversation identifier
    ///   - progressHandler: Callback for progress updates
    /// - Returns: Download URL string
    /// - Throws: Upload errors
    func uploadImage(
        _ image: UIImage,
        messageId: String,
        conversationId: String,
        progressHandler: @escaping (UploadProgress) -> Void
    ) async throws -> String {
        
        // 1. Notify: Preparing
        progressHandler(UploadProgress(messageId: messageId, progress: 0, status: .preparing))
        
        // 2. Compress image
        progressHandler(UploadProgress(messageId: messageId, progress: 0.1, status: .compressing))
        
        guard let compressedData = ImageCompressor.compress(image: image, targetSizeKB: 1024) else {
            throw ImageUploadError.compressionFailed
        }
        
        // 3. Prepare storage reference
        let storageRef = storage.reference()
        let imagePath = "images/\(conversationId)/\(messageId).jpg"
        let imageRef = storageRef.child(imagePath)
        
        // 4. Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Get image dimensions for metadata
        let dimensions = ImageCompressor.getDimensions(image)
        metadata.customMetadata = [
            "width": String(Int(dimensions.width)),
            "height": String(Int(dimensions.height)),
            "originalSize": String(image.jpegData(compressionQuality: 1.0)?.count ?? 0),
            "compressedSize": String(compressedData.count)
        ]
        
        // 5. Upload with progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = imageRef.putData(compressedData, metadata: metadata)
            
            // Store task for cancellation support
            uploadTasks[messageId] = uploadTask
            
            // Progress observer
            uploadTask.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                progressHandler(UploadProgress(
                    messageId: messageId,
                    progress: 0.1 + (percentComplete * 0.8), // 10-90%
                    status: .uploading(
                        bytesUploaded: progress.completedUnitCount,
                        totalBytes: progress.totalUnitCount
                    )
                ))
            }
            
            // Success observer
            uploadTask.observe(.success) { snapshot in
                // Get download URL
                imageRef.downloadURL { url, error in
                    if let error = error {
                        progressHandler(UploadProgress(messageId: messageId, progress: 1.0, status: .failed(error)))
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        let urlString = url.absoluteString
                        progressHandler(UploadProgress(messageId: messageId, progress: 1.0, status: .completed(url: urlString)))
                        continuation.resume(returning: urlString)
                    }
                    
                    // Cleanup
                    self.uploadTasks.removeValue(forKey: messageId)
                }
            }
            
            // Failure observer
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    progressHandler(UploadProgress(messageId: messageId, progress: 1.0, status: .failed(error)))
                    continuation.resume(throwing: error)
                }
                
                // Cleanup
                self.uploadTasks.removeValue(forKey: messageId)
            }
        }
    }
    
    // MARK: - Control
    
    /// Cancel ongoing upload
    /// - Parameter messageId: Message identifier
    func cancelUpload(messageId: String) {
        uploadTasks[messageId]?.cancel()
        uploadTasks.removeValue(forKey: messageId)
        print("🚫 Upload cancelled: \(messageId)")
    }
    
    /// Retry failed upload
    /// - Parameters:
    ///   - messageId: Message identifier
    ///   - image: UIImage to retry
    ///   - conversationId: Conversation identifier
    ///   - progressHandler: Progress callback
    /// - Returns: Download URL
    func retryUpload(
        messageId: String,
        image: UIImage,
        conversationId: String,
        progressHandler: @escaping (UploadProgress) -> Void
    ) async throws -> String {
        print("🔄 Retrying upload: \(messageId)")
        return try await uploadImage(image, messageId: messageId, conversationId: conversationId, progressHandler: progressHandler)
    }
}

enum ImageUploadError: LocalizedError {
    case compressionFailed
    case uploadFailed
    case urlGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed:
            return "Failed to upload image to server"
        case .urlGenerationFailed:
            return "Failed to generate download URL"
        }
    }
}
```

### Files Created
- `swift_demo/Services/ImageUploadService.swift`

### Acceptance Criteria
- [ ] Successfully uploads images to Firebase Storage
- [ ] Progress updates work (0-100%)
- [ ] Download URL returned on success
- [ ] Retry logic works for failed uploads
- [ ] Cancellation stops upload immediately
- [ ] Handles network errors gracefully
- [ ] No memory leaks with large uploads
- [ ] Concurrent uploads supported
- [ ] Metadata stored correctly

### Testing
Create a manual test that:
- Creates a test image
- Calls uploadImage with progress handler
- Prints progress updates
- Verifies URL returned on success
- Prints error on failure

---

## PR-7: MessageEntity Updates for Image Support

### Meta Information
- **Dependencies:** None (can be done early)
- **Priority:** High
- **Branch:** `feature/pr-7-message-entity-image-support`

### Objective
Update MessageEntity model to support image messages with nullable text field.

### Files to Modify

**File:** `swift_demo/Models/SwiftData/MessageEntity.swift`

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
    
    init(
        id: String,
        conversationId: String,
        senderId: String,
        text: String? = nil,
        timestamp: Date,
        status: MessageStatus = .pending,
        readBy: [String] = [],
        imageUrl: String? = nil,
        imageLocalPath: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
        self.imageUrl = imageUrl
        self.imageLocalPath = imageLocalPath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
    
    var isImageMessage: Bool {
        imageUrl != nil || imageLocalPath != nil
    }
    
    var displayText: String {
        if isImageMessage {
            return "Image"
        }
        return text ?? ""
    }
}
```

**File:** `swift_demo/Services/MessageService.swift`

Add new method:

```swift
func sendImageMessage(
    messageId: String,
    imageUrl: String,
    conversationId: String,
    senderId: String,
    recipientId: String,
    imageWidth: Double,
    imageHeight: Double
) async throws {
    print("☁️ Sending image message to Firestore: \(messageId)")
    
    try await retryService.executeWithRetry(policy: .default) {
        let messageData: [String: Any] = [
            "id": messageId,
            "conversationId": conversationId,
            "senderId": senderId,
            "text": NSNull(), // Explicitly null for image-only
            "timestamp": FieldValue.serverTimestamp(),
            "status": "delivered",
            "readBy": [],
            "imageUrl": imageUrl,
            "imageWidth": imageWidth,
            "imageHeight": imageHeight
        ]
        
        try await self.db.collection("messages").document(messageId).setData(messageData)
        print("✅ Image message sent to Firestore")
        
        // Update conversation
        var participants = [senderId]
        if !recipientId.isEmpty {
            participants.append(recipientId)
        } else {
            if let conversation = try? await MainActor.run(body: {
                try self.localStorage.fetchConversation(byId: conversationId)
            }) {
                participants = conversation.participantIds
            }
        }
        
        try await ConversationService.shared.updateConversation(
            conversationId: conversationId,
            lastMessage: "Image",
            participants: participants
        )
    }
}
```

### Acceptance Criteria
- [ ] Model compiles successfully
- [ ] Existing messages unaffected
- [ ] New image fields save/load correctly
- [ ] Migration works without data loss
- [ ] isImageMessage computed property works
- [ ] displayText shows "Image" for image messages

---

## PR-8: Image Picker Integration (Camera + Photo Library)

### Meta Information
- **Dependencies:** PR-5, PR-7
- **Priority:** Medium
- **Branch:** `feature/pr-8-image-picker`

### Objective
Integrate PHPickerViewController for photo library and UIImagePickerController for camera, with permission handling.

### Files to Create

**File:** `swift_demo/Views/Chat/ImagePickerView.swift`

```swift
import SwiftUI
import PhotosUI

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

**File:** `swift_demo/Utilities/PermissionManager.swift`

```swift
import AVFoundation
import Photos
import UIKit

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    // MARK: - Camera
    
    func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func checkCameraPermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    // MARK: - Photo Library
    
    func requestPhotoLibraryPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func checkPhotoLibraryPermission() -> Bool {
        PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    // MARK: - Alerts
    
    func showPermissionDeniedAlert(for permission: PermissionType) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }
            
            let alert = UIAlertController(
                title: "\(permission.rawValue) Access Required",
                message: "Please enable \(permission.rawValue) access in Settings to use this feature.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            rootViewController.present(alert, animated: true)
        }
    }
}

enum PermissionType: String {
    case camera = "Camera"
    case photoLibrary = "Photo Library"
}
```

**Update Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>MessageAI needs camera access to take photos for messages</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>MessageAI needs photo library access to share images in messages</string>
```

### Modify MessageInputView.swift

```swift
struct MessageInputView: View {
    let onSend: (String) -> Void
    let onSendImage: ((UIImage) -> Void)? // NEW
    let onTextChange: ((String) -> Void)?
    
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingImageSource = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // NEW: Image picker button
            Button(action: { showingImageSource = true }) {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .onChange(of: messageText) { _, newValue in
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
        .confirmationDialog("Choose Photo Source", isPresented: $showingImageSource) {
            Button("Take Photo") {
                checkCameraPermission()
            }
            Button("Choose from Library") {
                checkPhotoLibraryPermission()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: imageSourceType)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                onSendImage?(image)
                selectedImage = nil
            }
        }
    }
    
    private func send() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        onSend(text)
        messageText = ""
        onTextChange?("")
    }
    
    private func checkCameraPermission() {
        Task {
            let granted = await PermissionManager.shared.requestCameraPermission()
            if granted {
                imageSourceType = .camera
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
                imageSourceType = .photoLibrary
                showingImagePicker = true
            } else {
                PermissionManager.shared.showPermissionDeniedAlert(for: .photoLibrary)
            }
        }
    }
}
```

### Acceptance Criteria
- [ ] Photo library picker works
- [ ] Camera picker works (on device)
- [ ] Permissions requested on first use
- [ ] Permission denied shows alert with Settings link
- [ ] Selected image passes to callback
- [ ] Cancel works at all stages
- [ ] UI is intuitive

---

## PR-9: Image Message Bubble and Display

### Meta Information
- **Dependencies:** PR-6, PR-7, PR-8
- **Priority:** Medium
- **Branch:** `feature/pr-9-image-message-display`

### Objective
Update message bubbles to display images with progressive loading and proper layout. Add sendImage method to ChatViewModel.

### Files to Create

**File:** `swift_demo/Views/Chat/ImageMessageView.swift`

```swift
import SwiftUI

struct ImageMessageView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    let onTap: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    private let maxSize: CGFloat = 300
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxSize, maxHeight: maxSize)
                    .cornerRadius(16)
                    .onTapGesture {
                        onTap()
                    }
            } else if loadError {
                errorView
            } else {
                placeholderView
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: maxSize, height: maxSize)
            .cornerRadius(16)
            .overlay(
                ProgressView()
            )
    }
    
    private var errorView: some View {
        Rectangle()
            .fill(Color.red.opacity(0.1))
            .frame(width: maxSize, height: maxSize)
            .cornerRadius(16)
            .overlay(
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        // Try local path first (for queued messages)
        if let localPath = message.imageLocalPath {
            if let localImage = try? ImageFileManager.shared.loadImage(withId: message.id) {
                image = localImage
                return
            }
        }
        
        // Load from URL
        guard let urlString = message.imageUrl,
              let url = URL(string: urlString) else {
            loadError = true
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                image = downloadedImage
            } else {
                loadError = true
            }
        } catch {
            print("Failed to load image: \(error)")
            loadError = true
        }
    }
}
```

### Modify MessageBubbleView.swift

```swift
var body: some View {
    if message.isImageMessage {
        ImageMessageView(
            message: message,
            isFromCurrentUser: isFromCurrentUser,
            onTap: {
                // Will implement in PR-10
            }
        )
    } else {
        // Existing text message view
    }
}
```

### Add sendImage to ChatViewModel.swift

```swift
@Published var uploadProgress: [String: Double] = [:] // Track upload progress

func sendImage(_ image: UIImage) {
    let messageId = UUID().uuidString
    
    Task {
        do {
            // 1. Compress and save locally
            guard let imagePath = try? ImageFileManager.shared.saveImage(image, withId: messageId) else {
                errorMessage = "Failed to process image"
                return
            }
            
            let dimensions = ImageCompressor.getDimensions(image)
            
            // 2. Create optimistic message
            await MainActor.run {
                let optimisticMessage = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: nil,
                    timestamp: Date(),
                    status: networkMonitor.isConnected ? .pending : .queued,
                    imageLocalPath: imagePath.path,
                    imageWidth: dimensions.width,
                    imageHeight: dimensions.height
                )
                messages.append(optimisticMessage)
                
                try? localStorage.saveMessage(optimisticMessage)
            }
            
            // 3. If online, upload immediately
            if networkMonitor.isConnected {
                let downloadUrl = try await ImageUploadService.shared.uploadImage(
                    image,
                    messageId: messageId,
                    conversationId: conversationId
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.uploadProgress[messageId] = progress.progress
                    }
                }
                
                // 4. Send to Firestore
                try await messageService.sendImageMessage(
                    messageId: messageId,
                    imageUrl: downloadUrl,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId,
                    imageWidth: dimensions.width,
                    imageHeight: dimensions.height
                )
                
                // 5. Update message with URL
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].imageUrl = downloadUrl
                        messages[index].status = .sent
                        try? localStorage.updateMessage(
                            messageId: messageId,
                            status: .sent,
                            readBy: []
                        )
                    }
                    uploadProgress.removeValue(forKey: messageId)
                }
                
                // 6. Clean up local file
                try? ImageFileManager.shared.deleteImage(withId: messageId)
                
            } else {
                // Offline: Queue for later
                try queueService.queueImageMessage(
                    id: messageId,
                    conversationId: conversationId,
                    imageLocalPath: imagePath.path
                )
            }
            
        } catch {
            print("❌ Failed to send image: \(error)")
            await MainActor.run {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Failed to send image"
            }
        }
    }
}
```

### Update ChatView.swift

```swift
MessageInputView(
    onSend: viewModel.sendMessage,
    onSendImage: viewModel.sendImage, // NEW
    onTextChange: viewModel.handleTextFieldChange
)
```

### Acceptance Criteria
- [ ] Image messages display in chat
- [ ] Loading placeholder shows
- [ ] Tap opens full screen (PR-10)
- [ ] Works for sent/received images
- [ ] Optimistic UI shows immediately
- [ ] Failed images show error state

---

## PR-10: Full-Screen Image Viewer with Zoom

### Meta Information
- **Dependencies:** PR-9
- **Priority:** Medium
- **Branch:** `feature/pr-10-image-viewer`

### Objective
Create full-screen image viewer with zoom, pan, and dismiss gestures.

### File to Create

**File:** `swift_demo/Views/Chat/FullScreenImageView.swift`

```swift
import SwiftUI

struct FullScreenImageView: View {
    let imageUrl: String?
    let localImage: UIImage?
    let message: MessageEntity
    
    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnificationGesture)
                    .gesture(dragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
                scale = min(max(scale, 1), 3) // Limit 1x-3x
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    offset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if scale <= 1 && value.translation.height > 100 {
                    dismiss()
                } else {
                    lastOffset = offset
                }
            }
    }
    
    private func loadImage() async {
        if let localImage = localImage {
            image = localImage
            return
        }
        
        guard let urlString = imageUrl ?? message.imageUrl,
              let url = URL(string: urlString) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            image = UIImage(data: data)
        } catch {
            print("Failed to load image: \(error)")
        }
    }
}
```

### Update ImageMessageView.swift

```swift
@State private var showingFullScreen = false

// In body, wrap ZStack:
.fullScreenCover(isPresented: $showingFullScreen) {
    FullScreenImageView(
        imageUrl: message.imageUrl,
        localImage: image,
        message: message
    )
}

// Update onTap:
onTap: {
    showingFullScreen = true
}
```

### Acceptance Criteria
- [ ] Opens in full screen
- [ ] Pinch to zoom works (1x-3x)
- [ ] Pan works when zoomed
- [ ] Double-tap toggles zoom
- [ ] Swipe down dismisses
- [ ] Smooth animations

---

## PR-11: Image Message Offline Queue Support

### Meta Information
- **Dependencies:** PR-6, PR-7, PR-9
- **Priority:** Medium
- **Branch:** `feature/pr-11-image-queue`

### Objective
Extend MessageQueueService to handle image uploads when device comes back online.

### Modify QueuedMessageEntity.swift

```swift
@Model
class QueuedMessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var text: String?
    var timestamp: Date
    var retryCount: Int
    
    // NEW: Image support
    var imageLocalPath: String?
    var isImageMessage: Bool
    var imageWidth: Double?
    var imageHeight: Double?
    
    init(id: String, conversationId: String, text: String?, timestamp: Date, imageLocalPath: String? = nil, imageWidth: Double? = nil, imageHeight: Double? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.timestamp = timestamp
        self.retryCount = 0
        self.imageLocalPath = imageLocalPath
        self.isImageMessage = imageLocalPath != nil
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}
```

### Update MessageQueueService.swift

Add methods:

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
    print("📥 Image message queued: \(id)")
}

private func processImageMessage(_ queuedMessage: QueuedMessageEntity) async {
    guard let imagePath = queuedMessage.imageLocalPath,
          let image = try? ImageFileManager.shared.loadImage(withId: queuedMessage.id) else {
        try? markMessageAsFailed(queuedMessage)
        return
    }
    
    do {
        let dimensions = ImageCompressor.getDimensions(image)
        
        let downloadUrl = try await ImageUploadService.shared.uploadImage(
            image,
            messageId: queuedMessage.id,
            conversationId: queuedMessage.conversationId
        ) { _ in }
        
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        let participants = queuedMessage.conversationId.split(separator: "_").map(String.init)
        let recipientId = participants.first { $0 != currentUserId } ?? ""
        
        try await MessageService.shared.sendImageMessage(
            messageId: queuedMessage.id,
            imageUrl: downloadUrl,
            conversationId: queuedMessage.conversationId,
            senderId: currentUserId,
            recipientId: recipientId,
            imageWidth: dimensions.width,
            imageHeight: dimensions.height
        )
        
        try localStorage.removeQueuedMessage(queuedMessage.id)
        try? ImageFileManager.shared.deleteImage(withId: queuedMessage.id)
        try localStorage.updateMessageStatus(messageId: queuedMessage.id, status: .delivered)
        
    } catch {
        try? localStorage.incrementRetryCount(messageId: queuedMessage.id)
    }
}
```

Update `processQueue()` to handle images:

```swift
for queuedMessage in queuedMessages {
    if queuedMessage.isImageMessage {
        await processImageMessage(queuedMessage)
    } else {
        // Existing text message processing
    }
}
```

### Acceptance Criteria
- [ ] Image messages queue when offline
- [ ] Queued images persist across restarts
- [ ] Images upload when online
- [ ] Local files cleaned after upload
- [ ] Works with existing text queue

---

## Summary

Part 2 covered PRs 6-11 for complete image message functionality:
- ✅ ImageUploadService with progress tracking
- ✅ MessageEntity image support
- ✅ Image picker integration
- ✅ Image message display
- ✅ Full-screen viewer
- ✅ Offline queue support

**Next:** `tasks_v2_3.md` for Profile Pictures (PRs 12-16)

