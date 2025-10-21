//
//  ImageUploadTestView.swift
//  swift_demo
//
//  Test view for ImageUploadService
//
//  Vue Analogy: This is like a test page with file input and progress bar
//  that shows upload progress and handles success/failure
//

import SwiftUI
import FirebaseAuth

struct ImageUploadTestView: View {
    @State private var testResults: [String] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadStatus: String = ""
    @State private var testImage: UIImage?
    @State private var uploadedImageURL: String?
    
    private let uploadService = ImageUploadService.shared
    private let testMessageId = UUID().uuidString
    private let testConversationId = "test_conversation_123"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Image Upload Test")
                    .font(.title)
                    .bold()
                
                // Progress Indicator
                if isUploading {
                    VStack(spacing: 12) {
                        ProgressView(value: uploadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                        
                        Text(uploadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(uploadProgress * 100))%")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button("Create Test Image") {
                        createTestImage()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUploading)
                    
                    Button("Upload Image") {
                        Task {
                            await testUpload()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(testImage == nil || isUploading)
                    
                    Button("Cancel Upload") {
                        cancelUpload()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!isUploading)
                    
                    Button("Test Retry") {
                        Task {
                            await testRetry()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUploading)
                    
                    Button("Clear Results") {
                        testResults.removeAll()
                        testImage = nil
                        uploadedImageURL = nil
                        uploadProgress = 0
                        uploadStatus = ""
                    }
                    .buttonStyle(.bordered)
                }
                
                // Image Preview
                if let image = testImage {
                    VStack {
                        Text("Test Image:")
                            .font(.headline)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .border(Color.gray)
                        Text("\(Int(image.size.width))x\(Int(image.size.height))")
                            .font(.caption)
                    }
                }
                
                // Uploaded Image URL
                if let url = uploadedImageURL {
                    VStack(alignment: .leading) {
                        Text("Uploaded Image URL:")
                            .font(.headline)
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.green)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
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
                
                // Service Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Service Status:")
                        .font(.headline)
                    Text("Active uploads: \(uploadService.activeUploadCount)")
                        .font(.caption)
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
    
    /// Create a test image
    func createTestImage() {
        log("ℹ️ Creating test image...")
        
        let size = CGSize(width: 1500, height: 1500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Gradient background
            let colors = [UIColor.orange.cgColor, UIColor.red.cgColor, UIColor.purple.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0, 0.5, 1])!
            
            context.cgContext.drawLinearGradient(gradient,
                                                  start: .zero,
                                                  end: CGPoint(x: size.width, y: size.height),
                                                  options: [])
            
            // Add text
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: 80)
            ]
            let text = "UPLOAD TEST"
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }
        
        testImage = image
        
        if let data = image.jpegData(compressionQuality: 1.0) {
            let sizeMB = Double(data.count) / 1024.0 / 1024.0
            log("✅ Test image created: \(Int(image.size.width))x\(Int(image.size.height)), \(String(format: "%.2f", sizeMB))MB")
        }
    }
    
    /// Test upload
    func testUpload() async {
        guard let image = testImage else {
            log("❌ No test image. Create one first.")
            return
        }
        
        // Check authentication
        guard Auth.auth().currentUser != nil else {
            log("❌ No authenticated user. Please log in first.")
            return
        }
        
        log("ℹ️ Starting upload test...")
        log("   Message ID: \(testMessageId)")
        log("   Conversation ID: \(testConversationId)")
        
        isUploading = true
        uploadProgress = 0
        uploadStatus = "Preparing..."
        
        do {
            let url = try await uploadService.uploadImage(
                image,
                messageId: testMessageId,
                conversationId: testConversationId,
                progressHandler: { [self] progress in
                    // Update UI on main thread
                    self.uploadProgress = progress.progress
                    self.uploadStatus = progress.status.description
                    
                    // Log progress milestones
                    if case .uploading(let uploaded, let total) = progress.status {
                        let percent = Int(Double(uploaded) / Double(total) * 100)
                        if percent % 25 == 0 {
                            self.log("   Progress: \(percent)%")
                        }
                    }
                }
            )
            
            uploadedImageURL = url
            log("✅ Upload succeeded!")
            log("   URL: \(url)")
            
        } catch {
            log("❌ Upload failed: \(error.localizedDescription)")
        }
        
        isUploading = false
    }
    
    /// Test cancel
    func cancelUpload() {
        log("ℹ️ Cancelling upload...")
        uploadService.cancelUpload(messageId: testMessageId)
        isUploading = false
        uploadProgress = 0
        uploadStatus = "Cancelled"
        log("✅ Upload cancelled")
    }
    
    /// Test retry
    func testRetry() async {
        guard let image = testImage else {
            log("❌ No test image. Create one first.")
            return
        }
        
        guard Auth.auth().currentUser != nil else {
            log("❌ No authenticated user. Please log in first.")
            return
        }
        
        log("ℹ️ Testing retry...")
        
        isUploading = true
        uploadProgress = 0
        uploadStatus = "Retrying..."
        
        do {
            let url = try await uploadService.retryUpload(
                messageId: UUID().uuidString, // New ID for retry test
                image: image,
                conversationId: testConversationId,
                progressHandler: { [self] progress in
                    self.uploadProgress = progress.progress
                    self.uploadStatus = progress.status.description
                }
            )
            
            uploadedImageURL = url
            log("✅ Retry succeeded!")
            log("   URL: \(url)")
            
        } catch {
            log("❌ Retry failed: \(error.localizedDescription)")
        }
        
        isUploading = false
    }
    
    func log(_ message: String) {
        testResults.append(message)
        print("🧪 [ImageUploadTest] \(message)")
    }
}

#Preview {
    ImageUploadTestView()
}

