//
//  MessageInputView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//  Updated for PR-8: Added image picker support
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    var onSendImage: ((UIImage) -> Void)? = nil // PR-8: Callback for image messages
    var onTextChange: ((String) -> Void)? = nil // PR-3: Optional callback for typing indicator
    
    // In Vue: this would be v-model:focused or defineModel('focused')
    @FocusState.Binding var isFocused: Bool
    
    // PR-8: Image picker state
    @State private var showingImagePicker = false
    @State private var showingImageSource = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // PR-8: Image picker button
            // In Vue: <button @click="showImagePicker">📷</button>
            Button(action: { showingImageSource = true }) {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .disabled(onSendImage == nil) // Disable if no image handler
            
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isFocused)
                .onTapGesture {
                    // Force focus when tapped
                    // In Vue: emit('update:focused', true)
                    isFocused = true
                }
                .onChange(of: text) { oldValue, newValue in
                    // PR-3: Notify about text changes for typing indicator
                    // In Vue: @update:modelValue="onTextChange"
                    onTextChange?(newValue)
                }
            
            Button(action: {
                print("🔵 [MessageInputView] Send button pressed with text: '\(text)'")
                onSend()
                print("🔵 [MessageInputView] onSend() completed")
                // PR-3: Stop typing when sending message
                onTextChange?("")
                isFocused = true // Keep keyboard open after sending
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty ? .gray : .blue)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        // PR-8: Image source selection dialog
        // In Vue: <Modal v-if="showImageSource">
        .confirmationDialog("Choose Photo Source", isPresented: $showingImageSource) {
            Button("Take Photo") {
                checkCameraPermission()
            }
            Button("Choose from Library") {
                checkPhotoLibraryPermission()
            }
            Button("Cancel", role: .cancel) {}
        }
        // PR-8: Image picker sheet
        // In Vue: <ImagePicker v-if="showImagePicker" v-model="selectedImage" />
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: imageSourceType)
        }
        // PR-8: Handle selected image
        // In Vue: watch(selectedImage, (img) => { if (img) onSendImage(img) })
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                print("📷 [MessageInputView] Image selected, calling onSendImage")
                onSendImage?(image)
                selectedImage = nil // Reset for next time
            }
        }
    }
    
    // MARK: - Permission Handling
    
    /// Check camera permission and open camera if granted
    /// In Vue: const checkCamera = async () => { ... }
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
    
    /// Check photo library permission and open library if granted
    /// In Vue: const checkPhotoLibrary = async () => { ... }
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
}

