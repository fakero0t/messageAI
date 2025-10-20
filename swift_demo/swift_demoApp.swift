//
//  swift_demoApp.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct swift_demoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationService = NotificationService.shared

    init() {
        // Initialize network monitoring
        _ = NetworkMonitor.shared
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                MainView()
                    .environmentObject(authViewModel)
                    .environmentObject(notificationService)
                    .task {
                        // Request notification permissions
                        notificationService.requestAuthorization()
                        
                        // Perform crash recovery and process queue on app launch
                        await performAppLaunchTasks()
                    }
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .modelContainer(PersistenceController.shared.container)
    }
    
    private func performAppLaunchTasks() async {
        print("🚀 Running app launch tasks...")
        
        // Small delay to ensure auth and persistence are ready
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // 1. Perform crash recovery first
        await CrashRecoveryService.shared.performRecovery()
        
        // 2. Process message queue
        await MessageQueueService.shared.processQueue()
        
        print("✅ App launch tasks complete")
    }
}
