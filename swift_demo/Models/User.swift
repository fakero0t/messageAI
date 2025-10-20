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
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    
    var statusText: String {
        if online {
            return "Online"
        } else if let lastSeen = lastSeen {
            return "Last seen \(lastSeen.relativeTimeString())"
        } else {
            return "Offline"
        }
    }
}

extension Date {
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

