//
//  FailedMessageActionsView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct FailedMessageActionsView: View {
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.georgianRed)
            }
            .buttonStyle(.borderless)
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.top, 4)
    }
}

