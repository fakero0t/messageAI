# PR-1: Project Setup & Firebase Configuration

## Overview
Set up the Firebase project, integrate the Firebase SDK into the Xcode project, and configure the necessary infrastructure for the messaging app.

## Dependencies
- None (First PR)

## Tasks

### 1. Firebase Project Setup
- [ ] Create new Firebase project at console.firebase.google.com
- [ ] Name project "Messaging MVP" or similar
- [ ] Add iOS app to Firebase project
  - [ ] Bundle ID: com.yourname.swift-demo (or existing bundle ID)
  - [ ] Download `GoogleService-Info.plist`
- [ ] Enable Firestore Database
  - [ ] Start in test mode for now
  - [ ] Create database in preferred region
- [ ] Enable Firebase Authentication
  - [ ] Enable Email/Password provider

### 2. Xcode Project Configuration
- [ ] Open Xcode project
- [ ] Add Firebase SDK via Swift Package Manager
  - [ ] Go to File > Add Package Dependencies
  - [ ] URL: `https://github.com/firebase/firebase-ios-sdk`
  - [ ] Select version 10.x or latest
  - [ ] Add packages:
    - [ ] FirebaseAuth
    - [ ] FirebaseFirestore
    - [ ] FirebaseMessaging (for push notifications)
- [ ] Add `GoogleService-Info.plist` to project
  - [ ] Place in `swift_demo/` folder (same level as `ContentView.swift`)
  - [ ] Ensure it's added to target

### 3. App Initialization
- [ ] Update `swift_demoApp.swift` to initialize Firebase
  - [ ] Import Firebase
  - [ ] Call `FirebaseApp.configure()` in app initializer
  - [ ] Add `@main` attribute if not present

### 4. Info.plist Configuration
- [ ] Open Info.plist
- [ ] Verify bundle identifier matches Firebase registration
- [ ] Add any required Firebase configurations

### 5. Test Firebase Connection
- [ ] Build and run app in Simulator
- [ ] Check Xcode console for Firebase initialization success
- [ ] Verify no Firebase configuration errors
- [ ] Check Firebase Console for app connection (Analytics)

## Files to Create/Modify

### New Files
- `GoogleService-Info.plist` (downloaded from Firebase)

### Modified Files
- `swift_demo/swift_demoApp.swift` - Add Firebase initialization
- `swift_demo.xcodeproj/project.pbxproj` - SPM dependencies (automatic)

## Code Examples

### swift_demoApp.swift
```swift
import SwiftUI
import FirebaseCore

@main
struct swift_demoApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Acceptance Criteria
- [ ] Firebase project created and configured
- [ ] Firebase SDK integrated via SPM
- [ ] GoogleService-Info.plist added to project
- [ ] App initializes Firebase successfully
- [ ] No build errors
- [ ] App runs in Simulator without Firebase errors
- [ ] Firebase Console shows app connected

## Testing
1. Run app in Simulator
2. Check Xcode console for: `[Firebase/Core] Configured`
3. Open Firebase Console → Project Overview → Check for active app
4. No red errors in console related to Firebase

## Notes
- Save Firebase project credentials securely
- Don't commit GoogleService-Info.plist to public repos (add to .gitignore if needed)
- Test mode Firestore rules will be changed to secure rules later
- iOS 17+ deployment target as specified

## Next PR
PR-2: Authentication System (depends on this PR)

