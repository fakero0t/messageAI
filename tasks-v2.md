# PR-2: Authentication System

## Overview
Implement Firebase Authentication with email/password login and signup. Create authentication views and manage user session state.

## Dependencies
- PR-1: Project Setup & Firebase Configuration

## Tasks

### 1. Create Authentication Service
- [ ] Create `Services/` folder in swift_demo
- [ ] Create `AuthenticationService.swift`
  - [ ] Implement singleton pattern
  - [ ] Add email/password signup method
  - [ ] Add email/password login method
  - [ ] Add logout method
  - [ ] Add current user observable property
  - [ ] Add auth state listener

### 2. Create User Model
- [ ] Create `Models/` folder in swift_demo
- [ ] Create `User.swift` model
  - [ ] Properties: id, email, displayName
  - [ ] Initializer from Firebase User
  - [ ] Codable conformance

### 3. Create Authentication Views
- [ ] Create `Views/Auth/` folder
- [ ] Create `LoginView.swift`
  - [ ] Email text field
  - [ ] Password secure field
  - [ ] Login button
  - [ ] Link to signup view
  - [ ] Error message display
  - [ ] Loading state
- [ ] Create `SignupView.swift`
  - [ ] Email text field
  - [ ] Display name text field
  - [ ] Password secure field
  - [ ] Confirm password field
  - [ ] Signup button
  - [ ] Link to login view
  - [ ] Error message display
  - [ ] Loading state

### 4. Create Authentication ViewModel
- [ ] Create `ViewModels/` folder
- [ ] Create `AuthViewModel.swift`
  - [ ] ObservableObject conformance
  - [ ] @Published properties for form fields
  - [ ] @Published error message
  - [ ] @Published loading state
  - [ ] @Published authentication state
  - [ ] Login method
  - [ ] Signup method
  - [ ] Logout method
  - [ ] Form validation

### 5. Update App Entry Point
- [ ] Modify `swift_demoApp.swift`
  - [ ] Create AuthViewModel as @StateObject
  - [ ] Show LoginView if not authenticated
  - [ ] Show main app if authenticated
  - [ ] Pass authentication state through environment

### 6. Create Firestore User Document
- [ ] Update AuthenticationService to create user document in Firestore
  - [ ] On signup: create document in `users/{userId}`
  - [ ] Store: userId, email, displayName, online: false
  - [ ] Handle errors gracefully

## Files to Create/Modify

### New Files
- `swift_demo/Services/AuthenticationService.swift`
- `swift_demo/Models/User.swift`
- `swift_demo/Views/Auth/LoginView.swift`
- `swift_demo/Views/Auth/SignupView.swift`
- `swift_demo/ViewModels/AuthViewModel.swift`

### Modified Files
- `swift_demo/swift_demoApp.swift` - Add auth state management
- `swift_demo/ContentView.swift` - Will be main app view (update later)

## Code Structure Examples

### AuthenticationService.swift
```swift
import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: User?
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        setupAuthStateListener()
    }
    
    func setupAuthStateListener() { }
    func signUp(email: String, password: String, displayName: String) async throws { }
    func signIn(email: String, password: String) async throws { }
    func signOut() throws { }
    func createUserDocument(userId: String, email: String, displayName: String) async throws { }
}
```

### User.swift
```swift
import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    var online: Bool = false
}
```

### AuthViewModel.swift
```swift
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
    
    func login() async { }
    func signup() async { }
    func logout() { }
    func validateSignupForm() -> Bool { }
}
```

## Acceptance Criteria
- [ ] Users can sign up with email/password
- [ ] Users can log in with existing credentials
- [ ] Users can log out
- [ ] User document created in Firestore on signup
- [ ] Authentication state persists across app restarts
- [ ] Error messages displayed for invalid credentials
- [ ] Form validation works (email format, password length, matching passwords)
- [ ] Loading states shown during auth operations
- [ ] App shows login view when not authenticated
- [ ] App shows main view when authenticated

## Testing
1. Run app in Simulator
2. Sign up with new email/password
3. Verify user appears in Firebase Console → Authentication
4. Verify user document appears in Firestore → users collection
5. Log out
6. Log in with same credentials
7. Force quit app and reopen - should remain logged in
8. Test error cases:
   - Invalid email format
   - Password too short
   - Wrong password
   - Non-matching passwords (signup)

## Notes
- Email/password auth is simplest for MVP testing
- User ID from Firebase Auth is used as document ID in Firestore
- Password minimum length: 6 characters (Firebase default)
- Display name required for user identification in chats
- Auth state persists automatically via Firebase

## Next PR
PR-3: Basic SwiftUI Structure & Navigation (depends on this PR)

