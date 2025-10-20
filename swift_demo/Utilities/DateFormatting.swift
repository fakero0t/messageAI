//
//  DateFormatting.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation

extension Date {
    /// Returns a user-friendly relative or absolute time string for chat messages
    func chatTimestamp() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        // Just now (< 1 minute)
        if let minutes = components.minute, minutes < 1 {
            return "Just now"
        }
        
        // Minutes ago (< 1 hour)
        if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m ago"
        }
        
        // Hours ago (< 24 hours, same day)
        if let hours = components.hour, hours < 24, calendar.isDateInToday(self) {
            return "\(hours)h ago"
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday at \(self.formatted(date: .omitted, time: .shortened))"
        }
        
        // This week
        if let days = components.day, days < 7 {
            let weekday = self.formatted(.dateTime.weekday(.wide))
            let time = self.formatted(date: .omitted, time: .shortened)
            return "\(weekday) at \(time)"
        }
        
        // Older
        return self.formatted(date: .abbreviated, time: .shortened)
    }
    
    /// Returns short timestamp for conversation list
    func conversationTimestamp() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        // Minutes
        if let minutes = components.minute, minutes < 60 {
            return minutes < 1 ? "now" : "\(minutes)m"
        }
        
        // Hours (today)
        if let hours = components.hour, hours < 24, calendar.isDateInToday(self) {
            return "\(hours)h"
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // This week
        if let days = components.day, days < 7 {
            return self.formatted(.dateTime.weekday(.abbreviated))
        }
        
        // Older
        return self.formatted(date: .numeric, time: .omitted)
    }
    
    /// Returns date separator text
    func dateSeparatorText() -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today"
        }
        
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // This week
        let now = Date()
        let components = calendar.dateComponents([.day], from: self, to: now)
        if let days = components.day, days < 7 {
            return self.formatted(.dateTime.weekday(.wide))
        }
        
        // Older
        return self.formatted(date: .abbreviated, time: .omitted)
    }
    
    /// Check if two dates are on the same day
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

