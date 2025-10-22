//
//  AuthViewModel.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published var confirmPassword = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var isCheckingUsername = false
    @Published var isInitializing = true // Track initial auth check
    
    private let authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        authService.$currentUser
            .map { $0 != nil }
            .assign(to: &$isAuthenticated)
        
        // Mark initialization complete after first auth state check
        // Use a small delay to give Firebase Auth time to check for existing session
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                self.isInitializing = false
            }
        }
        
        // Reset loading state when auth succeeds
        $isAuthenticated
            .filter { $0 == true }
            .sink { [weak self] _ in
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    func login() async {
        // Validate fields
        if email.isEmpty && password.isEmpty {
            errorMessage = "Please enter your email and password"
            return
        }
        
        if email.isEmpty {
            errorMessage = "Please enter your email address"
            return
        }
        
        if password.isEmpty {
            errorMessage = "Please enter your password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            // isLoading will be reset by the isAuthenticated listener
        } catch {
            errorMessage = getFriendlyErrorMessage(from: error)
            isLoading = false
        }
    }
    
    func signup() async {
        guard validateSignupForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password, username: username, displayName: displayName)
        } catch {
            errorMessage = getFriendlyErrorMessage(from: error)
        }
        
        isLoading = false
    }
    
    func checkUsernameAvailability() async {
        guard !username.isEmpty else { return }
        
        // Validate format first
        guard isValidUsername(username) else {
            errorMessage = "Username must be 3-20 characters (letters, numbers, and underscores only)"
            return
        }
        
        isCheckingUsername = true
        errorMessage = nil
        
        do {
            let isAvailable = try await UserService.shared.isUsernameAvailable(username)
            if !isAvailable {
                errorMessage = "Username '@\(username)' is already taken. Please choose another."
            }
        } catch {
            errorMessage = "Couldn't verify username availability. Please try again."
        }
        
        isCheckingUsername = false
    }
    
    func logout() {
        do {
            // Clear all local data before logging out
            print("🗑️ Clearing local storage on logout...")
            Task { @MainActor in
                do {
                    try LocalStorageService.shared.clearAllData()
                } catch {
                    print("⚠️ Error clearing local data: \(error)")
                }
            }
            
            try authService.signOut()
            
            // Clear form fields
            email = ""
            password = ""
            username = ""
            displayName = ""
            confirmPassword = ""
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't sign out. Please try again."
        }
    }
    
    func validateSignupForm() -> Bool {
        // Check for empty fields
        if username.isEmpty {
            errorMessage = "Please enter a username"
            return false
        }
        
        if displayName.isEmpty {
            errorMessage = "Please enter your display name"
            return false
        }
        
        if email.isEmpty {
            errorMessage = "Please enter your email address"
            return false
        }
        
        if password.isEmpty {
            errorMessage = "Please create a password"
            return false
        }
        
        if confirmPassword.isEmpty {
            errorMessage = "Please confirm your password"
            return false
        }
        
        // Validate username format
        if !isValidUsername(username) {
            errorMessage = "Username must be 3-20 characters (letters, numbers, and underscores only)"
            return false
        }
        
        // Validate email format
        if !email.contains("@") || !email.contains(".") {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        // Validate password length
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long"
            return false
        }
        
        // Check password match
        if password != confirmPassword {
            errorMessage = "Passwords don't match. Please check and try again."
            return false
        }
        
        return true
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    private func getFriendlyErrorMessage(from error: Error) -> String {
        // Check for custom AuthError first
        if let authError = error as? AuthError {
            return authError.errorDescription ?? "An error occurred"
        }
        
        // Parse Firebase error codes
        let errorCode = (error as NSError).code
        let errorDomain = (error as NSError).domain
        
        // Firebase Auth errors
        if errorDomain == "FIRAuthErrorDomain" {
            switch errorCode {
            case 17007: // Email already in use
                return "This email is already registered. Please sign in or use a different email."
            case 17008, 17009: // Invalid email or wrong password
                return "Invalid email or password. Please check your credentials and try again."
            case 17011: // User not found
                return "No account found with this email. Please check or create a new account."
            case 17026: // Weak password
                return "Please choose a stronger password (at least 6 characters)."
            case 17020: // Network error
                return "Network connection issue. Please check your internet and try again."
            case 17999: // Too many requests
                return "Too many attempts. Please wait a moment and try again."
            case 17010: // Password incorrect
                return "Incorrect password. Please try again or reset your password."
            case 17012: // Invalid user token
                return "Your session has expired. Please sign in again."
            case 17014: // Email already exists
                return "This email is already registered. Please sign in instead."
            default:
                break
            }
        }
        
        // Fallback to a generic friendly message
        let errorMessage = error.localizedDescription.lowercased()
        if errorMessage.contains("network") || errorMessage.contains("internet") {
            return "Connection issue. Please check your internet and try again."
        } else if errorMessage.contains("password") {
            return "Password issue. Please check your password and try again."
        } else if errorMessage.contains("email") {
            return "Email issue. Please check your email address and try again."
        }
        
        return "Something went wrong. Please try again."
    }
}

