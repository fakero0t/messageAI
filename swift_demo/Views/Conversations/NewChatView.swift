//
//  NewChatView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var userIdOrEmail = ""
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
                    
                    Text("Enter the user ID or email of the person you want to chat with")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                TextField("User ID or Email", text: $userIdOrEmail)
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
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(userIdOrEmail.isEmpty || isLoading)
                
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
                CreateGroupView()
            }
        }
    }
    
    private func searchUser() {
        Task {
            isLoading = true
            errorMessage = nil
            
            // Try as user ID first
            do {
                let user = try await UserService.shared.fetchUser(byId: userIdOrEmail)
                print("✅ Found user by ID: \(user.displayName)")
                await createConversationAndNavigate(with: user)
                return
            } catch {
                print("⚠️ Not found by ID: \(error.localizedDescription)")
            }
            
            // Try as email
            do {
                if let user = try await UserService.shared.fetchUser(byEmail: userIdOrEmail) {
                    print("✅ Found user by email: \(user.displayName)")
                    await createConversationAndNavigate(with: user)
                    return
                }
            } catch {
                print("⚠️ Error searching by email: \(error.localizedDescription)")
            }
            
            print("❌ User not found for input: \(userIdOrEmail)")
            errorMessage = "User not found"
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

