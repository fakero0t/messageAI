//
//  ImageUploadService.swift
//  swift_demo
//
//  Created for PR-6: Image upload to Firebase Storage with progress tracking
//
//  Vue Analogy: This is like an upload service in Vue
//  - uploadImage() → like axios.post() with FormData and onUploadProgress
//  - progressHandler → like onUploadProgress callback in axios
//  - uploadTasks → like a Map of AbortControllers for cancellation
//

import Foundation
import FirebaseStorage
import UIKit

/// Service for uploading images to Firebase Storage
/// In Vue: class ImageUploadService { upload, cancel, retry }
class ImageUploadService {
    // Singleton pattern
    // In Vue: export const imageUploadService = new ImageUploadService()
    static let shared = ImageUploadService()
    
    private let storage = Storage.storage()
    
    /// Active upload tasks for cancellation support
    /// In Vue: const uploadTasks = new Map<string, AbortController>()
    private var uploadTasks: [String: StorageUploadTask] = [:]
    
    private init() {
        print("📤 [ImageUploadService] Initialized")
    }
    
    // MARK: - Models
    
    /// Progress update model
    /// In Vue: interface UploadProgress { messageId, progress, status }
    struct UploadProgress {
        let messageId: String
        let progress: Double // 0.0 to 1.0
        let status: UploadStatus
    }
    
    /// Upload status enum
    /// In Vue: type UploadStatus = 'preparing' | 'compressing' | 'uploading' | 'completed' | 'failed'
    enum UploadStatus {
        case preparing
        case compressing
        case uploading(bytesUploaded: Int64, totalBytes: Int64)
        case completed(url: String)
        case failed(Error)
        
        var description: String {
            switch self {
            case .preparing:
                return "Preparing..."
            case .compressing:
                return "Compressing image..."
            case .uploading(let uploaded, let total):
                let uploadedMB = Double(uploaded) / 1024.0 / 1024.0
                let totalMB = Double(total) / 1024.0 / 1024.0
                return String(format: "Uploading %.1f MB / %.1f MB", uploadedMB, totalMB)
            case .completed:
                return "Upload complete"
            case .failed(let error):
                return "Failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Upload
    
    /// Upload image to Firebase Storage with progress tracking
    /// In Vue: const uploadImage = async (file, messageId, onProgress) => { ... }
    ///
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - messageId: Unique message identifier
    ///   - conversationId: Conversation identifier
    ///   - progressHandler: Callback for progress updates (called on main thread)
    /// - Returns: Download URL string
    /// - Throws: ImageUploadError on failure
    func uploadImage(
        _ image: UIImage,
        messageId: String,
        conversationId: String,
        progressHandler: @escaping (UploadProgress) -> Void
    ) async throws -> String {
        
        print("📤 [ImageUpload] Starting upload for message: \(messageId)")
        print("   Conversation: \(conversationId)")
        
        // 1. Notify: Preparing
        await MainActor.run {
            progressHandler(UploadProgress(messageId: messageId, progress: 0, status: .preparing))
        }
        
        // 2. Compress image
        print("📤 [ImageUpload] Compressing image...")
        await MainActor.run {
            progressHandler(UploadProgress(messageId: messageId, progress: 0.1, status: .compressing))
        }
        
        guard let compressedData = ImageCompressor.compress(image: image, targetSizeKB: 1024) else {
            print("❌ [ImageUpload] Compression failed")
            throw ImageUploadError.compressionFailed
        }
        
        print("   Compressed size: \(compressedData.count / 1024)KB")
        
        // 3. Prepare storage reference
        // Path: /images/{conversationId}/{messageId}.jpg
        let storageRef = storage.reference()
        let imagePath = "images/\(conversationId)/\(messageId).jpg"
        let imageRef = storageRef.child(imagePath)
        
        print("📤 [ImageUpload] Upload path: \(imagePath)")
        
        // 4. Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Store image dimensions in metadata
        let dimensions = ImageCompressor.getDimensions(image)
        metadata.customMetadata = [
            "width": String(Int(dimensions.width)),
            "height": String(Int(dimensions.height)),
            "originalSize": String(image.jpegData(compressionQuality: 1.0)?.count ?? 0),
            "compressedSize": String(compressedData.count)
        ]
        
        print("   Dimensions: \(Int(dimensions.width))x\(Int(dimensions.height))")
        
        // 5. Upload with progress tracking
        // In Vue: await axios.post(url, formData, { onUploadProgress })
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = imageRef.putData(compressedData, metadata: metadata)
            
            // Store task for cancellation support
            // In Vue: uploadTasks.set(messageId, abortController)
            uploadTasks[messageId] = uploadTask
            
            // Progress observer
            // In Vue: onUploadProgress: (progressEvent) => { ... }
            uploadTask.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                print("📤 [ImageUpload] Progress: \(Int(percentComplete * 100))%")
                
                Task { @MainActor in
                    progressHandler(UploadProgress(
                        messageId: messageId,
                        progress: 0.1 + (percentComplete * 0.8), // 10-90% range (0-10% was compression)
                        status: .uploading(
                            bytesUploaded: progress.completedUnitCount,
                            totalBytes: progress.totalUnitCount
                        )
                    ))
                }
            }
            
            // Success observer
            uploadTask.observe(.success) { [weak self] snapshot in
                print("✅ [ImageUpload] Upload complete, fetching download URL...")
                
                // Get download URL
                // In Vue: const response = await axios.get(uploadedFile.url)
                imageRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ [ImageUpload] Failed to get download URL: \(error.localizedDescription)")
                        Task { @MainActor in
                            progressHandler(UploadProgress(messageId: messageId, progress: 1.0, status: .failed(error)))
                        }
                        continuation.resume(throwing: ImageUploadError.urlGenerationFailed)
                    } else if let url = url {
                        let urlString = url.absoluteString
                        print("✅ [ImageUpload] Download URL: \(urlString)")
                        
                        Task { @MainActor in
                            progressHandler(UploadProgress(messageId: messageId, progress: 1.0, status: .completed(url: urlString)))
                        }
                        continuation.resume(returning: urlString)
                    }
                    
                    // Cleanup
                    self?.uploadTasks.removeValue(forKey: messageId)
                }
            }
            
            // Failure observer
            uploadTask.observe(.failure) { [weak self] snapshot in
                if let error = snapshot.error {
                    print("❌ [ImageUpload] Upload failed: \(error.localizedDescription)")
                    
                    Task { @MainActor in
                        progressHandler(UploadProgress(messageId: messageId, progress: 1.0, status: .failed(error)))
                    }
                    continuation.resume(throwing: ImageUploadError.uploadFailed)
                }
                
                // Cleanup
                self?.uploadTasks.removeValue(forKey: messageId)
            }
        }
    }
    
    // MARK: - Control
    
    /// Cancel ongoing upload
    /// In Vue: uploadTasks.get(messageId)?.abort()
    ///
    /// - Parameter messageId: Message identifier
    func cancelUpload(messageId: String) {
        if let task = uploadTasks[messageId] {
            task.cancel()
            uploadTasks.removeValue(forKey: messageId)
            print("🚫 [ImageUpload] Upload cancelled: \(messageId)")
        } else {
            print("⚠️ [ImageUpload] No active upload to cancel: \(messageId)")
        }
    }
    
    /// Check if upload is in progress
    /// In Vue: uploadTasks.has(messageId)
    ///
    /// - Parameter messageId: Message identifier
    /// - Returns: True if upload is active
    func isUploading(messageId: String) -> Bool {
        return uploadTasks[messageId] != nil
    }
    
    /// Get count of active uploads
    /// In Vue: uploadTasks.size
    var activeUploadCount: Int {
        return uploadTasks.count
    }
    
    /// Cancel all ongoing uploads
    /// In Vue: uploadTasks.forEach(task => task.abort())
    func cancelAllUploads() {
        print("🚫 [ImageUpload] Cancelling all uploads (\(uploadTasks.count))")
        uploadTasks.values.forEach { $0.cancel() }
        uploadTasks.removeAll()
    }
    
    // MARK: - Retry
    
    /// Retry failed upload
    /// In Vue: const retry = () => uploadImage(file, messageId, onProgress)
    ///
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
        print("🔄 [ImageUpload] Retrying upload: \(messageId)")
        return try await uploadImage(image, messageId: messageId, conversationId: conversationId, progressHandler: progressHandler)
    }
    
    // MARK: - Utilities
    
    /// Delete image from Firebase Storage
    /// In Vue: await deleteObject(ref(storage, path))
    ///
    /// - Parameters:
    ///   - conversationId: Conversation identifier
    ///   - messageId: Message identifier
    func deleteImage(conversationId: String, messageId: String) async throws {
        let storageRef = storage.reference()
        let imagePath = "images/\(conversationId)/\(messageId).jpg"
        let imageRef = storageRef.child(imagePath)
        
        print("🗑️ [ImageUpload] Deleting image: \(imagePath)")
        
        try await imageRef.delete()
        
        print("✅ [ImageUpload] Image deleted successfully")
    }
}

// MARK: - Errors

/// Errors that can occur during image upload
/// In Vue: class ImageUploadError extends Error { ... }
enum ImageUploadError: LocalizedError {
    case compressionFailed
    case uploadFailed
    case urlGenerationFailed
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed:
            return "Failed to upload image to server"
        case .urlGenerationFailed:
            return "Failed to generate download URL"
        case .cancelled:
            return "Upload was cancelled"
        }
    }
}

// MARK: - Vue/TypeScript Comparison

/*
 This Swift service is equivalent to this Vue composable:
 
 ```typescript
 // composables/useImageUpload.ts
 import { getStorage, ref as storageRef, uploadBytesResumable, getDownloadURL } from 'firebase/storage'
 
 interface UploadProgress {
   messageId: string
   progress: number // 0-1
   status: UploadStatus
 }
 
 type UploadStatus = 
   | { type: 'preparing' }
   | { type: 'compressing' }
   | { type: 'uploading', bytesUploaded: number, totalBytes: number }
   | { type: 'completed', url: string }
   | { type: 'failed', error: Error }
 
 class ImageUploadService {
   private storage = getStorage()
   private uploadTasks = new Map<string, () => void>() // Cancel functions
   
   // Upload image with progress tracking
   async uploadImage(
     file: File,
     messageId: string,
     conversationId: string,
     onProgress: (progress: UploadProgress) => void
   ): Promise<string> {
     
     // 1. Preparing
     onProgress({ messageId, progress: 0, status: { type: 'preparing' } })
     
     // 2. Compress
     onProgress({ messageId, progress: 0.1, status: { type: 'compressing' } })
     const compressed = await compressImage(file, 1024)
     
     // 3. Upload
     const path = `images/${conversationId}/${messageId}.jpg`
     const ref = storageRef(this.storage, path)
     
     return new Promise((resolve, reject) => {
       const uploadTask = uploadBytesResumable(ref, compressed, {
         contentType: 'image/jpeg',
         customMetadata: { width: '1024', height: '768' }
       })
       
       // Store for cancellation
       this.uploadTasks.set(messageId, () => uploadTask.cancel())
       
       // Progress listener
       uploadTask.on('state_changed',
         (snapshot) => {
           const progress = snapshot.bytesTransferred / snapshot.totalBytes
           onProgress({
             messageId,
             progress: 0.1 + progress * 0.8, // 10-90%
             status: {
               type: 'uploading',
               bytesUploaded: snapshot.bytesTransferred,
               totalBytes: snapshot.totalBytes
             }
           })
         },
         (error) => {
           onProgress({ messageId, progress: 1, status: { type: 'failed', error } })
           this.uploadTasks.delete(messageId)
           reject(error)
         },
         async () => {
           const url = await getDownloadURL(ref)
           onProgress({ messageId, progress: 1, status: { type: 'completed', url } })
           this.uploadTasks.delete(messageId)
           resolve(url)
         }
       )
     })
   }
   
   // Cancel upload
   cancelUpload(messageId: string) {
     const cancel = this.uploadTasks.get(messageId)
     if (cancel) {
       cancel()
       this.uploadTasks.delete(messageId)
     }
   }
   
   // Retry
   async retryUpload(
     file: File,
     messageId: string,
     conversationId: string,
     onProgress: (progress: UploadProgress) => void
   ): Promise<string> {
     return this.uploadImage(file, messageId, conversationId, onProgress)
   }
 }
 
 export const imageUploadService = new ImageUploadService()
 ```
 
 Key similarities:
 - uploadImage() → uploadBytesResumable() with progress listener
 - progressHandler → onProgress callback
 - uploadTasks → Map of cancel functions
 - Status enum → Discriminated union type in TypeScript
 - Progress range 0-1 (0-10% compression, 10-90% upload, 90-100% URL fetch)
 */

