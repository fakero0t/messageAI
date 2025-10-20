//
//  swift_demoApp.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI
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
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                MainView()
                    .environmentObject(authViewModel)
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
    }
}
