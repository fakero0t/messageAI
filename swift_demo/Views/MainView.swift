//
//  MainView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var conversationToNavigateTo: String?
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ConversationListView(conversationToNavigateTo: $conversationToNavigateTo)
                    .tabItem {
                        Label("Chats", systemImage: "message")
                    }
                    .tag(0)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .tag(1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    print("📲 Navigating to conversation: \(conversationId)")
                    selectedTab = 0 // Switch to Chats tab
                    conversationToNavigateTo = conversationId
                }
            }
            
            // In-app notification banner overlay
            VStack {
                NotificationBannerView()
                Spacer()
            }
            .allowsHitTesting(true)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var currentUser: User? {
        AuthenticationService.shared.currentUser
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = currentUser {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.displayName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            OnlineStatusView(isOnline: user.online, lastSeen: user.lastSeen)
                        }
                        
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(user.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        // Test system notification
                        NotificationService.shared.showMessageNotification(
                            conversationId: "test-123",
                            senderName: "Test User",
                            messageText: "This is a test notification!",
                            isGroup: false
                        )
                    }) {
                        HStack {
                            Spacer()
                            Text("Test System Notification")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        // Test in-app banner
                        let notification = InAppNotification(
                            conversationId: "test-123",
                            senderName: "Test User",
                            messageText: "This is a test in-app notification banner! It should appear at the top of the screen.",
                            isGroup: false
                        )
                        InAppNotificationManager.shared.show(notification)
                    }) {
                        HStack {
                            Spacer()
                            Text("Test In-App Banner")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        // Test group notification
                        let notification = InAppNotification(
                            conversationId: "test-group-456",
                            senderName: "Cool Group",
                            messageText: "Someone sent a message in this group chat!",
                            isGroup: true
                        )
                        InAppNotificationManager.shared.show(notification)
                    }) {
                        HStack {
                            Spacer()
                            Text("Test Group Banner")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

