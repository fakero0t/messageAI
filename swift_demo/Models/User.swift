//
//  User.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let username: String // Unique username for user lookup
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    var profileImageUrl: String? // PR-12: Profile picture URL
    
    var statusText: String {
        if online {
            return "Online"
        } else if let lastSeen = lastSeen {
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
    
    // PR-12: Generate initials for avatar fallback
    var initials: String {
        let components = displayName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return String(initials).uppercased()
    }
}

extension Date {
    func relativeTimeString() -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        
        // Ensure we never show "0s" or "in 0s" - minimum is "1s ago"
        guard timeInterval > 0 else {
            return "1s ago"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        // For very recent times (< 1 second), show "1s ago"
        if timeInterval < 1.0 {
            return "1s ago"
        }
        
        return formatter.localizedString(for: self, relativeTo: now)
    }
}

