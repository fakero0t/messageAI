//
//  InAppNotificationManager.swift
//  swift_demo
//
//  Created by ary on 10/21/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class InAppNotificationManager: ObservableObject {
    static let shared = InAppNotificationManager()
    
    @Published var currentNotification: InAppNotification?
    
    private var dismissTask: Task<Void, Never>?
    private let autoDismissDelay: TimeInterval = 3.0
    
    private init() {
        print("🔔 [InAppNotificationManager] Initialized")
    }
    
    /// Show a new in-app notification banner
    /// - Parameter notification: The notification to display
    func show(_ notification: InAppNotification) {
        print("🔔 [InAppNotificationManager] Showing notification from: \(notification.senderName)")
        print("   Message: \(notification.messageText)")
        print("   Conversation: \(notification.conversationId)")
        
        // Cancel any existing auto-dismiss task
        dismissTask?.cancel()
        
        // Show new notification with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentNotification = notification
        }
        
        // Schedule auto-dismiss after delay
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
            if !Task.isCancelled {
                print("🔔 [InAppNotificationManager] Auto-dismissing notification")
                self.dismiss()
            }
        }
    }
    
    /// Dismiss the current notification
    func dismiss() {
        print("🔔 [InAppNotificationManager] Dismissing notification")
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            currentNotification = nil
        }
    }
}

