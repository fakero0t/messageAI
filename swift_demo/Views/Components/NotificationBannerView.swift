//
//  NotificationBannerView.swift
//  swift_demo
//
//  Created by ary on 10/21/25.
//

import SwiftUI

struct NotificationBannerView: View {
    @EnvironmentObject private var notificationManager: InAppNotificationManager
    
    var body: some View {
        if let notification = notificationManager.currentNotification {
            VStack {
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(notification.isGroup ? Color.green : avatarColor(for: notification.senderName))
                        .frame(width: 40, height: 40)
                        .overlay {
                            if notification.isGroup {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            } else {
                                Text(notification.senderName.prefix(1).uppercased())
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.isGroup ? "Group: \(notification.senderName)" : notification.senderName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(notification.messageText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Dismiss button
                    Button {
                        notificationManager.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture {
                handleTap(notification: notification)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Swipe up to dismiss
                        if value.translation.height < -50 {
                            print("🔔 [NotificationBannerView] Swiped up to dismiss")
                            notificationManager.dismiss()
                        }
                    }
            )
        }
    }
    
    private func handleTap(notification: InAppNotification) {
        print("🔔 [NotificationBannerView] Banner tapped - navigating to: \(notification.conversationId)")
        notificationManager.dismiss()
        
        // Navigate to conversation
        NotificationCenter.default.post(
            name: .navigateToConversation,
            object: nil,
            userInfo: ["conversationId": notification.conversationId]
        )
    }
    
    private func avatarColor(for name: String) -> Color {
        // Generate consistent color based on name
        let colors: [Color] = [.blue, .purple, .pink, .orange, .red, .indigo]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

