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
        print("🔔 [NotificationService] Initializing...")
    }
    
    func setup() {
        print("🔔 [NotificationService] Setting up delegate...")
        UNUserNotificationCenter.current().delegate = self
        checkNotificationSettings()
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = settings.authorizationStatus == .authorized
                print("🔔 Notification settings checked: \(settings.authorizationStatus.rawValue)")
                print("   Authorized: \(self.notificationPermissionGranted)")
            }
        }
    }
    
    func requestAuthorization() {
        print("🔔 [NotificationService] Requesting authorization...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
                print("🔔 [NotificationService] Permission request result: \(granted)")
                print("   notificationPermissionGranted is now: \(self.notificationPermissionGranted)")
            }
            
            if let error = error {
                print("❌ [NotificationService] Error requesting notification authorization: \(error)")
                return
            }
            
            if granted {
                print("✅ [NotificationService] Notification permissions GRANTED")
            } else {
                print("⚠️ [NotificationService] Notification permissions DENIED by user")
            }
        }
    }
    
    func showMessageNotification(
        conversationId: String,
        senderName: String,
        messageText: String,
        isGroup: Bool
    ) {
        print("🔔 Attempting to show notification from \(senderName): \(messageText)")
        print("   Current conversation: \(currentConversationId ?? "nil")")
        print("   Target conversation: \(conversationId)")
        print("   Permission granted: \(notificationPermissionGranted)")
        
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

