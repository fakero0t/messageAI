//
//  ConversationRowView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ConversationRowView: View {
    let conversationDetail: ConversationWithDetails
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if conversationDetail.conversation.isGroup {
                // Group avatar
                Circle()
                    .fill(Color.green)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
            } else {
                // Individual avatar
                Circle()
                    .fill(avatarColor)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(conversationDetail.displayAvatar)
                            .foregroundColor(.white)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
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
                    if let lastMessage = conversationDetail.conversation.lastMessageText {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(hasUnreadMessages ? .primary : .secondary)
                            .fontWeight(hasUnreadMessages ? .medium : .regular)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Spacer()
                    
                    if conversationDetail.conversation.unreadCount > 0 {
                        Text("\(conversationDetail.conversation.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            hasUnreadMessages 
                ? Color.blue.opacity(0.05) 
                : Color.clear
        )
    }
    
    private var hasUnreadMessages: Bool {
        conversationDetail.conversation.unreadCount > 0
    }
    
    private var avatarColor: Color {
        // Generate color based on conversation ID for consistency
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let index = abs(conversationDetail.id.hashValue) % colors.count
        return colors[index]
    }
}

