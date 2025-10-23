# Definition Cache Management

Guide for clearing and managing definition caches in both Firestore and iOS.

---

## Overview

Definitions are cached in two places:
1. **Firestore** - Global cache shared across all users
2. **iOS (SwiftData)** - Local cache per device

---

## Firestore Cache (Server-Side)

### Quick Clear with Firebase CLI

```bash
cd /Users/ary/Desktop/swift_demo/functions

# Make script executable
chmod +x clearCache.sh

# Clear all cached definitions
./clearCache.sh --all

# Show cache statistics
./clearCache.sh --stats
```

### Manual Clear

```bash
# Delete entire collection
firebase firestore:delete definitionCache --recursive --yes

# View cached definitions
firebase firestore:get definitionCache --limit 10
```

### Using the Node.js Script (Advanced)

**Note:** Requires Firebase service account key

```bash
cd /Users/ary/Desktop/swift_demo/functions

# Download service account key from Firebase Console
# Place it as serviceAccountKey.json in functions/

# Clear all definitions
node clearDefinitionCache.js --all

# Clear specific word
node clearDefinitionCache.js --word=გამარჯობა

# List all cached definitions
node clearDefinitionCache.js --list

# Show statistics
node clearDefinitionCache.js --stats
```

---

## iOS Local Cache

### Option 1: Use DefinitionCacheManager in Code

Add this code anywhere in your app (e.g., in a debug menu or test):

```swift
// Clear all local definitions
Task { @MainActor in
    DefinitionCacheManager.shared.clearAllDefinitions()
}

// Clear specific word
Task { @MainActor in
    DefinitionCacheManager.shared.clearDefinition(for: "გამარჯობა")
}

// Get cache statistics
Task { @MainActor in
    let stats = DefinitionCacheManager.shared.getCacheStats()
    print("Cached words: \(stats.totalWords)")
    print("Total accesses: \(stats.totalAccessCount)")
    print("Average: \(stats.averageAccessCount)")
}

// List all cached definitions
Task { @MainActor in
    let definitions = DefinitionCacheManager.shared.listAllDefinitions()
    for def in definitions {
        print("\(def.wordKey): \(def.definition)")
    }
}

// Clear old definitions (older than 30 days)
Task { @MainActor in
    DefinitionCacheManager.shared.clearOldDefinitions(olderThanDays: 30)
}
```

### Option 2: Add Debug Menu (Recommended)

Create a hidden debug view accessible by triple-tapping the app title:

```swift
// Add to MainView or ProfileView
.onTapGesture(count: 3) {
    showDebugMenu = true
}
.sheet(isPresented: $showDebugMenu) {
    DefinitionCacheDebugView()
}
```

```swift
// Create new file: DefinitionCacheDebugView.swift
struct DefinitionCacheDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats: CacheStats?
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Cache Statistics") {
                    if let stats = stats {
                        Text("Cached Words: \(stats.totalWords)")
                        Text("Total Accesses: \(stats.totalAccessCount)")
                        Text("Avg Access: \(String(format: "%.1f", stats.averageAccessCount))")
                    } else {
                        Text("Loading...")
                    }
                }
                
                Section("Actions") {
                    Button("Clear All Definitions") {
                        showAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear Old Definitions (30+ days)") {
                        Task { @MainActor in
                            DefinitionCacheManager.shared.clearOldDefinitions(olderThanDays: 30)
                            loadStats()
                        }
                    }
                }
            }
            .navigationTitle("Definition Cache")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear Cache?", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    Task { @MainActor in
                        DefinitionCacheManager.shared.clearAllDefinitions()
                        loadStats()
                    }
                }
            }
        }
        .onAppear { loadStats() }
    }
    
    private func loadStats() {
        Task { @MainActor in
            stats = DefinitionCacheManager.shared.getCacheStats()
        }
    }
}
```

### Option 3: Delete App Data (Nuclear Option)

```bash
# Simulator
xcrun simctl uninstall booted com.yourcompany.swift-demo

# Device: Delete app from home screen
# This clears ALL local data including messages
```

---

## When to Clear Cache

### Firestore Cache
- ✅ After updating definition prompts (to get fresh definitions)
- ✅ If definitions are consistently incorrect
- ✅ During development/testing
- ❌ In production (users benefit from cached definitions)

### iOS Local Cache
- ✅ When testing new definition logic
- ✅ If cache is too large (>1000 entries)
- ✅ User reports wrong definition (clear that specific word)
- ❌ Generally not needed (cache evicts old entries automatically)

---

## Cache Behavior

### Firestore Cache
- **TTL**: No automatic expiration
- **Size**: Unlimited (but costs $)
- **Shared**: All users benefit from cached definitions
- **Updates**: Requires manual clearing to refresh

### iOS Local Cache
- **TTL**: Based on lastAccessedAt (LRU eviction)
- **Size**: Limited to 1000 most recent entries
- **Shared**: Per-device only
- **Updates**: Automatic eviction of old entries

---

## Monitoring Cache Health

### Check Firestore Cache Size

```bash
firebase firestore:get definitionCache --limit 1 | grep "wordKey" -c
```

### Check Cost Impact

```bash
# View Firestore usage in Firebase Console
# https://console.firebase.google.com/project/messageai-cbd8a/usage

# Definitions use:
# - 1 read per cache hit (cheap)
# - 1 write per new definition (cheap)
# - Storage: ~1KB per definition (cheap)
```

### Check iOS Cache in Xcode

Add this to your debug menu:

```swift
let stats = DefinitionCacheManager.shared.getCacheStats()
print("📊 Cache Stats:")
print("   Total words: \(stats.totalWords)")
print("   Total hits: \(stats.totalAccessCount)")
print("   Oldest: \(stats.oldestCacheDate?.formatted() ?? "N/A")")
print("   Newest: \(stats.newestCacheDate?.formatted() ?? "N/A")")
```

---

## Troubleshooting

### "Wrong definition showing"

1. Clear Firestore cache for that specific word
2. Clear iOS local cache
3. Test again - should fetch fresh definition

### "Cache not working"

Check logs for:
```
💾 [DefinitionService] Cache hit for word: XXX
```

If not appearing, check:
- SwiftData is properly initialized
- DefinitionCacheEntity registered in PersistenceController

### "Firebase script not working"

Make sure you're authenticated:
```bash
firebase login
firebase use messageai-cbd8a
```

---

## Quick Reference

```bash
# Firestore: Clear all
firebase firestore:delete definitionCache --recursive --yes

# iOS: Clear all (in app code)
DefinitionCacheManager.shared.clearAllDefinitions()

# Firestore: View cached words
firebase firestore:get definitionCache --limit 10

# iOS: View stats (in app code)
let stats = DefinitionCacheManager.shared.getCacheStats()
```

