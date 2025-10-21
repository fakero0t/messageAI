# swift_demo Test Suite

Comprehensive unit tests covering the messaging app MVP features from PRs 1-18.

## Test Coverage by PR

### PR-2: Authentication System
**File:** `ValidationTests.swift` (5 tests)
- Email format validation
- Password strength requirements
- Display name validation
- User ID format checks

### PR-5: User Profile & Online Status
**File:** `UserModelTests.swift` (5 tests)
- User model initialization
- Online/offline status tracking
- Mock user helpers
- LastSeen timestamp handling

### PR-9: Optimistic UI & Message Status
**File:** `MessageStatusTests.swift` (6 tests)
- Status enum values and transitions
- Display text formatting
- Icon name mappings
- Codable encoding/decoding
- Status progression logic

### PR-10: Offline Message Queueing
**File:** `MessageQueueServiceTests.swift` (6 tests)
- Singleton pattern verification
- Queue count management
- Processing state tracking
- Conversation ID parsing
- Max retry threshold enforcement
- Queued message structure validation

### PR-11: Network Monitoring & Resilience
**Files:** `NetworkMonitorTests.swift` (6 tests), `RetryPolicyTests.swift` (6 tests)

**NetworkMonitorTests:**
- Singleton instance verification
- Connection state initialization
- Connection quality descriptions
- Network status change notifications
- Monitor start/stop functionality

**RetryPolicyTests:**
- Policy configuration (default, aggressive, conservative)
- Exponential backoff calculation
- Max delay cap enforcement
- Retryable network error detection
- Non-retryable Firestore error handling
- Max retries enforcement

### PR-12: Crash Recovery & Message Retry
**Files:** `CrashRecoveryServiceTests.swift` (5 tests), `MessageDeduplicationTests.swift` (5 tests)

**CrashRecoveryServiceTests:**
- Service singleton pattern
- Stale message detection
- Recipient ID extraction
- Recovery process without crashes
- Status-based recovery handling

**MessageDeduplicationTests:**
- Duplicate message ID detection
- Message existence checking
- Duplicate removal algorithms
- UUID uniqueness verification
- Queue duplication checks

### PR-13: Read Receipts
**File:** `ReadReceiptServiceTests.swift` (6 tests)
- Singleton pattern verification
- Unread message filtering
- One-on-one chat read receipt logic
- Group chat read receipt logic
- Empty readBy array handling
- Multiple users read receipt tracking

### PR-14: Timestamps & Formatting
**File:** `DateFormattingTests.swift` (7 tests)
- "Just now" formatting for recent messages
- Minutes ago formatting
- Hours ago formatting
- Yesterday formatting
- Conversation list timestamp condensing
- Same day comparison
- Date separator text generation

### PR-15: Conversation List with Unread Badges
**File:** `ConversationModelTests.swift` (6 tests)
- One-on-one conversation ID format
- Conversation ID consistency
- Participant extraction from conversation ID
- Unread count logic
- Last message preview truncation
- Group vs one-on-one participant count

### Integration Tests
**File:** `IntegrationTests.swift` (5 tests)
- Complete message sending workflow (PR-7, PR-9)
- Offline to online transition (PR-10, PR-11)
- Read receipt workflow (PR-13)
- Message retry workflow (PR-12)
- Complete message lifecycle (pending → sent → delivered → read)

### Mock Services
**File:** `MockServices.swift`
- MockLocalStorageService for testing storage operations
- Mock User factory methods
- Mock MessageEntity factory methods
- Mock QueuedMessageEntity factory methods

## Total Test Count

- **63 unit tests** covering core functionality
- **5 integration tests** covering workflows
- **Total: 68 tests**

## Running Tests

### In Xcode
1. Open `swift_demo.xcodeproj`
2. Press `Cmd + U` to run all tests
3. Or use `Cmd + 6` to open Test Navigator and run individual test suites

### Command Line
```bash
xcodebuild test -scheme swift_demo -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Continuous Integration
Tests can be integrated into CI/CD pipelines using:
```bash
# Install dependencies
pod install  # or swift package resolve

# Run tests
xcodebuild test \
  -workspace swift_demo.xcworkspace \
  -scheme swift_demo \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath TestResults.xcresult
```

## Test Philosophy

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test workflows across multiple components
3. **Mock Services**: Use mocks to avoid Firebase dependencies in tests
4. **Fast Execution**: All tests should run in < 5 seconds
5. **Deterministic**: Tests should always produce the same result

## Adding New Tests

When adding new features:

1. Create a new test file: `<FeatureName>Tests.swift`
2. Import the test framework and app module:
   ```swift
   import XCTest
   @testable import swift_demo
   ```
3. Add approximately 5 tests per feature/PR
4. Update this README with test coverage

## Test Naming Convention

- Test files: `<ComponentName>Tests.swift`
- Test classes: `final class <ComponentName>Tests: XCTestCase`
- Test methods: `func test<DescriptiveActionOrScenario>()`

Example:
```swift
func testEmailValidationWithValidFormat() { }
func testRetryPolicyExponentialBackoff() { }
```

## Best Practices

1. **Arrange-Act-Assert**: Structure tests clearly
2. **One assertion per test**: Focus on single responsibility
3. **Descriptive names**: Test names should explain what they verify
4. **No external dependencies**: Use mocks for Firebase, network, etc.
5. **Fast tests**: Each test should complete in < 100ms
6. **Isolated tests**: Tests shouldn't depend on each other
7. **Clean state**: Use `setUp()` and `tearDown()` when needed

## Coverage Goals

- **Critical paths**: 100% coverage (authentication, message sending, queuing)
- **Business logic**: 80%+ coverage
- **UI components**: Focus on logic, not rendering
- **Overall target**: 70%+ code coverage

## Troubleshooting

### Tests not appearing in Xcode
- Clean build folder: `Cmd + Shift + K`
- Rebuild: `Cmd + B`
- Restart Xcode

### Import errors
- Ensure test target includes necessary files
- Check `@testable import swift_demo` is present
- Verify scheme includes test target

### Async test failures
- Use `XCTestExpectation` for async operations
- Use `@MainActor` for tests that need main thread
- Increase timeout if needed: `wait(for: [expectation], timeout: 10)`

## Firebase Testing Notes

These tests use mocks to avoid Firebase dependencies. For integration tests that require Firebase:
1. Use Firebase Test Lab or local emulator
2. Set up test Firebase project
3. Use `XCUITest` for end-to-end testing

## Future Enhancements

- [ ] UI tests for user interactions (XCUITest)
- [ ] Performance tests for message loading
- [ ] Snapshot tests for UI components
- [ ] Firebase emulator integration tests
- [ ] Load testing for message queues
- [ ] Memory leak detection tests

---

*Last Updated: October 21, 2025*

