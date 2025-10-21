//
//  StorageTestView.swift
//  swift_demo
//
//  Manual test view for Firebase Storage operations
//  Tests upload, download, and delete functionality
//
//  Vue Analogy: This is like a test page in your Vue app with buttons
//  that call storage.ref().put(), storage.ref().getDownloadURL(), etc.
//

import SwiftUI
import FirebaseStorage
import FirebaseAuth

struct StorageTestView: View {
    @State private var testResults: [String] = []
    @State private var isLoading = false
    @State private var uploadedImageURL: String?
    @State private var downloadedImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Firebase Storage Test")
                    .font(.title)
                    .bold()
                
                if isLoading {
                    ProgressView("Testing...")
                }
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button("Test Upload Image") {
                        testUpload()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button("Test Download Image") {
                        testDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || uploadedImageURL == nil)
                    
                    Button("Test Delete Image") {
                        testDelete()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || uploadedImageURL == nil)
                    
                    Button("Run All Tests") {
                        runAllTests()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isLoading)
                    
                    Button("Clear Results") {
                        testResults.removeAll()
                        uploadedImageURL = nil
                        downloadedImage = nil
                    }
                    .buttonStyle(.bordered)
                }
                
                // Downloaded Image Preview
                if let image = downloadedImage {
                    VStack {
                        Text("Downloaded Image:")
                            .font(.headline)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .border(Color.gray)
                    }
                }
                
                // Test Results
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Results:")
                        .font(.headline)
                    
                    ForEach(testResults.indices, id: \.self) { index in
                        let result = testResults[index]
                        HStack(alignment: .top) {
                            Text(result.hasPrefix("✅") ? "✅" : result.hasPrefix("❌") ? "❌" : "ℹ️")
                            Text(result.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "❌ ", with: "").replacingOccurrences(of: "ℹ️ ", with: ""))
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    // MARK: - Test Functions
    
    /// Run all tests in sequence
    /// In Vue: const runAllTests = async () => { ... }
    func runAllTests() {
        Task {
            await MainActor.run {
                isLoading = true
                testResults.removeAll()
                uploadedImageURL = nil
                downloadedImage = nil
            }
            
            // Test 1: Upload
            await testUploadAsync()
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Test 2: Download
            if uploadedImageURL != nil {
                await testDownloadAsync()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            // Test 3: Delete
            if uploadedImageURL != nil {
                await testDeleteAsync()
            }
            
            await MainActor.run {
                isLoading = false
                log("✅ All tests complete!")
            }
        }
    }
    
    /// Test image upload to Firebase Storage
    func testUpload() {
        Task {
            await testUploadAsync()
        }
    }
    
    func testUploadAsync() async {
        await MainActor.run {
            isLoading = true
            log("ℹ️ Starting upload test...")
        }
        
        // Check authentication
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                log("❌ No authenticated user. Please log in first.")
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            log("ℹ️ User authenticated: \(currentUser.uid)")
        }
        
        // Create a test image (100x100 red square)
        guard let testImage = createTestImage() else {
            await MainActor.run {
                log("❌ Failed to create test image")
                isLoading = false
            }
            return
        }
        
        // Compress to JPEG
        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            await MainActor.run {
                log("❌ Failed to compress image")
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            log("ℹ️ Image size: \(imageData.count / 1024)KB")
        }
        
        // Create storage reference
        let storage = Storage.storage()
        let messageId = UUID().uuidString
        let conversationId = "test_conversation"
        let storagePath = "images/\(conversationId)/\(messageId).jpg"
        let storageRef = storage.reference().child(storagePath)
        
        await MainActor.run {
            log("ℹ️ Upload path: \(storagePath)")
        }
        
        do {
            // Upload
            // In Vue: await uploadBytes(ref(storage, path), imageData)
            let metadata = try await storageRef.putDataAsync(imageData)
            
            await MainActor.run {
                log("✅ Upload succeeded!")
                log("ℹ️ Content type: \(metadata.contentType ?? "unknown")")
                uploadedImageURL = storagePath
            }
            
        } catch {
            await MainActor.run {
                log("❌ Upload failed: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Test image download from Firebase Storage
    func testDownload() {
        Task {
            await testDownloadAsync()
        }
    }
    
    func testDownloadAsync() async {
        await MainActor.run {
            isLoading = true
            log("ℹ️ Starting download test...")
        }
        
        guard let path = uploadedImageURL else {
            await MainActor.run {
                log("❌ No uploaded image to download. Upload first.")
                isLoading = false
            }
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child(path)
        
        await MainActor.run {
            log("ℹ️ Download path: \(path)")
        }
        
        do {
            // Download
            // In Vue: const data = await getBytes(ref(storage, path))
            let data = try await storageRef.data(maxSize: 10 * 1024 * 1024) // 10MB max
            
            if let image = UIImage(data: data) {
                await MainActor.run {
                    log("✅ Download succeeded!")
                    log("ℹ️ Image size: \(image.size.width)x\(image.size.height)")
                    downloadedImage = image
                }
            } else {
                await MainActor.run {
                    log("❌ Failed to create UIImage from downloaded data")
                }
            }
            
        } catch {
            await MainActor.run {
                log("❌ Download failed: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Test image deletion from Firebase Storage
    func testDelete() {
        Task {
            await testDeleteAsync()
        }
    }
    
    func testDeleteAsync() async {
        await MainActor.run {
            isLoading = true
            log("ℹ️ Starting delete test...")
        }
        
        guard let path = uploadedImageURL else {
            await MainActor.run {
                log("❌ No uploaded image to delete. Upload first.")
                isLoading = false
            }
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child(path)
        
        await MainActor.run {
            log("ℹ️ Delete path: \(path)")
        }
        
        do {
            // Delete
            // In Vue: await deleteObject(ref(storage, path))
            try await storageRef.delete()
            
            await MainActor.run {
                log("✅ Delete succeeded!")
                uploadedImageURL = nil
                downloadedImage = nil
            }
            
        } catch {
            await MainActor.run {
                log("❌ Delete failed: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Helper Functions
    
    /// Create a simple test image (red square)
    /// In Vue: this would be like creating a blob or canvas image
    func createTestImage() -> UIImage? {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Fill with red color
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add white text
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: 20)
            ]
            let text = "TEST"
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }
        
        return image
    }
    
    /// Log a test result
    /// In Vue: console.log() but we show it in the UI
    func log(_ message: String) {
        testResults.append(message)
        print("📦 [Storage Test] \(message)")
    }
}

// MARK: - Preview

#Preview {
    StorageTestView()
}

