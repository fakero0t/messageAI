//
//  ReadReceiptView.swift
//  swift_demo
//
//  Read receipt display under last message from current user
//

import SwiftUI
import SwiftData

struct ReadReceiptView: View {
    @Bindable var message: MessageEntity
    let participants: [String]
    let currentUserId: String
    let isLastFromCurrentUser: Bool
    
    var body: some View {
        if isLastFromCurrentUser,
           let receiptText = ReadReceiptService.shared.readReceiptText(
            message: message,
            participants: participants,
            currentUserId: currentUserId
           ) {
            Text(receiptText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

