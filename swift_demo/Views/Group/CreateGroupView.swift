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
    @State private var participantIds: [String] = []
    @State private var newParticipantId = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var navigateToGroup = false
    @State private var createdGroupId: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("Enter group name (optional)", text: $groupName)
                }
                
                Section {
                    TextField("Enter User ID", text: $newParticipantId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Button("Add Participant") {
                        addParticipant()
                    }
                    .disabled(newParticipantId.isEmpty)
                } header: {
                    Text("Participants")
                } footer: {
                    Text("Add at least 2 other participants (3 total including you)")
                        .font(.caption)
                }
                
                if !participantIds.isEmpty {
                    Section("Added Participants (\(participantIds.count))") {
                        ForEach(participantIds, id: \.self) { participantId in
                            HStack {
                                Text(participantId)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button {
                                    removeParticipant(participantId)
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
                        .disabled(participantIds.count < 2)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToGroup) {
                if let groupId = createdGroupId {
                    // Navigate to group chat
                    // For now, just dismiss - full group chat in PR-17
                    Text("Group created: \(groupId)")
                }
            }
        }
    }
    
    private func addParticipant() {
        let trimmed = newParticipantId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Check for duplicates
        if participantIds.contains(trimmed) {
            errorMessage = "This participant is already added"
            return
        }
        
        // Check if adding self
        if trimmed == AuthenticationService.shared.currentUser?.id {
            errorMessage = "You are automatically included in the group"
            return
        }
        
        participantIds.append(trimmed)
        newParticipantId = ""
        errorMessage = nil
    }
    
    private func removeParticipant(_ id: String) {
        participantIds.removeAll { $0 == id }
    }
    
    private func createGroup() {
        guard participantIds.count >= 2 else {
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
                
                let groupId = try await GroupService.shared.createGroup(
                    name: groupName.isEmpty ? nil : groupName,
                    participantIds: participantIds,
                    creatorId: currentUserId
                )
                
                print("✅ Group created: \(groupId)")
                
                await MainActor.run {
                    createdGroupId = groupId
                    isCreating = false
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

