//
//  MessageInputView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isFocused)
            
            Button(action: {
                onSend()
                isFocused = true // Keep keyboard open after sending
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty ? .gray : .blue)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

