//
//  ReadReceiptView.swift
//  swift_demo
//
//  Read receipt display under last message from current user
//

import SwiftUI
import SwiftData

struct ReadReceiptView: View {
    let message: MessageEntity
    let participants: [String]
    let currentUserId: String
    let isLastFromCurrentUser: Bool
    
    @State private var receiptText: String? = nil
    
    // Recompute receipt text when message read receipt data changes
    // This ensures the view updates when deliveredTo or readBy arrays change
    private var receiptDataId: String {
        // Create a unique ID based on read receipt arrays to trigger .task when they change
        "\(message.deliveredTo.sorted().joined(separator: ","))_\(message.readBy.sorted().joined(separator: ","))_\(message.deliveredAt?.timeIntervalSince1970 ?? 0)_\(message.readAt?.timeIntervalSince1970 ?? 0)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLastFromCurrentUser {
                if let text = receiptText {
                    Text(text)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .task(id: receiptDataId) {
            print("🔄 [ReadReceiptView] Task triggered for message \(message.id.prefix(8))")
            print("   isLastFromCurrentUser: \(isLastFromCurrentUser)")
            print("   participants: \(participants)")
            print("   currentUserId: \(currentUserId)")
            print("   receiptDataId: \(receiptDataId)")
            updateReceiptText()
        }
        .onAppear {
            print("👁️ [ReadReceiptView] onAppear for message \(message.id.prefix(8))")
            print("   isLastFromCurrentUser: \(isLastFromCurrentUser)")
            print("   participants count: \(participants.count)")
            updateReceiptText()
        }
    }
    
    private func updateReceiptText() {
        print("🔍 [ReadReceiptView] updateReceiptText called")
        print("   Message: \(message.id.prefix(8))")
        print("   Participants passed to view: \(participants)")
        print("   Current user ID: \(currentUserId)")
        print("   Message sender ID: \(message.senderId)")
        print("   Message deliveredTo: \(message.deliveredTo)")
        print("   Message readBy: \(message.readBy)")
        
        let newText = ReadReceiptService.shared.readReceiptText(
            message: message,
            participants: participants,
            currentUserId: currentUserId
        )
        
        if newText != receiptText {
            print("🔄 [ReadReceiptView] Receipt text changed for message \(message.id.prefix(8))")
            print("   Old: \(receiptText ?? "nil")")
            print("   New: \(newText ?? "nil")")
            receiptText = newText
        } else {
            print("⚠️ [ReadReceiptView] Receipt text unchanged: \(receiptText ?? "nil")")
        }
    }
}

