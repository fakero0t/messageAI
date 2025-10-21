//
//  ImageFileManager.swift
//  swift_demo
//
//  Created for PR-5: Local image file management
//
//  Vue Analogy: This is like a local file storage service in Vue/Node
//  - saveImage() → like fs.writeFile() or IndexedDB.put()
//  - loadImage() → like fs.readFile() or IndexedDB.get()
//  - deleteImage() → like fs.unlink() or IndexedDB.delete()
//  - cleanupOldImages() → like a cron job that removes stale data
//

import UIKit

/// Manages local storage of images on disk for offline queue and caching
/// In Vue: const imageFileManager = new ImageFileManager() (singleton)
class ImageFileManager {
    // Singleton pattern
    // In Vue: export const imageFileManager = new ImageFileManager()
    static let shared = ImageFileManager()
    
    private let fileManager = FileManager.default
    
    /// Directory for storing queued images
    /// In Vue: const IMAGES_DIR = path.join(documentsDir, 'QueuedImages')
    private lazy var imagesDirectory: URL = {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesURL = documentsURL.appendingPathComponent("QueuedImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        // In Vue: if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true })
        if !fileManager.fileExists(atPath: imagesURL.path) {
            try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            print("📁 [ImageFileManager] Created QueuedImages directory: \(imagesURL.path)")
        }
        
        return imagesURL
    }()
    
    private init() {
        print("📁 [ImageFileManager] Initialized")
        print("   Storage path: \(imagesDirectory.path)")
    }
    
    // MARK: - Save
    
    /// Save image to disk and return file path
    /// In Vue: const saveToDisk = async (image: Blob, id: string) => { ... }
    ///
    /// - Parameters:
    ///   - image: UIImage to save
    ///   - id: Unique identifier (message ID)
    /// - Returns: File URL where image was saved
    /// - Throws: ImageFileError if save fails
    func saveImage(_ image: UIImage, withId id: String) throws -> URL {
        let fileURL = getImagePath(withId: id)
        
        print("💾 [ImageFileManager] Saving image with ID: \(id)")
        
        // Compress and save as JPEG
        // In Vue: const buffer = await image.arrayBuffer()
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ [ImageFileManager] Failed to compress image")
            throw ImageFileError.compressionFailed
        }
        
        print("   Size: \(imageData.count / 1024)KB")
        
        // Write to disk
        // In Vue: await fs.promises.writeFile(path, buffer)
        try imageData.write(to: fileURL)
        
        print("✅ [ImageFileManager] Image saved to: \(fileURL.lastPathComponent)")
        return fileURL
    }
    
    // MARK: - Load
    
    /// Load image from disk
    /// In Vue: const loadFromDisk = async (id: string) => { ... }
    ///
    /// - Parameter id: Unique identifier (message ID)
    /// - Returns: UIImage if found, nil if file doesn't exist
    /// - Throws: ImageFileError if load fails
    func loadImage(withId id: String) throws -> UIImage? {
        let fileURL = getImagePath(withId: id)
        
        print("📂 [ImageFileManager] Loading image with ID: \(id)")
        
        // Check if file exists
        // In Vue: if (!fs.existsSync(path)) return null
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ [ImageFileManager] File not found: \(fileURL.lastPathComponent)")
            return nil
        }
        
        // Read from disk
        // In Vue: const buffer = await fs.promises.readFile(path)
        let imageData = try Data(contentsOf: fileURL)
        
        guard let image = UIImage(data: imageData) else {
            print("❌ [ImageFileManager] Failed to create UIImage from data")
            throw ImageFileError.saveFailed
        }
        
        print("✅ [ImageFileManager] Image loaded: \(fileURL.lastPathComponent)")
        return image
    }
    
    // MARK: - Delete
    
    /// Delete image from disk
    /// In Vue: const deleteFromDisk = async (id: string) => { ... }
    ///
    /// - Parameter id: Unique identifier (message ID)
    /// - Throws: File system errors
    func deleteImage(withId id: String) throws {
        let fileURL = getImagePath(withId: id)
        
        print("🗑️ [ImageFileManager] Deleting image with ID: \(id)")
        
        // Check if file exists
        // In Vue: if (!fs.existsSync(path)) return
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("ℹ️ [ImageFileManager] File already deleted: \(fileURL.lastPathComponent)")
            return // Already deleted
        }
        
        // Delete file
        // In Vue: await fs.promises.unlink(path)
        try fileManager.removeItem(at: fileURL)
        print("✅ [ImageFileManager] Image deleted: \(fileURL.lastPathComponent)")
    }
    
    // MARK: - Path
    
    /// Get file path for image
    /// In Vue: const getImagePath = (id: string) => path.join(IMAGES_DIR, `${id}.jpg`)
    ///
    /// - Parameter id: Unique identifier (message ID)
    /// - Returns: File URL for the image
    func getImagePath(withId id: String) -> URL {
        return imagesDirectory.appendingPathComponent("\(id).jpg")
    }
    
    /// Check if image exists on disk
    /// In Vue: const exists = (id: string) => fs.existsSync(getImagePath(id))
    ///
    /// - Parameter id: Unique identifier (message ID)
    /// - Returns: True if file exists
    func imageExists(withId id: String) -> Bool {
        let path = getImagePath(withId: id).path
        return fileManager.fileExists(atPath: path)
    }
    
    // MARK: - Cleanup
    
    /// Clean up old images (garbage collection)
    /// In Vue: const cleanupOldFiles = async (daysOld: number) => { ... }
    ///
    /// - Parameter days: Delete images older than this many days (default: 7)
    func cleanupOldImages(olderThan days: Int = 7) {
        print("🧹 [ImageFileManager] Starting cleanup (older than \(days) days)")
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            print("⚠️ [ImageFileManager] Could not list directory contents")
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        var deletedCount = 0
        
        for fileURL in files {
            // Get file creation date
            // In Vue: const stats = await fs.promises.stat(path)
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date,
                  creationDate < cutoffDate else {
                continue
            }
            
            // Delete old file
            // In Vue: await fs.promises.unlink(path)
            try? fileManager.removeItem(at: fileURL)
            deletedCount += 1
            print("   🗑️ Deleted: \(fileURL.lastPathComponent)")
        }
        
        print("✅ [ImageFileManager] Cleanup complete: \(deletedCount) files deleted")
    }
    
    /// Get total size of cached images
    /// In Vue: const getCacheSize = async () => { ... }
    ///
    /// - Returns: Size in bytes
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for fileURL in files {
            // Get file size
            // In Vue: const stats = await fs.promises.stat(path)
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? Int64 else {
                continue
            }
            totalSize += fileSize
        }
        
        return totalSize
    }
    
    /// Get human-readable cache size
    /// In Vue: const formatBytes = (bytes: number) => { ... }
    ///
    /// - Returns: Formatted string like "1.5 MB"
    func getFormattedCacheSize() -> String {
        let bytes = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Get count of cached images
    /// In Vue: const getCacheCount = async () => { ... }
    ///
    /// - Returns: Number of images stored
    func getCachedImageCount() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return 0
        }
        return files.count
    }
    
    /// Clear all cached images
    /// In Vue: const clearAll = async () => { ... }
    func clearAllImages() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        var deletedCount = 0
        for fileURL in files {
            try? fileManager.removeItem(at: fileURL)
            deletedCount += 1
        }
        
        print("🗑️ [ImageFileManager] Cleared all images: \(deletedCount) files deleted")
    }
}

// MARK: - Errors

/// Errors that can occur during image file operations
/// In Vue: class ImageFileError extends Error { ... }
enum ImageFileError: LocalizedError {
    case compressionFailed
    case fileNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .fileNotFound:
            return "Image file not found"
        case .saveFailed:
            return "Failed to save image to disk"
        }
    }
}

// MARK: - Vue/TypeScript Comparison

/*
 This Swift class is equivalent to this Vue/Node service:
 
 ```typescript
 // services/ImageFileManager.ts
 import fs from 'fs/promises'
 import path from 'path'
 
 class ImageFileManager {
   private static instance: ImageFileManager
   private imagesDirectory: string
   
   private constructor() {
     this.imagesDirectory = path.join(documentsDir, 'QueuedImages')
     
     // Create directory if it doesn't exist
     if (!fs.existsSync(this.imagesDirectory)) {
       fs.mkdirSync(this.imagesDirectory, { recursive: true })
     }
   }
   
   static get shared(): ImageFileManager {
     if (!this.instance) {
       this.instance = new ImageFileManager()
     }
     return this.instance
   }
   
   // Save image to disk
   async saveImage(blob: Blob, id: string): Promise<string> {
     const filePath = this.getImagePath(id)
     const buffer = Buffer.from(await blob.arrayBuffer())
     
     await fs.writeFile(filePath, buffer)
     console.log('💾 Image saved:', filePath)
     
     return filePath
   }
   
   // Load image from disk
   async loadImage(id: string): Promise<Blob | null> {
     const filePath = this.getImagePath(id)
     
     if (!fs.existsSync(filePath)) {
       return null
     }
     
     const buffer = await fs.readFile(filePath)
     return new Blob([buffer], { type: 'image/jpeg' })
   }
   
   // Delete image from disk
   async deleteImage(id: string): Promise<void> {
     const filePath = this.getImagePath(id)
     
     if (!fs.existsSync(filePath)) {
       return // Already deleted
     }
     
     await fs.unlink(filePath)
     console.log('🗑️ Image deleted:', filePath)
   }
   
   // Get file path for image
   private getImagePath(id: string): string {
     return path.join(this.imagesDirectory, `${id}.jpg`)
   }
   
   // Clean up old images
   async cleanupOldImages(days: number = 7): Promise<void> {
     const files = await fs.readdir(this.imagesDirectory)
     const cutoffDate = Date.now() - days * 24 * 60 * 60 * 1000
     
     for (const file of files) {
       const filePath = path.join(this.imagesDirectory, file)
       const stats = await fs.stat(filePath)
       
       if (stats.birthtimeMs < cutoffDate) {
         await fs.unlink(filePath)
       }
     }
   }
   
   // Get cache size
   async getCacheSize(): Promise<number> {
     const files = await fs.readdir(this.imagesDirectory)
     let totalSize = 0
     
     for (const file of files) {
       const filePath = path.join(this.imagesDirectory, file)
       const stats = await fs.stat(filePath)
       totalSize += stats.size
     }
     
     return totalSize
   }
 }
 
 export const imageFileManager = ImageFileManager.shared
 ```
 
 Key similarities:
 - Singleton pattern for shared instance
 - Save/load/delete operations map to fs operations
 - Cleanup based on file creation date
 - Cache size calculation by summing file sizes
 */

