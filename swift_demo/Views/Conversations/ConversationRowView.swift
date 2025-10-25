//
//  ConversationRowView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ConversationRowView: View {
    let conversationDetail: ConversationWithDetails
    
    @State private var otherUser: User?
    
    var body: some View {
        HStack(spacing: 12) {
            // PR-15: Avatar
            if conversationDetail.conversation.isGroup {
                // Group icon (no avatar, just colored circle with icon)
                ZStack {
                    Circle()
                        .fill(Color.georgianRed.opacity(0.2))
                        .frame(width: AvatarView.sizeMedium, height: AvatarView.sizeMedium)
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.georgianRed)
                }
            } else {
                // User avatar with profile picture support
                AvatarView(user: otherUser, size: AvatarView.sizeMedium)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversationDetail.displayName)
                        .font(.headline)
                        .fontWeight(hasUnreadMessages ? .bold : .regular)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessageTime = conversationDetail.conversation.lastMessageTime {
                        Text(lastMessageTime.conversationTimestamp())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(hasUnreadMessages ? .semibold : .regular)
                    }
                }
                
                HStack {
                    Text(lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(hasUnreadMessages ? .primary : .secondary)
                        .fontWeight(hasUnreadMessages ? .semibold : .regular)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if conversationDetail.conversation.unreadCount > 0 {
                        Text("\(conversationDetail.conversation.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.georgianRed)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            hasUnreadMessages 
                ? Color.georgianRed.opacity(0.05) 
                : Color.clear
        )
        .task {
            await loadOtherUser()
        }
    }
    
    // PR-15: Last message preview with image support
    private var lastMessagePreview: String {
        if let lastMessage = conversationDetail.conversation.lastMessageText {
            // Check if it's "Image" (from image messages)
            if lastMessage == "Image" {
                return "📷 Image"
            }
            return lastMessage
        } else {
            return "No messages yet"
        }
    }
    
    private var hasUnreadMessages: Bool {
        conversationDetail.conversation.unreadCount > 0
    }
    
    // PR-15: Load other user data for avatar
    private func loadOtherUser() async {
        guard !conversationDetail.conversation.isGroup else { return }
        
        // Get current user ID
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        
        // Find other user ID from participants
        let otherUserId = conversationDetail.conversation.participantIds.first { $0 != currentUserId }
        
        guard let userId = otherUserId else { return }
        
        // Fetch user from UserService
        do {
            let user = try await UserService.shared.fetchUser(byId: userId)
            await MainActor.run {
                self.otherUser = user
            }
        } catch {
            print("❌ [ConversationRow] Failed to load user \(userId): \(error)")
        }
    }
}

