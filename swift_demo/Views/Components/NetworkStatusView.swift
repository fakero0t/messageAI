//
//  NetworkStatusView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var queueService = MessageQueueService.shared
    
    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                statusIcon
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if queueService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .cornerRadius(16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private var shouldShow: Bool {
        networkMonitor.connectionQuality == .offline ||
        networkMonitor.connectionQuality == .poor ||
        queueService.queueCount > 0
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch networkMonitor.connectionQuality {
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
        case .poor:
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.orange)
        case .fair:
            Image(systemName: "wifi")
                .foregroundColor(.yellow)
        case .good, .excellent:
            if queueService.queueCount > 0 {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var statusText: String {
        switch networkMonitor.connectionQuality {
        case .offline:
            if queueService.queueCount > 0 {
                return "Offline • \(queueService.queueCount) queued"
            }
            return "Offline • Messages will send when connected"
            
        case .poor:
            if queueService.queueCount > 0 {
                return "Poor connection • \(queueService.queueCount) queued"
            }
            return "Poor connection • Messages may be delayed"
            
        case .fair:
            if queueService.queueCount > 0 {
                return "Sending \(queueService.queueCount)..."
            }
            return ""
            
        case .good, .excellent:
            if queueService.queueCount > 0 {
                return "Sending \(queueService.queueCount)..."
            }
            return ""
        }
    }
    
    private var backgroundColor: Color {
        switch networkMonitor.connectionQuality {
        case .offline:
            return Color.red.opacity(0.1)
        case .poor:
            return Color.orange.opacity(0.15)
        case .fair:
            return Color.yellow.opacity(0.1)
        case .good, .excellent:
            return Color(.systemGray6)
        }
    }
}

