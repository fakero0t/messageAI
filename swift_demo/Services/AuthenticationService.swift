//
//  AuthenticationService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: User?
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var isCreatingNewUser = false // Flag to prevent fallback during signup
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            if let firebaseUser = firebaseUser {
                self?.loadUserData(userId: firebaseUser.uid)
                // Start presence tracking
                PresenceService.shared.startTracking(for: firebaseUser.uid)
            } else {
                // Stop presence tracking
                PresenceService.shared.stopTracking()
                Task { @MainActor in
                    self?.currentUser = nil
                }
            }
        }
    }
    
    private func loadUserData(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading user data: \(error)")
                // Don't create fallback if we're in the middle of creating a new user
                if !self.isCreatingNewUser {
                    self.createFallbackUser(userId: userId)
                }
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No user document found for userId: \(userId)")
                // Don't create fallback if we're in the middle of creating a new user
                if !self.isCreatingNewUser {
                    print("Creating fallback user")
                    self.createFallbackUser(userId: userId)
                } else {
                    print("Waiting for user document to be created during signup...")
                }
                return
            }
            
            guard let user = try? Firestore.Decoder().decode(User.self, from: data) else {
                print("Failed to decode user data")
                if !self.isCreatingNewUser {
                    self.createFallbackUser(userId: userId)
                }
                return
            }
            
            Task { @MainActor in
                self.currentUser = user
                // Clear the flag once we successfully load the user
                self.isCreatingNewUser = false
            }
        }
    }
    
    private func createFallbackUser(userId: String) {
        guard let firebaseUser = auth.currentUser else { return }
        
        // Create a basic user object so auth can complete
        let user = User(
            id: userId,
            email: firebaseUser.email ?? "unknown@email.com",
            username: "user_\(userId.prefix(8))", // Fallback username
            displayName: firebaseUser.email?.components(separatedBy: "@").first ?? "User",
            online: true,
            lastSeen: nil
        )
        
        Task { @MainActor in
            self.currentUser = user
        }
        
        // Try to create the document in Firestore
        Task {
            do {
                let data = try Firestore.Encoder().encode(user)
                try await db.collection("users").document(userId).setData(data, merge: true)
                print("✅ Created user document for \(userId)")
            } catch {
                print("⚠️ Failed to create user document: \(error)")
            }
        }
    }
    
    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        // Normalize username to lowercase for consistency
        let normalizedUsername = username.lowercased()
        
        // Check if username is available before creating account
        let isAvailable = try await UserService.shared.isUsernameAvailable(normalizedUsername)
        
        if !isAvailable {
            throw AuthError.usernameTaken
        }
        
        // Set flag to prevent fallback user creation during signup
        isCreatingNewUser = true
        
        do {
            // Create Firebase Auth user
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // Immediately create user document with specified username to prevent race condition
            // This must happen before the auth state listener tries to load the user
            try await createUserDocument(userId: result.user.uid, email: email, username: normalizedUsername, displayName: displayName)
            
            print("✅ User created with username: @\(normalizedUsername)")
            
            // Force reload user data now that document is created
            loadUserData(userId: result.user.uid)
        } catch {
            // Clear flag if signup fails
            isCreatingNewUser = false
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }
    
    func signOut() throws {
        PresenceService.shared.stopTracking()
        try auth.signOut()
    }
    
    private func createUserDocument(userId: String, email: String, username: String, displayName: String) async throws {
        // Create user as online since they're actively signing up
        let user = User(id: userId, email: email, username: username, displayName: displayName, online: true, lastSeen: Date())
        let data = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(userId).setData(data)
        print("✅ Created user document with online status: true")
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case usernameTaken
    case invalidUsername
    
    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "This username is already taken. Please choose another."
        case .invalidUsername:
            return "Username must be 3-20 characters (letters, numbers, and underscores only)"
        }
    }
}

