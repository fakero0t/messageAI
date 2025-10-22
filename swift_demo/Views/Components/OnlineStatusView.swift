//
//  OnlineStatusView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI
import Combine

struct OnlineStatusView: View {
    let isOnline: Bool
    let lastSeen: Date?
    
    // Timer to update relative time every 10 seconds
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOnline ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onReceive(timer) { _ in
            // Update current time to trigger statusText recalculation
            currentTime = Date()
        }
    }
    
    private var statusText: String {
        if isOnline {
            return "Online"
        } else if let lastSeen = lastSeen {
            // Using currentTime in calculation ensures it updates with the timer
            let _ = currentTime // Force dependency on currentTime
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
}

