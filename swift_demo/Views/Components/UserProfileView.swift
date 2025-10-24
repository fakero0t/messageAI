//
//  UserProfileView.swift
//  swift_demo
//
//  Created by ary on 10/24/25.
//

import SwiftUI
import Combine

struct UserProfileView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var user: User?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
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
            .onDisappear {
                // Clean up listener
                cancellables.removeAll()
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
                    
                    // Start observing real-time status updates
                    observeUserStatus()
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
    
    private func observeUserStatus() {
        print("👤 [UserProfileView] Setting up real-time status observer for user: \(userId)")
        
        UserService.shared.observeUserStatus(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [userId] updatedUser in
                guard let updatedUser = updatedUser else { return }
                
                user = updatedUser
                print("🔄 [UserProfileView] Updated status for \(updatedUser.displayName): online=\(updatedUser.online)")
            }
            .store(in: &cancellables)
        
        print("✅ [UserProfileView] Real-time status observer active")
    }
}

