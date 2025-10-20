//
//  OnlineStatusView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct OnlineStatusView: View {
    let isOnline: Bool
    let lastSeen: Date?
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOnline ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusText: String {
        if isOnline {
            return "Online"
        } else if let lastSeen = lastSeen {
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
}

