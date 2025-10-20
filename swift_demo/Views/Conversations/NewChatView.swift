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
    @State private var navigateToChat = false
    @State private var selectedUser: User?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start New Chat")
                        .font(.headline)
                    
                    Text("Enter the user ID or email of the person you want to chat with")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
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
            .navigationDestination(isPresented: $navigateToChat) {
                if let user = selectedUser {
                    ChatView(recipientId: user.id, recipientName: user.displayName)
                }
            }
        }
    }
    
    private func searchUser() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // Try as user ID first
                if let user = try? await UserService.shared.fetchUser(byId: userIdOrEmail) {
                    selectedUser = user
                    navigateToChat = true
                    return
                }
                
                // Try as email
                if let user = try await UserService.shared.fetchUser(byEmail: userIdOrEmail) {
                    selectedUser = user
                    navigateToChat = true
                    return
                }
                
                errorMessage = "User not found"
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

