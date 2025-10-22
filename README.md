# MessageAI

A modern real-time messaging app built with SwiftUI and Firebase.

## ✨ Features

### Core Messaging
- ✅ One-on-one chat
- ✅ Group chat (3+ participants)
- ✅ Real-time message delivery (<200ms)
- ✅ Offline message queueing
- ✅ Message persistence (SwiftData)
- ✅ Optimistic UI updates
- ✅ Crash recovery
- ✅ Message retry on failure

### Rich Media **[NEW]**
- ✅ Image messages (send/receive)
- ✅ Profile pictures
- ✅ Image compression (~1MB)
- ✅ Progressive image loading
- ✅ Full-screen image viewer with zoom & pan
- ✅ Camera and photo library integration

### Real-Time Features
- ✅ Online/offline presence indicators
- ✅ Read receipts
- ✅ Typing indicators **[NEW]**
  - Shows who is typing in real-time
  - Smart formatting for multiple users
  - Auto-cleanup after 3 seconds
- ✅ Message delivery states (sending, sent, delivered, read)

### UI/UX
- ✅ Avatar system with initials fallback **[NEW]**
  - Profile pictures throughout the app
  - Colored initials when no picture set
  - Consistent per-user colors
- ✅ Modern SwiftUI interface
- ✅ Smooth animations and transitions
- ✅ Dark mode support
- ✅ Network status indicators
- ✅ In-app notification banners

### Infrastructure
- ✅ Firebase Authentication (Email/Password)
- ✅ Firestore (messages/conversations)
- ✅ Realtime Database (typing indicators) **[NEW]**
- ✅ Firebase Storage (images & profile pictures) **[NEW]**
- ✅ Network resilience & auto-reconnect
- ✅ Comprehensive error handling

## 🚀 Getting Started

### Prerequisites
- **Xcode 15+**
- **iOS 17+**
- **Firebase project** (see setup guide below)

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd swift_demo
   ```

2. **Install dependencies:**
   - Dependencies are managed via Swift Package Manager
   - Xcode will automatically resolve packages on first build

3. **Configure Firebase:**
   - See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for detailed instructions
   - Download `GoogleService-Info.plist` from Firebase Console
   - Add it to the Xcode project root

4. **Build and run:**
   ```bash
   open swift_demo.xcodeproj
   ```
   - Select target device/simulator
   - Press `Cmd+R` to build and run

## 📱 Usage

### Creating an Account
1. Launch the app
2. Tap **Sign Up**
3. Enter email and password
4. Set your display name
5. Start chatting!

### Sending Messages
- **Text:** Type in the input field and tap send
- **Images:** Tap the photo icon → Choose camera or library → Select image
- **Profile Picture:** Go to Settings tab → Tap "Change Photo"

### Starting a Conversation
1. Tap **+** in Conversations tab
2. Select a user from the list
3. Start chatting!

### Group Chats
1. Tap **+** in Conversations
2. Select "Create Group"
3. Choose participants (3+ users)
4. Set group name
5. Start group chat!

## 🏗️ Architecture

### Tech Stack
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Local persistence layer
- **Combine** - Reactive programming
- **Firebase** - Backend services
  - Authentication
  - Firestore (message storage)
  - Realtime Database (ephemeral data)
  - Storage (image hosting)

### Project Structure
```
swift_demo/
├── Models/              # Data models
│   ├── User.swift
│   ├── MessageStatus.swift
│   └── SwiftData/       # Local persistence models
├── Services/            # Business logic & Firebase integration
│   ├── AuthenticationService.swift
│   ├── MessageService.swift
│   ├── TypingService.swift
│   ├── ImageUploadService.swift
│   ├── UserService.swift
│   └── ...
├── ViewModels/          # MVVM view models
│   ├── AuthViewModel.swift
│   ├── ChatViewModel.swift
│   └── ConversationListViewModel.swift
├── Views/               # SwiftUI views
│   ├── Auth/
│   ├── Chat/
│   ├── Conversations/
│   ├── Components/
│   └── ...
└── Utilities/           # Helper functions & extensions
    ├── ImageCompressor.swift
    ├── ImageFileManager.swift
    └── DateFormatting.swift
```

### Design Patterns
- **MVVM** (Model-View-ViewModel)
- **Singleton** (Shared services)
- **Observer** (Combine publishers)
- **Repository** (Service layer)

## 🧪 Testing

### Run Tests
```bash
# All tests
xcodebuild test -scheme swift_demo \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Specific test class
xcodebuild test -scheme swift_demo \
  -only-testing:swift_demoTests/TypingServiceTests

# Test script (includes build)
./run_tests.sh
```

### Test Coverage
- ✅ **TypingService** - 17 tests (debouncing, timeouts, formatting)
- ✅ **ImageUploadService** - 14 tests (upload, progress, cancellation)
- ✅ **ImageUtils** - 14 tests (compression, resizing, file management)
- ✅ **MessageQueue** - 8 tests (offline queueing, retry logic)
- ✅ **NetworkMonitor** - 6 tests (connectivity detection)
- ✅ **DateFormatting** - 5 tests (time formatting)

See [TEST_SUITE_SUMMARY.md](TEST_SUITE_SUMMARY.md) for details.

## 📚 Documentation

- **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** - Complete Firebase configuration guide
- **[FEATURES.md](FEATURES.md)** - Detailed feature documentation
- **[TEST_COVERAGE.md](TEST_COVERAGE.md)** - Testing overview
- **[tasks_v2_*.md](tasks_v2_1.md)** - Development task breakdown

## 🔒 Security

### Firebase Security Rules

#### Firestore
- Users can only read conversations they're a participant in
- Users can only write their own messages
- Message ownership validated server-side

#### Realtime Database
- Authenticated users can read typing indicators
- Users can only write their own typing status
- Auto-cleanup on disconnect

#### Storage
- Profile pictures: Max 5MB, users can only upload their own
- Message images: Max 10MB, all authenticated users can upload
- Only image files allowed
- Filename validation for profile pictures

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md#security-best-practices) for details.

## ⚡ Performance

### Optimizations
- **Image Compression:** ~90% size reduction before upload
- **Image Caching:** In-memory and disk cache for fast loading
- **Debouncing:** Typing indicators debounced to reduce network calls
- **Lazy Loading:** Messages loaded on-demand
- **Optimistic UI:** Instant message display before server confirmation

### Metrics
- **Message delivery:** <200ms on good network
- **Typing indicator latency:** <500ms
- **Image upload:** <10s for 1MB on WiFi
- **App launch:** <2s cold start
- **Memory:** <150MB typical usage

## 🐛 Known Issues & Limitations

1. **Images:** Max 10MB per image, one image per message
2. **Video:** Not supported yet
3. **Image Editing:** No built-in editing tools
4. **GIFs:** Static only (no animation)
5. **Voice Messages:** Not implemented
6. **Link Previews:** Not implemented
7. **Message Reactions:** Not implemented

See [GitHub Issues](link-to-issues) for tracking.

## 🛠️ Development

### Prerequisites for Development
- Xcode 15+
- CocoaPods or Swift Package Manager
- Firebase CLI (optional, for rules deployment)

### Setup Development Environment
```bash
# Clone repo
git clone <repo-url>
cd swift_demo

# Open in Xcode
open swift_demo.xcodeproj

# Configure Firebase (see FIREBASE_SETUP.md)

# Run tests
./run_tests.sh
```

### Code Style
- Swift style guide (SwiftLint configured)
- 4-space indentation
- Descriptive variable names
- Comments for complex logic

### Contributing
1. Fork the repository
2. Create a feature branch (`feature/amazing-feature`)
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📝 License

This project is for educational purposes.

## 🙏 Acknowledgments

- Firebase for backend infrastructure
- SwiftUI for modern UI development
- The Swift community for excellent tooling and resources

## 📧 Support

For questions or issues:
- Open a [GitHub Issue](link-to-issues)
- Check [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for common setup problems
- Review [FEATURES.md](FEATURES.md) for feature documentation

---

**Built with ❤️ using SwiftUI and Firebase**

