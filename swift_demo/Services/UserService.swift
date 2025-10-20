//
//  UserService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class UserService {
    static let shared = UserService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchUser(byId userId: String) async throws -> User {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data() else {
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return try Firestore.Decoder().decode(User.self, from: data)
    }
    
    func fetchUser(byEmail email: String) async throws -> User? {
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        guard let document = snapshot.documents.first,
              let user = try? Firestore.Decoder().decode(User.self, from: document.data()) else {
            return nil
        }
        return user
    }
}

