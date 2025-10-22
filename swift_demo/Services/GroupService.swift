//
//  GroupService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class GroupService {
    static let shared = GroupService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    private init() {}
    
    func createGroup(
        name: String?,
        participantIds: [String],
        creatorId: String
    ) async throws -> String {
        guard participantIds.count >= 2 else {
            throw NSError(domain: "GroupService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Group must have at least 2 other participants (3 total including you)"
            ])
        }
        
        // Ensure creator is in participants
        var allParticipants = participantIds
        if !allParticipants.contains(creatorId) {
            allParticipants.append(creatorId)
        }
        
        // Generate unique group ID
        let groupId = UUID().uuidString
        
        print("🆕 Creating group: \(groupId) with \(allParticipants.count) participants")
        
        // Create in Firestore
        let groupData: [String: Any] = [
            "id": groupId,
            "participants": allParticipants,
            "isGroup": true,
            "groupName": name ?? "",
            "createdBy": creatorId,
            "createdAt": FieldValue.serverTimestamp(),
            "lastMessageTime": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("conversations").document(groupId).setData(groupData)
        print("✅ Group created in Firestore")
        
        // Create in local storage immediately so it appears in conversation list
        try await MainActor.run {
            let conversation = ConversationEntity(
                id: groupId,
                participantIds: allParticipants,
                isGroup: true,
                groupName: name,
                createdBy: creatorId
            )
            conversation.lastMessageTime = Date()
            try localStorage.saveConversation(conversation)
            print("✅ Group saved to local storage")
        }
        
        return groupId
    }
    
    func addParticipant(groupId: String, userId: String, requesterId: String) async throws {
        print("➕ Adding participant \(userId) to group \(groupId)")
        
        // Verify requester is creator
        let snapshot = try await db.collection("conversations").document(groupId).getDocument()
        guard let data = snapshot.data(),
              let createdBy = data["createdBy"] as? String,
              createdBy == requesterId else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Only group creator can add participants"
            ])
        }
        
        // Add to Firestore
        try await db.collection("conversations").document(groupId).updateData([
            "participants": FieldValue.arrayUnion([userId])
        ])
        
        // Update local storage
        try await MainActor.run {
            if let conversation = try? localStorage.fetchConversation(byId: groupId) {
                if !conversation.participantIds.contains(userId) {
                    conversation.participantIds.append(userId)
                    // SwiftData auto-saves changes to tracked objects
                }
            }
        }
        
        print("✅ Participant added")
    }
    
    func removeParticipant(groupId: String, userId: String, requesterId: String) async throws {
        print("➖ Removing participant \(userId) from group \(groupId)")
        
        // Allow if:
        // 1. Requester is removing themselves (leaving group), OR
        // 2. Requester is the creator removing someone else
        
        let snapshot = try await db.collection("conversations").document(groupId).getDocument()
        guard let data = snapshot.data(),
              let createdBy = data["createdBy"] as? String else {
            throw NSError(domain: "GroupService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Group not found"
            ])
        }
        
        let isSelfRemoval = userId == requesterId
        let isCreator = createdBy == requesterId
        
        guard isSelfRemoval || isCreator else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Only group creator can remove other participants"
            ])
        }
        
        // Remove from Firestore
        try await db.collection("conversations").document(groupId).updateData([
            "participants": FieldValue.arrayRemove([userId])
        ])
        
        // Update local storage
        try await MainActor.run {
            if let conversation = try? localStorage.fetchConversation(byId: groupId) {
                conversation.participantIds.removeAll { $0 == userId }
                // SwiftData auto-saves changes to tracked objects
            }
        }
        
        print("✅ Participant removed")
    }
    
    func isCreator(groupId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection("conversations").document(groupId).getDocument()
        guard let data = snapshot.data(),
              let createdBy = data["createdBy"] as? String else {
            return false
        }
        return createdBy == userId
    }
}

