//
//  NewChatView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showCreateGroup = false
    
    // Callback to notify parent of selected conversation
    var onConversationCreated: ((String, User) -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // One-on-One Chat Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start One-on-One Chat")
                        .font(.headline)
                    
                    Text("Enter username (e.g., @john_doe), email, or user ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                TextField("Username, Email, or User ID", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: searchUser) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Start Chat")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.georgianRed)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(searchText.isEmpty || isLoading)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4))
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4))
                }
                .padding()
                
                // Group Chat Section
                Button {
                    showCreateGroup = true
                } label: {
                    Label("Create Group Chat", systemImage: "person.3.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView { groupId, groupName in
                    // Navigate to the newly created group chat
                    onConversationCreated?(groupId, User(
                        id: groupId,
                        email: "",
                        username: "group",
                        displayName: groupName
                    ))
                    // Dismiss NewChatView so user goes directly to the group chat
                    dismiss()
                }
            }
        }
    }
    
    private func searchUser() {
        Task {
            isLoading = true
            errorMessage = nil
            
            // Normalize search text
            var searchQuery = searchText.trimmingCharacters(in: .whitespaces)
            
            // Remove @ prefix if searching by username
            if searchQuery.hasPrefix("@") {
                searchQuery = String(searchQuery.dropFirst())
            }
            
            // Try as username first (most common use case)
            do {
                if let user = try await UserService.shared.fetchUser(byUsername: searchQuery) {
                    print("✅ Found user by username: \(user.displayName) (@\(user.username))")
                    await createConversationAndNavigate(with: user)
                    return
                }
            } catch {
                print("⚠️ Error searching by username: \(error.localizedDescription)")
            }
            
            // Try as user ID
            do {
                let user = try await UserService.shared.fetchUser(byId: searchQuery)
                print("✅ Found user by ID: \(user.displayName)")
                await createConversationAndNavigate(with: user)
                return
            } catch {
                print("⚠️ Not found by ID: \(error.localizedDescription)")
            }
            
            // Try as email
            do {
                if let user = try await UserService.shared.fetchUser(byEmail: searchQuery) {
                    print("✅ Found user by email: \(user.displayName)")
                    await createConversationAndNavigate(with: user)
                    return
                }
            } catch {
                print("⚠️ Error searching by email: \(error.localizedDescription)")
            }
            
            print("❌ User not found for input: \(searchQuery)")
            errorMessage = "User not found. Try searching by username (e.g., @username)"
            isLoading = false
        }
    }
    
    private func createConversationAndNavigate(with user: User) async {
        do {
            guard let currentUserId = AuthenticationService.shared.currentUser?.id else {
                errorMessage = "Not logged in"
                isLoading = false
                return
            }
            
            // Create or get conversation
            let conversationId = try await ConversationService.shared.getOrCreateConversation(
                userId1: currentUserId,
                userId2: user.id
            )
            
            print("💬 Conversation ready: \(conversationId)")
            
            await MainActor.run {
                isLoading = false
                // Notify parent and dismiss
                onConversationCreated?(conversationId, user)
                dismiss()
            }
            
        } catch {
            print("❌ Failed to create conversation: \(error)")
            errorMessage = "Failed to start chat"
            isLoading = false
        }
    }
}

