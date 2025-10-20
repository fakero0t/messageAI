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
    @Published var displayName = ""
    @Published var confirmPassword = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isAuthenticated = false
    
    private let authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        authService.$currentUser
            .map { $0 != nil }
            .assign(to: &$isAuthenticated)
        
        // Reset loading state when auth succeeds
        $isAuthenticated
            .filter { $0 == true }
            .sink { [weak self] _ in
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            // isLoading will be reset by the isAuthenticated listener
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func signup() async {
        guard validateSignupForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        do {
            try authService.signOut()
            // Clear form fields
            email = ""
            password = ""
            displayName = ""
            confirmPassword = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func validateSignupForm() -> Bool {
        if displayName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty {
            errorMessage = "Please fill in all fields"
            return false
        }
        
        if !email.contains("@") {
            errorMessage = "Please enter a valid email"
            return false
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
}

