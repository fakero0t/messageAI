//
//  GroupInfoView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct GroupInfoView: View {
    let groupId: String
    @Environment(\.dismiss) private var dismiss
    @State private var conversation: ConversationEntity?
    @State private var participants: [User] = []
    @State private var isCreator = false
    @State private var showAddParticipant = false
    @State private var newParticipantId = ""
    @State private var errorMessage: String?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading group info...")
                } else {
                    List {
                        Section("Group Details") {
                            if let conversation = conversation {
                                LabeledContent("Name", value: conversation.groupName ?? "Unnamed Group")
                                LabeledContent("Members", value: "\(conversation.participantIds.count)")
                                
                                if let creatorId = conversation.createdBy,
                                   let creator = participants.first(where: { $0.id == creatorId }) {
                                    LabeledContent("Created by", value: creator.displayName)
                                }
                            }
                        }
                        
                        Section("Participants") {
                            ForEach(participants) { participant in
                                HStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Text(participant.displayName.prefix(1).uppercased())
                                                .foregroundColor(.white)
                                        }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(participant.displayName)
                                            .font(.headline)
                                        
                                        OnlineStatusView(
                                            isOnline: participant.online,
                                            lastSeen: participant.lastSeen
                                        )
                                    }
                                    
                                    Spacer()
                                    
                                    // Only creator can remove others (not themselves)
                                    if isCreator && participant.id != conversation?.createdBy {
                                        Button(role: .destructive) {
                                            removeParticipant(participant.id)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                            
                            if isCreator {
                                Button {
                                    showAddParticipant = true
                                } label: {
                                    Label("Add Participant", systemImage: "person.badge.plus")
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
                        
                        Section {
                            Button("Leave Group", role: .destructive) {
                                leaveGroup()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Add Participant", isPresented: $showAddParticipant) {
                TextField("User ID", text: $newParticipantId)
                    .textInputAutocapitalization(.never)
                
                Button("Cancel", role: .cancel) {
                    newParticipantId = ""
                }
                
                Button("Add") {
                    addParticipant()
                }
            } message: {
                Text("Enter the user ID of the person you want to add")
            }
            .onAppear {
                loadGroupInfo()
            }
        }
    }
    
    private func loadGroupInfo() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // Load conversation
                conversation = try await MainActor.run {
                    try LocalStorageService.shared.fetchConversation(byId: groupId)
                }
                
                // Load participants
                if let conversation = conversation {
                    participants = []
                    for participantId in conversation.participantIds {
                        if let user = try? await UserService.shared.fetchUser(byId: participantId) {
                            participants.append(user)
                        }
                    }
                    
                    // Check if current user is creator
                    let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                    isCreator = try await GroupService.shared.isCreator(groupId: groupId, userId: currentUserId)
                }
                
                isLoading = false
                
            } catch {
                print("❌ Error loading group info: \(error)")
                errorMessage = "Failed to load group info"
                isLoading = false
            }
        }
    }
    
    private func addParticipant() {
        guard !newParticipantId.isEmpty else { return }
        
        Task {
            do {
                let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                
                try await GroupService.shared.addParticipant(
                    groupId: groupId,
                    userId: newParticipantId,
                    requesterId: currentUserId
                )
                
                print("✅ Participant added")
                newParticipantId = ""
                loadGroupInfo() // Reload
                
            } catch {
                print("❌ Error adding participant: \(error)")
                errorMessage = "Failed to add participant: \(error.localizedDescription)"
            }
        }
    }
    
    private func removeParticipant(_ userId: String) {
        Task {
            do {
                let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                
                try await GroupService.shared.removeParticipant(
                    groupId: groupId,
                    userId: userId,
                    requesterId: currentUserId
                )
                
                print("✅ Participant removed")
                loadGroupInfo() // Reload
                
            } catch {
                print("❌ Error removing participant: \(error)")
                errorMessage = "Failed to remove participant: \(error.localizedDescription)"
            }
        }
    }
    
    private func leaveGroup() {
        Task {
            do {
                let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                
                // For leaving, we need to allow self-removal
                // Use Firestore directly to bypass creator check
                try await GroupService.shared.removeParticipant(
                    groupId: groupId,
                    userId: currentUserId,
                    requesterId: currentUserId
                )
                
                print("✅ Left group")
                
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                print("❌ Error leaving group: \(error)")
                errorMessage = "Failed to leave group: \(error.localizedDescription)"
            }
        }
    }
}

