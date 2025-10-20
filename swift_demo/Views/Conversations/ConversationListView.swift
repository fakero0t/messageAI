//
//  ConversationListView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ConversationListView: View {
    @State private var showNewChat = false
    @State private var conversations: [String] = [] // Placeholder
    
    var currentUserName: String {
        AuthenticationService.shared.currentUser?.displayName ?? "Messages"
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Conversations Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap the compose button to start a new chat")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(conversations, id: \.self) { conversation in
                            Text(conversation)
                        }
                    }
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
        }
    }
}

