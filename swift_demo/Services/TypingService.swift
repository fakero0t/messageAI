//
//  TypingService.swift
//  swift_demo
//
//  Service for real-time typing indicators using Firebase Realtime Database
//
//  Vue Analogy: This is like a Vue composable (useTypingIndicator) that:
//  - Uses Firebase Realtime Database (like onValue in Firebase JS SDK)
//  - Returns reactive refs that auto-update (like Combine publishers → Vue refs)
//  - Has debouncing (like lodash debounce or VueUse useDebounceFn)
//

import Foundation
import FirebaseDatabase
import FirebaseAuth
import Combine

class TypingService: ObservableObject {
    // Singleton pattern - like export const typingService in TypeScript
    static let shared = TypingService()
    
    // Firebase Realtime Database reference
    // In Vue: const db = getDatabase()
    private let database = Database.database().reference()
    
    // Store timers for debouncing and timeouts
    // In Vue: Map<string, NodeJS.Timeout>
    private var debounceTimers: [String: Timer] = [:]
    private var timeoutTasks: [String: Task<Void, Never>] = [:]
    
    // Track active listeners to avoid memory leaks
    // In Vue: Map<string, () => void> for cleanup functions
    private var activeListeners: [String: DatabaseHandle] = [:]
    
    // Published property for typing users by conversation
    // In Vue: const typingUsers = ref<Record<string, User[]>>({})
    @Published var typingUsers: [String: [User]] = [:]
    
    // Periodic cleanup timer to remove stale indicators
    private var cleanupTimer: Timer?
    
    private init() {
        // Start periodic cleanup task (runs every 2 seconds)
        // In Vue: setInterval(() => cleanupStaleIndicators(), 2000)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.cleanupStaleIndicators()
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start broadcasting typing status
    /// In Vue: like calling a debounced function that updates Firestore
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: Current user's ID
    ///   - displayName: Current user's display name
    func startTyping(conversationId: String, userId: String, displayName: String) {
        let key = "\(conversationId)_\(userId)"
        
        // Cancel existing debounce timer
        // In Vue: clearTimeout(timers[key])
        debounceTimers[key]?.invalidate()
        
        // Debounce: Only broadcast after 150ms of continued typing (snappy response!)
        // In Vue: const debouncedFn = useDebounceFn(broadcast, 150)
        debounceTimers[key] = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.broadcastTypingStatus(
                conversationId: conversationId,
                userId: userId,
                displayName: displayName
            )
        }
    }
    
    /// Stop broadcasting typing status
    /// In Vue: like calling remove(ref(db, path))
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: Current user's ID
    func stopTyping(conversationId: String, userId: String) {
        let key = "\(conversationId)_\(userId)"
        
        // Cancel debounce timer
        debounceTimers[key]?.invalidate()
        debounceTimers[key] = nil
        
        // Cancel timeout task
        timeoutTasks[key]?.cancel()
        timeoutTasks[key] = nil
        
        // Remove from database
        removeTypingStatus(conversationId: conversationId, userId: userId)
    }
    
    /// Observe typing users in a conversation
    /// Updates the @Published typingUsers property
    ///
    /// In Vue: This is like using onValue(dbRef, (snapshot) => { typingUsers.value[conversationId] = [...] })
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - currentUserId: Current user ID (to exclude from results)
    func observeTypingUsers(conversationId: String, currentUserId: String) {
        // Don't create duplicate listeners
        let listenerKey = "observe_\(conversationId)"
        guard activeListeners[listenerKey] == nil else {
            print("⚠️ [Observer] Already observing conversation: \(conversationId)")
            return
        }
        
        // Database path: /typing/{conversationId}
        let typingRef = database.child("typing").child(conversationId)
        let path = "typing/\(conversationId)"
        print("👂 [Observer] Starting to observe path: \(path)")
        print("👂 [Observer] Current user ID (will be excluded): \(currentUserId)")
        
        // Listen for value changes
        // In Vue: onValue(ref(db, `typing/${conversationId}`), (snapshot) => { ... })
        let handle = typingRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            print("📨 [Observer] RECEIVED DATA from Firebase!")
            print("📨 [Observer] Snapshot exists: \(snapshot.exists())")
            print("📨 [Observer] Snapshot value: \(String(describing: snapshot.value))")
            print("📨 [Observer] Children count: \(snapshot.childrenCount)")
            
            var users: [User] = []
            let now = Date()
            
            // Iterate through all children (user IDs)
            // In Vue: Object.entries(snapshot.val() || {})
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else {
                    print("⚠️ [Observer] Failed to cast child to DataSnapshot")
                    continue
                }
                
                print("🔍 [Observer] Processing child key: \(childSnapshot.key)")
                
                guard let data = childSnapshot.value as? [String: Any] else {
                    print("⚠️ [Observer] No data for key: \(childSnapshot.key)")
                    continue
                }
                
                print("🔍 [Observer] Data: \(data)")
                
                guard let displayName = data["displayName"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval else {
                    print("⚠️ [Observer] Missing displayName or timestamp")
                    continue
                }
                
                // Check if this is the current user (should be excluded)
                if childSnapshot.key == currentUserId {
                    print("🚫 [Observer] Skipping current user: \(displayName)")
                    continue
                }
                
                // Check if timestamp is recent (within 3 seconds for faster clearing)
                let typingDate = Date(timeIntervalSince1970: timestamp / 1000.0)
                let timeDiff = now.timeIntervalSince(typingDate)
                
                print("⏱️ [Observer] Time diff for \(displayName): \(timeDiff)s")
                
                // Only show typing if updated within last 3 seconds (prevents stuck indicators)
                if timeDiff < 3.0 {
                    let user = User(id: childSnapshot.key, email: "", displayName: displayName, online: true)
                    users.append(user)
                    print("✅ [Observer] Added user: \(displayName)")
                } else {
                    print("❌ [Observer] Timestamp too old for: \(displayName) (stale indicator)")
                }
            }
            
            print("📝 [Observer] Total users typing: \(users.count)")
            print("📝 [Observer] Users: \(users.map { $0.displayName })")
            
            // Update published property on main thread
            // In Vue: typingUsers.value[conversationId] = users
            DispatchQueue.main.async {
                self.typingUsers[conversationId] = users
                print("🔄 [Observer] Updated @Published property for conversation: \(conversationId)")
            }
        }
        
        // Store handle for cleanup
        activeListeners[listenerKey] = handle
        print("✅ [Observer] Listener registered successfully")
    }
    
    /// Stop observing typing users for a conversation
    /// In Vue: like calling unsubscribe() or cleanup function
    func stopObservingTypingUsers(conversationId: String) {
        let listenerKey = "observe_\(conversationId)"
        
        if let handle = activeListeners[listenerKey] {
            database.child("typing").child(conversationId).removeObserver(withHandle: handle)
            activeListeners.removeValue(forKey: listenerKey)
            
            // Clear typing users for this conversation
            DispatchQueue.main.async { [weak self] in
                self?.typingUsers.removeValue(forKey: conversationId)
            }
        }
    }
    
    /// Clean up typing status when leaving conversation
    /// In Vue: like onUnmounted() or cleanup function in composable
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: Current user ID
    func cleanup(conversationId: String, userId: String) {
        stopTyping(conversationId: conversationId, userId: userId)
        stopObservingTypingUsers(conversationId: conversationId)
    }
    
    // MARK: - Private Methods
    
    /// Broadcast typing status to Firebase
    /// In Vue: like set(ref(db, path), { displayName, timestamp })
    private func broadcastTypingStatus(
        conversationId: String,
        userId: String,
        displayName: String
    ) {
        // DEBUG: Check authentication status
        if let currentUser = Auth.auth().currentUser {
            print("🔐 [Auth] Current Firebase user: \(currentUser.uid)")
            print("🔐 [Auth] Trying to write as userId: \(userId)")
            print("🔐 [Auth] Match: \(currentUser.uid == userId)")
        } else {
            print("❌ [Auth] NO FIREBASE USER - NOT AUTHENTICATED!")
            return
        }
        
        let typingRef = database.child("typing").child(conversationId).child(userId)
        let path = "typing/\(conversationId)/\(userId)"
        print("📍 [Database] Writing to path: \(path)")
        
        // Data to store
        // In Vue: { displayName: string, timestamp: ServerValue.TIMESTAMP }
        let data: [String: Any] = [
            "timestamp": ServerValue.timestamp(),
            "displayName": displayName
        ]
        
        // Write to database
        // In Vue: await set(ref(db, path), data)
        typingRef.setValue(data) { error, _ in
            if let error = error {
                print("❌ Failed to set typing status: \(error.localizedDescription)")
            } else {
                print("✅ Typing status set for \(displayName)")
            }
        }
        
        // Set up onDisconnect to auto-remove when user disconnects
        // In Vue: onDisconnect(ref(db, path)).remove()
        // This is AMAZING - Firebase automatically removes it if connection drops!
        typingRef.onDisconnectRemoveValue()
        
        // Set up 3-second timeout to auto-remove if user stops typing (prevents stuck indicators)
        let key = "\(conversationId)_\(userId)"
        timeoutTasks[key]?.cancel() // Cancel existing timeout
        
        // In Vue: setTimeout(() => remove(ref), 3000)
        timeoutTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Only remove if task wasn't cancelled (user continued typing)
            if !Task.isCancelled {
                self?.removeTypingStatus(conversationId: conversationId, userId: userId)
                print("⏱️ Typing status auto-removed after 3s timeout for \(displayName)")
            }
        }
    }
    
    /// Remove typing status from database
    /// In Vue: await remove(ref(db, path))
    private func removeTypingStatus(conversationId: String, userId: String) {
        let typingRef = database.child("typing").child(conversationId).child(userId)
        
        typingRef.removeValue { error, _ in
            if let error = error {
                print("❌ Failed to remove typing status: \(error.localizedDescription)")
            }
        }
        
        // Clean up timeout task
        let key = "\(conversationId)_\(userId)"
        timeoutTasks[key]?.cancel()
        timeoutTasks.removeValue(forKey: key)
    }
    
    // MARK: - Utility Methods
    
    /// Format typing text based on number of users in a conversation
    /// In Vue: computed(() => formatTypingText(typingUsers.value[conversationId]))
    ///
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Formatted string like "Alice is typing..."
    func formatTypingText(for conversationId: String) -> String? {
        guard let users = typingUsers[conversationId], !users.isEmpty else { return nil }
        
        let names = users.map { $0.displayName }
        
        switch names.count {
        case 1:
            // "Alice is typing..."
            return "\(names[0]) is typing..."
        case 2:
            // "Alice and Bob are typing..."
            return "\(names[0]) and \(names[1]) are typing..."
        default:
            // "Alice and 2 others are typing..."
            return "\(names[0]) and \(names.count - 1) others are typing..."
        }
    }
    
    // MARK: - Private Cleanup
    
    /// Periodically removes stale typing indicators from Firebase
    /// This is a safety net to ensure indicators don't get stuck
    /// In Vue: const cleanupStaleIndicators = () => { ... }
    private func cleanupStaleIndicators() {
        // Iterate through all active conversations we're observing
        for (listenerKey, _) in activeListeners {
            // Extract conversationId from listener key (format: "observe_<conversationId>")
            guard listenerKey.hasPrefix("observe_"),
                  let conversationId = listenerKey.components(separatedBy: "observe_").last else {
                continue
            }
            
            // Check this conversation's typing indicators in Firebase
            let typingRef = database.child("typing").child(conversationId)
            
            typingRef.observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }
                let now = Date()
                
                // Check each user's typing status
                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot,
                          let data = childSnapshot.value as? [String: Any],
                          let timestamp = data["timestamp"] as? TimeInterval else {
                        continue
                    }
                    
                    // Check if timestamp is stale (older than 4 seconds)
                    let typingDate = Date(timeIntervalSince1970: timestamp / 1000.0)
                    let timeDiff = now.timeIntervalSince(typingDate)
                    
                    if timeDiff > 4.0 {
                        // Remove stale indicator from Firebase
                        let userId = childSnapshot.key
                        self.database.child("typing").child(conversationId).child(userId).removeValue { error, _ in
                            if let error = error {
                                print("🧹 [Cleanup] Failed to remove stale indicator: \(error.localizedDescription)")
                            } else {
                                print("🧹 [Cleanup] Removed stale typing indicator for user: \(userId)")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Vue/TypeScript Comparison

/*
 This Swift service is equivalent to this Vue composable:
 
 ```typescript
 // composables/useTypingIndicator.ts
 import { ref, onUnmounted } from 'vue'
 import { getDatabase, ref as dbRef, set, remove, onValue, onDisconnect, serverTimestamp } from 'firebase/database'
 
 export function useTypingIndicator(conversationId: string, currentUserId: string) {
   const db = getDatabase()
   const typingUsers = ref<string[]>([])
   
   let debounceTimer: NodeJS.Timeout | null = null
   let timeoutTimer: NodeJS.Timeout | null = null
   
   const startTyping = (displayName: string) => {
     if (debounceTimer) clearTimeout(debounceTimer)
     
     // Debounce: wait 500ms
     debounceTimer = setTimeout(async () => {
       const typingRef = dbRef(db, `typing/${conversationId}/${currentUserId}`)
       
       // Write to database
       await set(typingRef, {
         displayName,
         timestamp: serverTimestamp()
       })
       
       // Auto-remove on disconnect
       onDisconnect(typingRef).remove()
       
       // Set 5s timeout
       if (timeoutTimer) clearTimeout(timeoutTimer)
       timeoutTimer = setTimeout(() => {
         remove(typingRef)
       }, 5000)
     }, 500)
   }
   
   const stopTyping = async () => {
     if (debounceTimer) clearTimeout(debounceTimer)
     if (timeoutTimer) clearTimeout(timeoutTimer)
     
     const typingRef = dbRef(db, `typing/${conversationId}/${currentUserId}`)
     await remove(typingRef)
   }
   
   // Listen to typing users
   const conversationRef = dbRef(db, `typing/${conversationId}`)
   const unsubscribe = onValue(conversationRef, (snapshot) => {
     const users: string[] = []
     const data = snapshot.val() || {}
     
     Object.entries(data).forEach(([userId, info]: [string, any]) => {
       if (userId !== currentUserId) {
         users.push(info.displayName)
       }
     })
     
     typingUsers.value = users
   })
   
   onUnmounted(() => {
     stopTyping()
     unsubscribe()
   })
   
   return {
     typingUsers,
     startTyping,
     stopTyping
   }
 }
 ```
 
 Key Concepts:
 - Combine Publishers = Vue refs (reactive state)
 - Task/Timer = setTimeout/setInterval
 - @MainActor = automatic, not needed in Vue (single-threaded)
 - Singleton (.shared) = exported const
 - onDisconnect = Firebase feature that works same in both platforms
 */

