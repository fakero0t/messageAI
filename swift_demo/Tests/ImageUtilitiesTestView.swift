//
//  ImageUtilitiesTestView.swift
//  swift_demo
//
//  Test view for ImageCompressor and ImageFileManager
//
//  Vue Analogy: This is like a test page in your Vue app with buttons
//  that test image compression, file save/load/delete, thumbnails, etc.
//

import SwiftUI

struct ImageUtilitiesTestView: View {
    @State private var testResults: [String] = []
    @State private var isLoading = false
    @State private var testImage: UIImage?
    @State private var compressedImage: UIImage?
    @State private var thumbnailImage: UIImage?
    @State private var loadedImage: UIImage?
    
    private let testImageId = "test_image_\(UUID().uuidString)"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Image Utilities Test")
                    .font(.title)
                    .bold()
                
                if isLoading {
                    ProgressView("Testing...")
                }
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button("Create Test Image (5MB)") {
                        createLargeTestImage()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button("Test Compression") {
                        testCompression()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(testImage == nil || isLoading)
                    
                    Button("Test Thumbnail") {
                        testThumbnail()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(testImage == nil || isLoading)
                    
                    Button("Test Save/Load/Delete") {
                        testSaveLoadDelete()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(compressedImage == nil || isLoading)
                    
                    Button("Test Cache Info") {
                        testCacheInfo()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    
                    Button("Run All Tests") {
                        runAllTests()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isLoading)
                    
                    Button("Clear Results") {
                        testResults.removeAll()
                        testImage = nil
                        compressedImage = nil
                        thumbnailImage = nil
                        loadedImage = nil
                    }
                    .buttonStyle(.bordered)
                }
                
                // Image Previews
                VStack(spacing: 16) {
                    if let image = testImage {
                        VStack {
                            Text("Original Image:")
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
                    
                    if let image = compressedImage {
                        VStack {
                            Text("Compressed Image:")
                                .font(.headline)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .border(Color.green)
                            Text("\(Int(image.size.width))x\(Int(image.size.height))")
                                .font(.caption)
                        }
                    }
                    
                    if let image = thumbnailImage {
                        VStack {
                            Text("Thumbnail:")
                                .font(.headline)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .border(Color.blue)
                        }
                    }
                    
                    if let image = loadedImage {
                        VStack {
                            Text("Loaded from Disk:")
                                .font(.headline)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .border(Color.orange)
                        }
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
    
    func runAllTests() {
        Task {
            await MainActor.run {
                isLoading = true
                testResults.removeAll()
            }
            
            createLargeTestImage()
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            testCompression()
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            testThumbnail()
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            testSaveLoadDelete()
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            testCacheInfo()
            
            await MainActor.run {
                isLoading = false
                log("✅ All tests complete!")
            }
        }
    }
    
    /// Create a large test image (~5MB)
    func createLargeTestImage() {
        log("ℹ️ Creating large test image...")
        
        // Create a 3000x3000 image with gradient
        let size = CGSize(width: 3000, height: 3000)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Create gradient background
            let colors = [UIColor.blue.cgColor, UIColor.purple.cgColor, UIColor.systemPink.cgColor]
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
                .font: UIFont.boldSystemFont(ofSize: 120)
            ]
            let text = "TEST IMAGE"
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
    
    /// Test image compression
    func testCompression() {
        guard let image = testImage else {
            log("❌ No test image. Create one first.")
            return
        }
        
        log("ℹ️ Testing compression...")
        
        // Get original size
        if let originalData = image.jpegData(compressionQuality: 1.0) {
            let originalMB = Double(originalData.count) / 1024.0 / 1024.0
            log("   Original: \(String(format: "%.2f", originalMB))MB")
        }
        
        // Compress to 1MB
        if let compressedData = ImageCompressor.compress(image: image, targetSizeKB: 1024) {
            let compressedMB = Double(compressedData.count) / 1024.0 / 1024.0
            log("   Compressed: \(String(format: "%.2f", compressedMB))MB")
            
            if let compressed = UIImage(data: compressedData) {
                compressedImage = compressed
                log("✅ Compression successful: \(Int(compressed.size.width))x\(Int(compressed.size.height))")
            }
        } else {
            log("❌ Compression failed")
        }
    }
    
    /// Test thumbnail generation
    func testThumbnail() {
        guard let image = testImage else {
            log("❌ No test image. Create one first.")
            return
        }
        
        log("ℹ️ Testing thumbnail generation...")
        
        if let thumbnail = ImageCompressor.generateThumbnail(from: image, size: CGSize(width: 100, height: 100)) {
            thumbnailImage = thumbnail
            log("✅ Thumbnail generated: \(Int(thumbnail.size.width))x\(Int(thumbnail.size.height))")
        } else {
            log("❌ Thumbnail generation failed")
        }
    }
    
    /// Test save/load/delete cycle
    func testSaveLoadDelete() {
        guard let image = compressedImage ?? testImage else {
            log("❌ No image to test. Create and compress one first.")
            return
        }
        
        log("ℹ️ Testing save/load/delete cycle...")
        
        let fileManager = ImageFileManager.shared
        
        // Test Save
        do {
            let url = try fileManager.saveImage(image, withId: testImageId)
            log("✅ Image saved to: \(url.lastPathComponent)")
            
            // Verify exists
            if fileManager.imageExists(withId: testImageId) {
                log("✅ Image exists on disk")
            } else {
                log("❌ Image not found after save")
                return
            }
            
            // Test Load
            if let loaded = try fileManager.loadImage(withId: testImageId) {
                loadedImage = loaded
                log("✅ Image loaded: \(Int(loaded.size.width))x\(Int(loaded.size.height))")
            } else {
                log("❌ Failed to load image")
                return
            }
            
            // Test Delete
            try fileManager.deleteImage(withId: testImageId)
            log("✅ Image deleted")
            
            // Verify deleted
            if !fileManager.imageExists(withId: testImageId) {
                log("✅ Image no longer exists")
            } else {
                log("❌ Image still exists after delete")
            }
            
        } catch {
            log("❌ Error: \(error.localizedDescription)")
        }
    }
    
    /// Test cache info methods
    func testCacheInfo() {
        log("ℹ️ Testing cache info...")
        
        let fileManager = ImageFileManager.shared
        
        let count = fileManager.getCachedImageCount()
        let size = fileManager.getFormattedCacheSize()
        
        log("✅ Cache info:")
        log("   Files: \(count)")
        log("   Size: \(size)")
    }
    
    func log(_ message: String) {
        testResults.append(message)
        print("🧪 [ImageUtilitiesTest] \(message)")
    }
}

#Preview {
    ImageUtilitiesTestView()
}

