//
//  FirestoreListenerService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class FirestoreListenerService {
    static let shared = FirestoreListenerService()
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    private init() {}
    
    func listenToMessages(
        conversationId: String,
        onMessage: @escaping (MessageSnapshot) -> Void
    ) {
        // Remove existing listener if any
        stopListening(conversationId: conversationId)
        
        print("🎧 Starting listener for conversation: \(conversationId)")
        
        let listener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to messages: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                print("📬 Received \(snapshot.documentChanges.count) message changes")
                
                snapshot.documentChanges.forEach { change in
                    if change.type == .added || change.type == .modified {
                        do {
                            let messageData = change.document.data()
                            let messageSnapshot = try self.parseMessage(from: messageData)
                            print("📨 Message: \(change.type == .added ? "Added" : "Modified") - \(messageSnapshot.text)")
                            onMessage(messageSnapshot)
                        } catch {
                            print("❌ Error parsing message: \(error)")
                        }
                    }
                }
            }
        
        listeners[conversationId] = listener
    }
    
    func stopListening(conversationId: String) {
        if listeners[conversationId] != nil {
            print("🛑 Stopping listener for conversation: \(conversationId)")
            listeners[conversationId]?.remove()
            listeners.removeValue(forKey: conversationId)
        }
    }
    
    func stopAllListeners() {
        print("🛑 Stopping all listeners")
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    private func parseMessage(from data: [String: Any]) throws -> MessageSnapshot {
        let id = data["id"] as? String ?? ""
        let conversationId = data["conversationId"] as? String ?? ""
        let senderId = data["senderId"] as? String ?? ""
        let text = data["text"] as? String  // PR-7: Can be nil for image messages
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let status = data["status"] as? String ?? "delivered"
        let readBy = data["readBy"] as? [String] ?? []
        
        // PR-7: Image fields
        let imageUrl = data["imageUrl"] as? String
        let imageWidth = data["imageWidth"] as? Double
        let imageHeight = data["imageHeight"] as? Double
        
        return MessageSnapshot(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            status: status,
            readBy: readBy,
            imageUrl: imageUrl,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
    }
}

struct MessageSnapshot {
    let id: String
    let conversationId: String
    let senderId: String
    let text: String?  // PR-7: Optional for image-only messages
    let timestamp: Date
    let status: String
    let readBy: [String]
    
    // PR-7: Image support
    let imageUrl: String?
    let imageWidth: Double?
    let imageHeight: Double?
}

