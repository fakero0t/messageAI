//
//  UserProfileView.swift
//  swift_demo
//
//  Created by ary on 10/24/25.
//

import SwiftUI

struct UserProfileView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var user: User?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading profile...")
                } else if let user = user {
                    List {
                        Section {
                            VStack(spacing: 16) {
                                // Profile picture/avatar
                                AvatarView(user: user, size: 100)
                                
                                VStack(spacing: 4) {
                                    Text(user.displayName)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Online status
                                OnlineStatusView(
                                    isOnline: user.online,
                                    lastSeen: user.lastSeen
                                )
                                .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .listRowBackground(Color.clear)
                        }
                        
                        Section("Contact Information") {
                            LabeledContent("Email", value: user.email)
                            LabeledContent("Username", value: "@\(user.username)")
                        }
                        
                        Section("Settings") {
                            HStack {
                                Text("Georgian Learning Mode")
                                Spacer()
                                if user.georgianLearningMode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Enabled")
                                        .foregroundColor(.secondary)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                    Text("Disabled")
                                        .foregroundColor(.secondary)
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
                } else {
                    Text("User not found")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUserProfile()
            }
        }
    }
    
    private func loadUserProfile() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let fetchedUser = try await UserService.shared.fetchUser(byId: userId)
                await MainActor.run {
                    user = fetchedUser
                    isLoading = false
                }
            } catch {
                print("❌ Error loading user profile: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load user profile"
                    isLoading = false
                }
            }
        }
    }
}

