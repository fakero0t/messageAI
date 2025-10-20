//
//  NotificationService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import UserNotifications
import Combine

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var notificationPermissionGranted = false
    @Published var currentConversationId: String? // Track which conversation user is viewing
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
            }
            
            if let error = error {
                print("❌ Error requesting notification authorization: \(error)")
                return
            }
            
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("⚠️ Notification permissions denied")
            }
        }
    }
    
    func showMessageNotification(
        conversationId: String,
        senderName: String,
        messageText: String,
        isGroup: Bool
    ) {
        // Don't show notification if user is currently viewing this conversation
        guard currentConversationId != conversationId else {
            print("🔕 Suppressing notification - user in conversation")
            return
        }
        
        guard notificationPermissionGranted else {
            print("⚠️ Cannot show notification - permission not granted")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = isGroup ? "Group: \(senderName)" : senderName
        content.body = messageText
        content.sound = .default
        
        // Add conversation ID to userInfo for tap handling
        content.userInfo = [
            "conversationId": conversationId,
            "isGroup": isGroup
        ]
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Add notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error showing notification: \(error)")
            } else {
                print("🔔 Notification shown: \(senderName) - \(messageText)")
            }
        }
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Error clearing badge: \(error)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Check if user is currently in the conversation
        if let conversationId = userInfo["conversationId"] as? String {
            if currentConversationId == conversationId {
                // User is viewing this conversation - don't show notification
                completionHandler([])
                return
            }
        }
        
        // Show notification banner
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("👆 Notification tapped")
        
        // Navigate to conversation
        if let conversationId = userInfo["conversationId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let navigateToConversation = Notification.Name("navigateToConversation")
}

