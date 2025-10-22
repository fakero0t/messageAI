//
//  UserService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import UIKit

class UserService {
    static let shared = UserService()
    let db = Firestore.firestore()
    
    private init() {}
    
    func fetchUser(byId userId: String) async throws -> User {
        print("🔍 Searching for user with ID: \(userId)")
        let snapshot = try await db.collection("users").document(userId).getDocument()
        
        print("📄 Document exists: \(snapshot.exists)")
        
        guard let data = snapshot.data() else {
            print("❌ No data in document")
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        print("📦 Document data: \(data)")
        
        let user = try Firestore.Decoder().decode(User.self, from: data)
        print("✅ Successfully decoded user: \(user.displayName)")
        return user
    }
    
    func fetchUser(byEmail email: String) async throws -> User? {
        print("🔍 Searching for user with email: \(email)")
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        print("📊 Found \(snapshot.documents.count) documents")
        
        guard let document = snapshot.documents.first else {
            print("❌ No documents found for email")
            return nil
        }
        
        print("📦 First document data: \(document.data())")
        
        guard let user = try? Firestore.Decoder().decode(User.self, from: document.data()) else {
            print("❌ Failed to decode user")
            return nil
        }
        
        print("✅ Successfully decoded user: \(user.displayName)")
        return user
    }
    
    func observeUserStatus(userId: String) -> AnyPublisher<User?, Never> {
        let subject = PassthroughSubject<User?, Never>()
        
        let listener = db.collection("users").document(userId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let user = try? Firestore.Decoder().decode(User.self, from: data) else {
                    subject.send(nil)
                    return
                }
                subject.send(user)
            }
        
        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Profile Picture Management (PR-12)
    
    /// Upload profile picture to Firebase Storage
    /// - Parameters:
    ///   - userId: User ID
    ///   - image: UIImage to upload
    /// - Returns: Download URL string
    /// - Throws: Upload or compression errors
    func uploadProfileImage(userId: String, image: UIImage) async throws -> String {
        print("📸 [UserService] Uploading profile picture for user: \(userId)")
        
        // 1. Compress image (smaller target for profile pics - 500KB)
        guard let compressedData = ImageCompressor.compress(image: image, targetSizeKB: 500) else {
            print("❌ [UserService] Image compression failed")
            throw ProfileImageError.compressionFailed
        }
        
        print("📸 [UserService] Image compressed to \(String(format: "%.2f", Double(compressedData.count) / 1024.0))KB")
        
        // 2. Upload to Firebase Storage
        let storageRef = Storage.storage().reference()
        let profileImageRef = storageRef.child("profile_pictures/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        print("☁️ [UserService] Uploading to Firebase Storage...")
        _ = try await profileImageRef.putDataAsync(compressedData, metadata: metadata)
        
        // 3. Get download URL
        let downloadUrl = try await profileImageRef.downloadURL()
        let urlString = downloadUrl.absoluteString
        
        print("✅ [UserService] Upload complete, URL: \(urlString)")
        
        // 4. Update Firestore user document
        try await db.collection("users").document(userId).updateData([
            "profileImageUrl": urlString
        ])
        
        print("✅ [UserService] Firestore updated with profile image URL")
        
        // 5. Update local user object if current user
        if var currentUser = AuthenticationService.shared.currentUser,
           currentUser.id == userId {
            currentUser.profileImageUrl = urlString
            AuthenticationService.shared.currentUser = currentUser
            print("✅ [UserService] Local user object updated")
        }
        
        print("✅ [UserService] Profile picture upload complete")
        return urlString
    }
    
    /// Delete profile picture from Firebase Storage
    /// - Parameter userId: User ID
    /// - Throws: Deletion errors
    func deleteProfileImage(userId: String) async throws {
        print("🗑️ [UserService] Deleting profile picture for user: \(userId)")
        
        // 1. Delete from Storage
        let storageRef = Storage.storage().reference()
        let profileImageRef = storageRef.child("profile_pictures/\(userId).jpg")
        
        do {
            try await profileImageRef.delete()
            print("✅ [UserService] Image deleted from Firebase Storage")
        } catch {
            // Ignore if file doesn't exist
            print("⚠️ [UserService] Profile picture may not exist: \(error)")
        }
        
        // 2. Update Firestore (remove field)
        try await db.collection("users").document(userId).updateData([
            "profileImageUrl": FieldValue.delete()
        ])
        
        print("✅ [UserService] Firestore field removed")
        
        // 3. Update local user object if current user
        if var currentUser = AuthenticationService.shared.currentUser,
           currentUser.id == userId {
            currentUser.profileImageUrl = nil
            AuthenticationService.shared.currentUser = currentUser
            print("✅ [UserService] Local user object updated")
        }
        
        print("✅ [UserService] Profile picture deletion complete")
    }
}

// MARK: - Profile Image Errors (PR-12)

enum ProfileImageError: LocalizedError {
    case compressionFailed
    case uploadFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress profile picture"
        case .uploadFailed:
            return "Failed to upload profile picture"
        case .deleteFailed:
            return "Failed to delete profile picture"
        }
    }
}

