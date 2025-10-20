//
//  MessageStatus.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation

enum MessageStatus: String, Codable {
    case pending
    case sent
    case delivered
    case read
    case failed
    
    var displayText: String {
        switch self {
        case .pending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
}

