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
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            if let firebaseUser = firebaseUser {
                self?.loadUserData(userId: firebaseUser.uid)
            } else {
                self?.currentUser = nil
            }
        }
    }
    
    private func loadUserData(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(),
                  let user = try? Firestore.Decoder().decode(User.self, from: data) else {
                return
            }
            self?.currentUser = user
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        try await createUserDocument(userId: result.user.uid, email: email, displayName: displayName)
    }
    
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    private func createUserDocument(userId: String, email: String, displayName: String) async throws {
        let user = User(id: userId, email: email, displayName: displayName, online: false)
        let data = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(userId).setData(data)
    }
}

