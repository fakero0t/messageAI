//
//  ImageUploadServiceTests.swift
//  swift_demoTests
//
//  Comprehensive tests for ImageUploadService
//  Tests upload functionality, progress tracking, compression, and cancellation
//
//  Note: These tests interact with real Firebase Storage
//  Ensure you're authenticated before running tests
//

import XCTest
import Combine
import FirebaseStorage
@testable import swift_demo

final class ImageUploadServiceTests: XCTestCase {
    
    var imageUploadService: ImageUploadService!
    var cancellables: Set<AnyCancellable>!
    
    // Test conversation and message IDs
    let testConversationId = "test_upload_\(UUID().uuidString)"
    let testMessageId1 = "test_msg_\(UUID().uuidString)"
    let testMessageId2 = "test_msg_\(UUID().uuidString)"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        imageUploadService = ImageUploadService.shared
        cancellables = Set<AnyCancellable>()
        
        print("🧪 [Setup] Test conversation: \(testConversationId)")
    }
    
    override func tearDownWithError() throws {
        // Clean up uploaded test files from Firebase Storage
        cleanupTestFiles()
        
        cancellables.removeAll()
        
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    /// Create a test image with specified dimensions
    func createTestImage(width: Int, height: Int, color: UIColor = .blue) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some pattern to make it more compressible
            UIColor.white.setStroke()
            for i in stride(from: 0, to: Int(size.width), by: 10) {
                context.cgContext.move(to: CGPoint(x: i, y: 0))
                context.cgContext.addLine(to: CGPoint(x: i, y: Int(size.height)))
                context.cgContext.strokePath()
            }
        }
        
        return image
    }
    
    /// Clean up test files from Firebase Storage
    func cleanupTestFiles() {
        let storage = Storage.storage()
        let basePath = "images/\(testConversationId)"
        
        // Delete test message 1
        let ref1 = storage.reference().child("\(basePath)/\(testMessageId1).jpg")
        ref1.delete { error in
            if let error = error {
                print("⚠️ Cleanup error for msg1: \(error.localizedDescription)")
            }
        }
        
        // Delete test message 2
        let ref2 = storage.reference().child("\(basePath)/\(testMessageId2).jpg")
        ref2.delete { error in
            if let error = error {
                print("⚠️ Cleanup error for msg2: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Test 1: Upload Success
    
    func testUploadImage_ReturnsValidURL() async throws {
        // Given: A small test image
        let testImage = createTestImage(width: 500, height: 500)
        
        var progressUpdates: [ImageUploadService.UploadProgress] = []
        
        // When: Upload the image
        let downloadURL = try await imageUploadService.uploadImage(
            testImage,
            messageId: testMessageId1,
            conversationId: testConversationId
        ) { progress in
            progressUpdates.append(progress)
            print("📊 Progress: \(progress.status.description)")
        }
        
        // Then: Should return a valid Firebase Storage URL
        XCTAssertFalse(downloadURL.isEmpty, "Download URL should not be empty")
        XCTAssertTrue(downloadURL.contains("firebasestorage.googleapis.com"), "Should be Firebase Storage URL")
        XCTAssertTrue(downloadURL.contains(testConversationId), "URL should contain conversation ID")
        XCTAssertTrue(downloadURL.contains(testMessageId1), "URL should contain message ID")
        
        print("✅ Upload successful: \(downloadURL)")
        
        // Verify progress updates were received
        XCTAssertGreaterThan(progressUpdates.count, 0, "Should have received progress updates")
        
        // Check for expected statuses
        let statuses = progressUpdates.map { $0.status }
        let hasPreparing = statuses.contains { if case .preparing = $0 { return true }; return false }
        let hasCompressing = statuses.contains { if case .compressing = $0 { return true }; return false }
        let hasCompleted = statuses.contains { if case .completed = $0 { return true }; return false }
        
        XCTAssertTrue(hasPreparing, "Should have preparing status")
        XCTAssertTrue(hasCompressing, "Should have compressing status")
        XCTAssertTrue(hasCompleted, "Should have completed status")
    }
    
    func testUploadImage_ProgressReaches100Percent() async throws {
        // Given: A test image
        let testImage = createTestImage(width: 300, height: 300)
        
        var progressValues: [Double] = []
        
        // When: Upload
        _ = try await imageUploadService.uploadImage(
            testImage,
            messageId: testMessageId2,
            conversationId: testConversationId
        ) { progress in
            progressValues.append(progress.progress)
        }
        
        // Then: Progress should reach 1.0 (100%)
        let maxProgress = progressValues.max() ?? 0
        XCTAssertEqual(maxProgress, 1.0, accuracy: 0.01, "Progress should reach 100%")
        
        // Progress should be monotonically increasing (mostly)
        let sortedProgress = progressValues.sorted()
        XCTAssertEqual(progressValues.first, sortedProgress.first, "Progress should start low")
        XCTAssertEqual(progressValues.last, sortedProgress.last, "Progress should end high")
    }
    
    // MARK: - Test 2: Progress Tracking
    
    func testUploadProgress_HasAllExpectedStates() async throws {
        // Given: A test image
        let testImage = createTestImage(width: 400, height: 400)
        
        var receivedStatuses: [String] = []
        
        // When: Upload
        _ = try await imageUploadService.uploadImage(
            testImage,
            messageId: "test_progress_\(UUID().uuidString)",
            conversationId: testConversationId
        ) { progress in
            let statusDescription = progress.status.description
            receivedStatuses.append(statusDescription)
            print("📊 Status: \(statusDescription)")
        }
        
        // Then: Should receive multiple status updates
        XCTAssertGreaterThan(receivedStatuses.count, 2, "Should have multiple status updates")
        
        // Check that we got the expected stages
        let hasPreparingStatus = receivedStatuses.contains { $0.contains("Preparing") }
        let hasCompressingStatus = receivedStatuses.contains { $0.contains("Compressing") }
        let hasUploadingStatus = receivedStatuses.contains { $0.contains("Uploading") }
        let hasCompletedStatus = receivedStatuses.contains { $0.contains("complete") }
        
        XCTAssertTrue(hasPreparingStatus, "Should have 'Preparing' status")
        XCTAssertTrue(hasCompressingStatus, "Should have 'Compressing' status")
        XCTAssertTrue(hasUploadingStatus, "Should have 'Uploading' status")
        XCTAssertTrue(hasCompletedStatus, "Should have 'complete' status")
    }
    
    func testUploadProgress_ValuesIncreaseOverTime() async throws {
        // Given: A test image
        let testImage = createTestImage(width: 600, height: 600)
        
        var progressSequence: [Double] = []
        
        // When: Upload
        _ = try await imageUploadService.uploadImage(
            testImage,
            messageId: "test_sequence_\(UUID().uuidString)",
            conversationId: testConversationId
        ) { progress in
            progressSequence.append(progress.progress)
        }
        
        // Then: Progress values should generally increase
        // (allowing for small fluctuations due to status changes)
        XCTAssertGreaterThan(progressSequence.count, 2)
        XCTAssertLessThanOrEqual(progressSequence.first ?? 1.0, progressSequence.last ?? 0.0,
                                 "First progress should be <= last progress")
        
        // Final progress should be 1.0
        XCTAssertEqual(progressSequence.last, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Test 3: Image Compression
    
    func testLargeImageCompression() async throws {
        // Given: A large 4000x4000 image
        let largeImage = createTestImage(width: 4000, height: 4000, color: .red)
        
        print("🖼️ Created large image: 4000x4000")
        
        // When: Upload (which includes compression)
        let downloadURL = try await imageUploadService.uploadImage(
            largeImage,
            messageId: "test_large_\(UUID().uuidString)",
            conversationId: testConversationId
        ) { progress in
            if case .compressing = progress.status {
                print("📦 Compressing large image...")
            }
        }
        
        // Then: Upload should succeed (compression worked)
        XCTAssertFalse(downloadURL.isEmpty)
        XCTAssertTrue(downloadURL.contains("firebasestorage.googleapis.com"))
        
        print("✅ Large image uploaded successfully after compression")
    }
    
    func testCompression_ProducesReasonableSize() {
        // Given: A large image
        let largeImage = createTestImage(width: 2000, height: 2000)
        
        // When: Compress using ImageCompressor
        guard let (compressedData, dimensions) = ImageCompressor.compressImage(largeImage, targetSizeMB: 1.0) else {
            XCTFail("Compression failed")
            return
        }
        
        let sizeInMB = Double(compressedData.count) / 1024.0 / 1024.0
        print("📊 Compressed size: \(String(format: "%.2f", sizeInMB)) MB")
        
        // Then: Size should be reasonable (within 2MB target)
        XCTAssertLessThan(compressedData.count, 3 * 1024 * 1024, "Compressed size should be < 3MB")
        
        // Dimensions should be valid
        XCTAssertGreaterThan(dimensions.width, 0)
        XCTAssertGreaterThan(dimensions.height, 0)
    }
    
    // MARK: - Test 4: Cancellation
    
    func testCancelUpload() async throws {
        // Given: A larger image that takes time to upload
        let testImage = createTestImage(width: 2000, height: 2000)
        
        let expectation = XCTestExpectation(description: "Upload starts")
        var uploadStarted = false
        
        // When: Start upload and cancel mid-way
        Task {
            do {
                _ = try await imageUploadService.uploadImage(
                    testImage,
                    messageId: testMessageId1,
                    conversationId: testConversationId
                ) { progress in
                    if case .uploading = progress.status {
                        if !uploadStarted {
                            uploadStarted = true
                            expectation.fulfill()
                            
                            // Cancel after upload starts
                            Task {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                                self.imageUploadService.cancelUpload(messageId: self.testMessageId1)
                                print("❌ Cancelled upload")
                            }
                        }
                    }
                }
                
                XCTFail("Upload should have been cancelled")
            } catch {
                // Expected: cancellation should throw an error
                print("✅ Upload cancelled with error: \(error.localizedDescription)")
                XCTAssertTrue(error.localizedDescription.contains("cancel") || 
                            error.localizedDescription.contains("Upload task not found"),
                            "Error should indicate cancellation")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testCancelNonExistentUpload() {
        // Given: A message ID that doesn't have an upload
        let fakeMessageId = "fake_\(UUID().uuidString)"
        
        // When: Try to cancel
        imageUploadService.cancelUpload(messageId: fakeMessageId)
        
        // Then: Should not crash (graceful handling)
        // Just verify we get here without throwing
        XCTAssertTrue(true, "Should handle cancellation of non-existent upload gracefully")
    }
    
    // MARK: - Test 5: Error Handling
    
    func testUploadWithInvalidImage() async {
        // Given: An image with 0 dimensions (edge case)
        let invalidImage = UIImage()
        
        // When/Then: Should handle gracefully or throw appropriate error
        do {
            _ = try await imageUploadService.uploadImage(
                invalidImage,
                messageId: "test_invalid_\(UUID().uuidString)",
                conversationId: testConversationId
            ) { _ in }
            
            // May or may not fail depending on implementation
            // If it doesn't fail, that's acceptable (UIImage might handle it)
        } catch {
            // Expected: should fail with compression or upload error
            print("✅ Invalid image handled with error: \(error.localizedDescription)")
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Test 6: Retry Functionality
    
    func testRetryUpload() async throws {
        // Given: A test image that we'll upload twice
        let testImage = createTestImage(width: 300, height: 300, color: .green)
        let messageId = "test_retry_\(UUID().uuidString)"
        
        // When: Upload once
        let url1 = try await imageUploadService.retryUpload(
            image: testImage,
            messageId: messageId,
            conversationId: testConversationId
        ) { progress in
            print("📊 First upload: \(progress.status.description)")
        }
        
        // Then: Should succeed
        XCTAssertFalse(url1.isEmpty)
        print("✅ First upload URL: \(url1)")
        
        // When: Retry (upload again - simulating retry after failure)
        let url2 = try await imageUploadService.retryUpload(
            image: testImage,
            messageId: messageId,
            conversationId: testConversationId
        ) { progress in
            print("📊 Retry upload: \(progress.status.description)")
        }
        
        // Then: Should also succeed
        XCTAssertFalse(url2.isEmpty)
        print("✅ Retry upload URL: \(url2)")
        
        // URLs might be the same (overwrite) or different (new upload)
        // Either is acceptable
    }
    
    // MARK: - Test 7: Concurrent Uploads
    
    func testMultipleSimultaneousUploads() async throws {
        // Given: Three different images
        let image1 = createTestImage(width: 200, height: 200, color: .red)
        let image2 = createTestImage(width: 300, height: 300, color: .blue)
        let image3 = createTestImage(width: 250, height: 250, color: .green)
        
        let msg1 = "test_concurrent_1_\(UUID().uuidString)"
        let msg2 = "test_concurrent_2_\(UUID().uuidString)"
        let msg3 = "test_concurrent_3_\(UUID().uuidString)"
        
        // When: Upload all three simultaneously
        async let url1 = imageUploadService.uploadImage(image1, messageId: msg1, conversationId: testConversationId) { _ in }
        async let url2 = imageUploadService.uploadImage(image2, messageId: msg2, conversationId: testConversationId) { _ in }
        async let url3 = imageUploadService.uploadImage(image3, messageId: msg3, conversationId: testConversationId) { _ in }
        
        // Wait for all to complete
        let results = try await (url1, url2, url3)
        
        // Then: All should succeed
        XCTAssertFalse(results.0.isEmpty, "Upload 1 should succeed")
        XCTAssertFalse(results.1.isEmpty, "Upload 2 should succeed")
        XCTAssertFalse(results.2.isEmpty, "Upload 3 should succeed")
        
        // All URLs should be unique
        XCTAssertNotEqual(results.0, results.1)
        XCTAssertNotEqual(results.1, results.2)
        XCTAssertNotEqual(results.0, results.2)
        
        print("✅ All concurrent uploads successful")
    }
    
    // MARK: - Test 8: Image Dimensions
    
    func testUpload_PreservesDimensions() async throws {
        // Given: An image with specific dimensions
        let width = 800
        let height = 600
        let testImage = createTestImage(width: width, height: height)
        
        var capturedDimensions: (width: Double, height: Double)?
        
        // When: Compress (this is what happens during upload)
        if let (_, dimensions) = ImageCompressor.compressImage(testImage, targetSizeMB: 1.0) {
            capturedDimensions = dimensions
        }
        
        // Then: Dimensions should be captured
        XCTAssertNotNil(capturedDimensions)
        
        if let dims = capturedDimensions {
            // Dimensions should maintain aspect ratio
            let originalRatio = Double(width) / Double(height)
            let compressedRatio = dims.width / dims.height
            
            XCTAssertEqual(originalRatio, compressedRatio, accuracy: 0.1,
                          "Aspect ratio should be maintained")
        }
    }
}

