//
//  MainView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var conversationToNavigateTo: String?
    
    var body: some View {
        let isLearningModeEnabled = AuthenticationService.shared.currentUser?.georgianLearningMode ?? false
        
        ZStack {
            TabView(selection: $selectedTab) {
                ConversationListView(conversationToNavigateTo: $conversationToNavigateTo)
                    .tabItem {
                        Label("Chats", systemImage: "message")
                    }
                    .tag(0)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .tag(1)
                
                // Conditionally show Practice tab based on Georgian Learning Mode
                if isLearningModeEnabled {
                    PracticeView()
                        .tabItem {
                            Label("Practice", systemImage: "book.fill")
                        }
                        .tag(2)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    print("📲 Navigating to conversation: \(conversationId)")
                    selectedTab = 0 // Switch to Chats tab
                    conversationToNavigateTo = conversationId
                }
            }
            
            // In-app notification banner overlay
            VStack {
                NotificationBannerView()
                Spacer()
            }
            .allowsHitTesting(true)
        }
    }
}

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
                // PR-14: Profile Picture Section
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
                            Text("Username")
                            Spacer()
                            Text("@\(user.username)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            OnlineStatusView(isOnline: user.online, lastSeen: user.lastSeen)
                        }
                    }
                }
                
                // Georgian Learning Mode - Master Toggle
                Section("Georgian Learning") {
                    Toggle("Georgian Learning Mode", isOn: Binding(
                        get: { currentUser?.georgianLearningMode ?? false },
                        set: { enabled in
                            guard let userId = currentUser?.id else { return }
                            Task {
                                do {
                                    try await UserService.shared.updateGeorgianLearningMode(
                                        userId: userId, 
                                        enabled: enabled
                                    )
                                    if !enabled {
                                        // Reset services when disabling
                                        await MainActor.run {
                                            GeoSuggestionService.shared.resetSession()
                                            EnglishTranslationSuggestionService.shared.resetSession()
                                        }
                                    }
                                } catch {
                                    print("❌ Failed to update Georgian Learning Mode: \(error)")
                                }
                            }
                        }
                    ))
                    
                    Text("Enable to access practice exercises and receive Georgian vocabulary suggestions while chatting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Test Notifications Section
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
                
                // Logout Section
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
        
        print("📸 [ProfileView] Starting profile image upload...")
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                let url = try await UserService.shared.uploadProfileImage(userId: userId, image: image)
                print("✅ [ProfileView] Profile image uploaded: \(url)")
                
                await MainActor.run {
                    isUploading = false
                    selectedImage = nil
                    
                    // Force refresh current user
                    Task {
                        if let updatedUser = try? await UserService.shared.fetchUser(byId: userId) {
                            await MainActor.run {
                                AuthenticationService.shared.currentUser = updatedUser
                                print("✅ [ProfileView] Current user refreshed with new profile image")
                            }
                        }
                    }
                }
            } catch {
                print("❌ [ProfileView] Upload error: \(error)")
                await MainActor.run {
                    isUploading = false
                    uploadError = "Failed to upload image"
                }
            }
        }
    }
    
    private func deleteProfileImage() {
        guard let userId = currentUser?.id else { return }
        
        print("🗑️ [ProfileView] Deleting profile image...")
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                try await UserService.shared.deleteProfileImage(userId: userId)
                print("✅ [ProfileView] Profile image deleted")
                
                await MainActor.run {
                    isUploading = false
                    
                    // Force refresh current user
                    Task {
                        if let updatedUser = try? await UserService.shared.fetchUser(byId: userId) {
                            await MainActor.run {
                                AuthenticationService.shared.currentUser = updatedUser
                                print("✅ [ProfileView] Current user refreshed (image removed)")
                            }
                        }
                    }
                }
            } catch {
                print("❌ [ProfileView] Delete error: \(error)")
                await MainActor.run {
                    isUploading = false
                    uploadError = "Failed to delete image"
                }
            }
        }
    }
}

