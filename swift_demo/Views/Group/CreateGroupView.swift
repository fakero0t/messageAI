//
//  CreateGroupView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var participants: [User] = []
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    // Callback to notify parent of group creation
    var onGroupCreated: ((String, String) -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("Enter group name (optional)", text: $groupName)
                }
                
                Section {
                    HStack {
                        TextField("Username, Email, or User ID", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    Button("Add Participant") {
                        searchAndAddParticipant()
                    }
                    .disabled(searchText.isEmpty || isSearching)
                } header: {
                    Text("Add Participants")
                } footer: {
                    Text("Search by username (e.g., @username), email, or user ID. Add at least 2 other participants (3 total including you)")
                        .font(.caption)
                }
                
                if !participants.isEmpty {
                    Section("Added Participants (\(participants.count))") {
                        ForEach(participants) { participant in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(participant.displayName)
                                        .font(.body)
                                    Text("@\(participant.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    removeParticipant(participant)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            createGroup()
                        }
                        .disabled(participants.count < 2)
                    }
                }
            }
        }
    }
    
    private func searchAndAddParticipant() {
        Task {
            await MainActor.run {
                isSearching = true
                errorMessage = nil
            }
            
            // Normalize search text
            var searchQuery = searchText.trimmingCharacters(in: .whitespaces)
            
            // Remove @ prefix if searching by username
            if searchQuery.hasPrefix("@") {
                searchQuery = String(searchQuery.dropFirst())
            }
            
            var foundUser: User?
            
            // Try as username first (most common use case)
            do {
                if let user = try await UserService.shared.fetchUser(byUsername: searchQuery) {
                    print("✅ Found user by username: \(user.displayName) (@\(user.username))")
                    foundUser = user
                }
            } catch {
                print("⚠️ Error searching by username: \(error.localizedDescription)")
            }
            
            // Try as user ID if not found
            if foundUser == nil {
                do {
                    let user = try await UserService.shared.fetchUser(byId: searchQuery)
                    print("✅ Found user by ID: \(user.displayName)")
                    foundUser = user
                } catch {
                    print("⚠️ Not found by ID: \(error.localizedDescription)")
                }
            }
            
            // Try as email if still not found
            if foundUser == nil {
                do {
                    if let user = try await UserService.shared.fetchUser(byEmail: searchQuery) {
                        print("✅ Found user by email: \(user.displayName)")
                        foundUser = user
                    }
                } catch {
                    print("⚠️ Error searching by email: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isSearching = false
                
                guard let user = foundUser else {
                    errorMessage = "User not found. Try searching by username (e.g., @username)"
                    return
                }
                
                // Check if adding self
                if user.id == AuthenticationService.shared.currentUser?.id {
                    errorMessage = "You are automatically included in the group"
                    return
                }
                
                // Check for duplicates
                if participants.contains(where: { $0.id == user.id }) {
                    errorMessage = "\(user.displayName) is already added"
                    return
                }
                
                // Add participant
                participants.append(user)
                searchText = ""
                errorMessage = nil
            }
        }
    }
    
    private func removeParticipant(_ user: User) {
        participants.removeAll { $0.id == user.id }
    }
    
    private func createGroup() {
        guard participants.count >= 2 else {
            errorMessage = "Group must have at least 2 other participants (3 total including you)"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                guard let currentUserId = AuthenticationService.shared.currentUser?.id else {
                    throw NSError(domain: "CreateGroupView", code: 401, userInfo: [
                        NSLocalizedDescriptionKey: "Not logged in"
                    ])
                }
                
                // Extract participant IDs
                let participantIds = participants.map { $0.id }
                
                let groupId = try await GroupService.shared.createGroup(
                    name: groupName.isEmpty ? nil : groupName,
                    participantIds: participantIds,
                    creatorId: currentUserId
                )
                
                print("✅ Group created: \(groupId)")
                
                await MainActor.run {
                    isCreating = false
                    // Notify parent with group ID and display name
                    let displayName = groupName.isEmpty ? "Group Chat" : groupName
                    onGroupCreated?(groupId, displayName)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create group: \(error.localizedDescription)"
                    isCreating = false
                }
                print("❌ Group creation failed: \(error)")
            }
        }
    }
}

