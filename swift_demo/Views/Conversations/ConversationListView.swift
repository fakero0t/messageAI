//
//  ConversationListView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @ObservedObject private var authService = AuthenticationService.shared
    @State private var showNewChat = false
    @State private var pendingNavigation: PendingNavigation?
    @Binding var conversationToNavigateTo: String?
    
    // Access current user to check Georgian Learning Mode
    private var currentUser: User? {
        authService.currentUser
    }

    struct PendingNavigation: Identifiable, Hashable {
        let id = UUID()
        let conversationId: String
        let user: User
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: PendingNavigation, rhs: PendingNavigation) -> Bool {
            lhs.id == rhs.id
        }
    }

    init(conversationToNavigateTo: Binding<String?> = .constant(nil)) {
        _conversationToNavigateTo = conversationToNavigateTo
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: ConversationWithDetails.self) { conversationDetail in
                ChatView(
                    recipientId: conversationDetail.recipientId,
                    recipientName: conversationDetail.displayName,
                    conversationId: conversationDetail.conversation.id
                )
            }
            .navigationDestination(for: String.self) { conversationId in
                // Navigate by conversation ID (from notification)
                if let conversation = viewModel.conversations.first(where: { $0.conversation.id == conversationId }) {
                    ChatView(
                        recipientId: conversation.recipientId,
                        recipientName: conversation.displayName,
                        conversationId: conversation.conversation.id
                    )
                }
            }
            .navigationDestination(item: $pendingNavigation) { pending in
                // Navigate from new chat
                ChatView(
                    recipientId: pending.user.id,
                    recipientName: pending.user.displayName,
                    conversationId: pending.conversationId
                )
            }
            .toolbar {
                // Custom title with Georgian flag when in learning mode
                if currentUser?.georgianLearningMode == true {
                    ToolbarItem(placement: .principal) {
                        Text("🇬🇪")
                            .font(.title)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView { conversationId, user in
                    // Handle conversation creation (both 1-on-1 and group)
                    pendingNavigation = PendingNavigation(conversationId: conversationId, user: user)
                    // Refresh the conversation list to show the new chat
                    viewModel.loadConversations()
                }
            }
            .refreshable {
                viewModel.loadConversations()
            }
            .onChange(of: conversationToNavigateTo) { oldValue, newValue in
                if let conversationId = newValue {
                    // Trigger navigation by setting navigation path
                    // This is a workaround - in production, use proper navigation state management
                    print("🔔 Should navigate to: \(conversationId)")
                    conversationToNavigateTo = nil
                }
            }
        }
    }
    
    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conversationDetail in
                NavigationLink(value: conversationDetail) {
                    ConversationRowView(conversationDetail: conversationDetail)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Conversations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a new chat to begin messaging")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showNewChat = true
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.georgianRed)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
