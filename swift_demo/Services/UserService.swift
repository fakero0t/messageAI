//
//  UserService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore
import Combine

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
}

