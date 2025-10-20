//
//  ChatView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ChatView: View {
    let recipientId: String
    let recipientName: String
    @State private var messageText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list placeholder
            ScrollView {
                VStack {
                    Spacer()
                    Text("Start chatting with \(recipientName)")
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        // Placeholder - will be implemented in later PR
        print("Sending message: \(messageText)")
        messageText = ""
    }
}

