//
//  ConversationListView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showNewChat = false
    
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .refreshable {
                viewModel.loadConversations()
            }
        }
    }
    
    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conversationDetail in
                NavigationLink {
                    ChatView(
                        recipientId: conversationDetail.recipientId,
                        recipientName: conversationDetail.displayName,
                        conversationId: conversationDetail.conversation.id
                    )
                } label: {
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
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
