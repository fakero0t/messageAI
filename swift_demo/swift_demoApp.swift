//
//  swift_demoApp.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    print("🎉🎉🎉 APP IS LAUNCHING WITH NEW CODE! 🎉🎉🎉")
    
    // Configure App Check for debug mode in simulator
    #if targetEnvironment(simulator)
    let providerFactory = AppCheckDebugProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)
    print("📱 Using App Check Debug Provider for Simulator")
    #else
    // Use DeviceCheck for physical devices
    let providerFactory = AppCheckDebugProviderFactory() // Can switch to DeviceCheckProviderFactory in production
    AppCheck.setAppCheckProviderFactory(providerFactory)
    #endif
    
    FirebaseApp.configure()
    print("✅ Firebase configured successfully")
    return true
  }
}

@main
struct swift_demoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var inAppNotificationManager = InAppNotificationManager.shared

    init() {
        // Initialize network monitoring
        _ = NetworkMonitor.shared
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isInitializing {
                // Show loading screen while checking authentication
                LoadingView()
            } else if authViewModel.isAuthenticated {
                MainView()
                    .environmentObject(authViewModel)
                    .environmentObject(notificationService)
                    .environmentObject(inAppNotificationManager)
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

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "message.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
