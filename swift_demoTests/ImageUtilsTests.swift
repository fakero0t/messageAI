//
//  ImageUtilsTests.swift
//  swift_demoTests
//
//  Comprehensive unit tests for image utility classes:
//  - ImageCompressor (compression, resizing, thumbnails)
//  - ImageFileManager (save, load, delete)
//

import XCTest
import UIKit
@testable import swift_demo

final class ImageUtilsTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Create a test image with specified dimensions and color
    func createTestImage(width: Int, height: Int, color: UIColor = .red) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        return image
    }
    
    /// Get size of image data in bytes
    func getImageDataSize(_ image: UIImage, compressionQuality: CGFloat = 0.8) -> Int? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return data.count
    }
    
    // MARK: - ImageCompressor Tests
    
    func testImageCompression_ReducesFileSize() {
        // Given: A large image
        let largeImage = createTestImage(width: 2000, height: 2000)
        guard let originalSize = getImageDataSize(largeImage) else {
            XCTFail("Could not get original image size")
            return
        }
        
        print("Original size: \(Double(originalSize) / 1024.0 / 1024.0) MB")
        
        // When: Compress the image
        guard let (compressedData, dimensions) = ImageCompressor.compressImage(largeImage, targetSizeMB: 1.0) else {
            XCTFail("Compression failed")
            return
        }
        
        let compressedSize = compressedData.count
        print("Compressed size: \(Double(compressedSize) / 1024.0 / 1024.0) MB")
        
        // Then: Compressed size should be smaller
        XCTAssertLessThan(compressedSize, originalSize, "Compressed image should be smaller")
        
        // Should be close to target size (1MB = ~1,048,576 bytes)
        // Allow up to 2MB since it's a target, not a hard limit
        XCTAssertLessThan(compressedSize, 2 * 1024 * 1024, "Should be within reasonable size")
        
        // Dimensions should be returned
        XCTAssertGreaterThan(dimensions.width, 0)
        XCTAssertGreaterThan(dimensions.height, 0)
    }
    
    func testImageCompression_ReturnsValidImageData() {
        // Given: An image
        let image = createTestImage(width: 1000, height: 1000)
        
        // When: Compress
        guard let (compressedData, _) = ImageCompressor.compressImage(image, targetSizeMB: 1.0) else {
            XCTFail("Compression failed")
            return
        }
        
        // Then: Should be able to create UIImage from compressed data
        let reconstructedImage = UIImage(data: compressedData)
        XCTAssertNotNil(reconstructedImage, "Compressed data should be valid image data")
    }
    
    func testImageResize_MaintainsAspectRatio() {
        // Given: An image with 2:1 aspect ratio
        let image = createTestImage(width: 1000, height: 500)
        
        // When: Resize to max dimension 500
        let resized = ImageCompressor.resizeImage(image, maxDimension: 500)
        
        // Then: Should maintain 2:1 ratio
        // Max dimension is 500, so width should be 500 and height 250
        XCTAssertEqual(resized.size.width, 500, accuracy: 1.0)
        XCTAssertEqual(resized.size.height, 250, accuracy: 1.0)
        
        // Verify aspect ratio is maintained
        let originalRatio = 1000.0 / 500.0
        let resizedRatio = resized.size.width / resized.size.height
        XCTAssertEqual(originalRatio, resizedRatio, accuracy: 0.1)
    }
    
    func testImageResize_SquareImage() {
        // Given: A square image
        let image = createTestImage(width: 1000, height: 1000)
        
        // When: Resize to max dimension 500
        let resized = ImageCompressor.resizeImage(image, maxDimension: 500)
        
        // Then: Should remain square
        XCTAssertEqual(resized.size.width, 500, accuracy: 1.0)
        XCTAssertEqual(resized.size.height, 500, accuracy: 1.0)
    }
    
    func testImageResize_PortraitImage() {
        // Given: A portrait image (height > width)
        let image = createTestImage(width: 500, height: 1000)
        
        // When: Resize to max dimension 500
        let resized = ImageCompressor.resizeImage(image, maxDimension: 500)
        
        // Then: Height should be 500, width should be 250
        XCTAssertEqual(resized.size.width, 250, accuracy: 1.0)
        XCTAssertEqual(resized.size.height, 500, accuracy: 1.0)
    }
    
    func testThumbnailGeneration_CreatesCorrectSize() {
        // Given: A large image
        let image = createTestImage(width: 2000, height: 2000)
        
        // When: Generate thumbnail
        let thumbnail = ImageCompressor.generateThumbnail(image, size: 100)
        
        // Then: Should be 100x100
        XCTAssertEqual(thumbnail.size.width, 100, accuracy: 1.0)
        XCTAssertEqual(thumbnail.size.height, 100, accuracy: 1.0)
    }
    
    func testThumbnailGeneration_NonSquareImage() {
        // Given: A non-square image
        let image = createTestImage(width: 2000, height: 1000)
        
        // When: Generate square thumbnail
        let thumbnail = ImageCompressor.generateThumbnail(image, size: 100)
        
        // Then: Should be square (aspect fill - crops to fit)
        XCTAssertEqual(thumbnail.size.width, 100, accuracy: 1.0)
        XCTAssertEqual(thumbnail.size.height, 100, accuracy: 1.0)
    }
    
    // MARK: - ImageFileManager Tests
    
    func testSaveAndLoadImage() {
        // Given: An image and a unique filename
        let testImage = createTestImage(width: 500, height: 500, color: .blue)
        let filename = "test_save_load_\(UUID().uuidString).jpg"
        
        // When: Save image
        guard let savedPath = ImageFileManager.saveImage(testImage, filename: filename) else {
            XCTFail("Failed to save image")
            return
        }
        
        print("Saved to: \(savedPath)")
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPath), "File should exist at path")
        
        // When: Load image
        guard let loadedImage = ImageFileManager.loadImage(from: savedPath) else {
            XCTFail("Failed to load image")
            ImageFileManager.deleteImage(at: savedPath)
            return
        }
        
        // Then: Loaded image should have same dimensions as original
        XCTAssertEqual(loadedImage.size.width, testImage.size.width, accuracy: 1.0)
        XCTAssertEqual(loadedImage.size.height, testImage.size.height, accuracy: 1.0)
        
        // Cleanup
        ImageFileManager.deleteImage(at: savedPath)
    }
    
    func testDeleteImage() {
        // Given: A saved image
        let testImage = createTestImage(width: 100, height: 100)
        let filename = "test_delete_\(UUID().uuidString).jpg"
        
        guard let savedPath = ImageFileManager.saveImage(testImage, filename: filename) else {
            XCTFail("Failed to save image")
            return
        }
        
        // Verify it exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPath))
        
        // When: Delete image
        let deleted = ImageFileManager.deleteImage(at: savedPath)
        
        // Then: Should return true and file should not exist
        XCTAssertTrue(deleted, "Delete should return true")
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedPath), "File should not exist after deletion")
    }
    
    func testDeleteNonExistentImage() {
        // Given: A path that doesn't exist
        let fakePath = "/fake/path/\(UUID().uuidString).jpg"
        
        // When: Try to delete
        let deleted = ImageFileManager.deleteImage(at: fakePath)
        
        // Then: Should return false (can't delete what doesn't exist)
        XCTAssertFalse(deleted, "Should return false for non-existent file")
    }
    
    func testSaveMultipleImages() {
        // Given: Multiple images
        let image1 = createTestImage(width: 100, height: 100, color: .red)
        let image2 = createTestImage(width: 200, height: 200, color: .blue)
        let image3 = createTestImage(width: 300, height: 300, color: .green)
        
        let filename1 = "test_multi_1_\(UUID().uuidString).jpg"
        let filename2 = "test_multi_2_\(UUID().uuidString).jpg"
        let filename3 = "test_multi_3_\(UUID().uuidString).jpg"
        
        // When: Save all images
        guard let path1 = ImageFileManager.saveImage(image1, filename: filename1),
              let path2 = ImageFileManager.saveImage(image2, filename: filename2),
              let path3 = ImageFileManager.saveImage(image3, filename: filename3) else {
            XCTFail("Failed to save images")
            return
        }
        
        // Then: All should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: path1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path2))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path3))
        
        // Verify each can be loaded with correct dimensions
        if let loaded1 = ImageFileManager.loadImage(from: path1) {
            XCTAssertEqual(loaded1.size.width, 100, accuracy: 1.0)
        }
        if let loaded2 = ImageFileManager.loadImage(from: path2) {
            XCTAssertEqual(loaded2.size.width, 200, accuracy: 1.0)
        }
        if let loaded3 = ImageFileManager.loadImage(from: path3) {
            XCTAssertEqual(loaded3.size.width, 300, accuracy: 1.0)
        }
        
        // Cleanup
        ImageFileManager.deleteImage(at: path1)
        ImageFileManager.deleteImage(at: path2)
        ImageFileManager.deleteImage(at: path3)
    }
    
    func testLoadInvalidPath() {
        // Given: An invalid path
        let invalidPath = "/invalid/path/image.jpg"
        
        // When: Try to load
        let image = ImageFileManager.loadImage(from: invalidPath)
        
        // Then: Should return nil
        XCTAssertNil(image, "Loading from invalid path should return nil")
    }
    
    func testSaveWithLongFilename() {
        // Given: An image and a very long filename
        let testImage = createTestImage(width: 100, height: 100)
        let longFilename = String(repeating: "a", count: 200) + "_\(UUID().uuidString).jpg"
        
        // When: Save image
        let savedPath = ImageFileManager.saveImage(testImage, filename: longFilename)
        
        // Then: Should handle gracefully (either save or fail gracefully)
        if let path = savedPath {
            // If saved, verify and cleanup
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            ImageFileManager.deleteImage(at: path)
        }
        // If nil, that's acceptable - long filenames may not be supported
    }
    
    func testImagePersistence() {
        // Given: A saved image
        let testImage = createTestImage(width: 250, height: 250, color: .orange)
        let filename = "test_persistence_\(UUID().uuidString).jpg"
        
        guard let savedPath = ImageFileManager.saveImage(testImage, filename: filename) else {
            XCTFail("Failed to save image")
            return
        }
        
        // When: Load it multiple times
        let loaded1 = ImageFileManager.loadImage(from: savedPath)
        let loaded2 = ImageFileManager.loadImage(from: savedPath)
        let loaded3 = ImageFileManager.loadImage(from: savedPath)
        
        // Then: All loads should succeed
        XCTAssertNotNil(loaded1)
        XCTAssertNotNil(loaded2)
        XCTAssertNotNil(loaded3)
        
        // All should have same dimensions
        XCTAssertEqual(loaded1?.size.width, testImage.size.width, accuracy: 1.0)
        XCTAssertEqual(loaded2?.size.width, testImage.size.width, accuracy: 1.0)
        XCTAssertEqual(loaded3?.size.width, testImage.size.width, accuracy: 1.0)
        
        // Cleanup
        ImageFileManager.deleteImage(at: savedPath)
    }
}

