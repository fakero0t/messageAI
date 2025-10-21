//
//  TypingServiceTestView.swift
//  swift_demo
//
//  Test view for TypingService
//  In Vue: This is like a test component <TypingTest.vue>
//

import SwiftUI
import Combine

struct TypingServiceTestView: View {
    // In Vue: const typingService = inject('typingService')
    private let typingService = TypingService.shared
    
    // Reactive state
    // In Vue: const typingUsers = ref<string[]>([])
    @State private var typingUsers: [String] = []
    @State private var typingText: String?
    
    // Store the Combine subscription
    // In Vue: onUnmounted() cleanup handled automatically
    @State private var cancellables = Set<AnyCancellable>()
    
    // Test data
    private let testConversationId = "test-conversation-123"
    private let testUserId = "test-user-\(UUID().uuidString.prefix(6))"
    private let testDisplayName = "Test User"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Typing Service Test")
                .font(.headline)
            
            Divider()
            
            // Show who's typing
            VStack(alignment: .leading, spacing: 8) {
                Text("Currently Typing:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let typingText = typingText {
                    Text(typingText)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Text("No one is typing")
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Text("Raw users: \(typingUsers.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Control buttons
            VStack(spacing: 12) {
                Button("Start Typing") {
                    print("🖊️ Starting typing...")
                    typingService.startTyping(
                        conversationId: testConversationId,
                        userId: testUserId,
                        displayName: testDisplayName
                    )
                }
                .buttonStyle(.borderedProminent)
                
                Button("Stop Typing") {
                    print("🛑 Stopping typing...")
                    typingService.stopTyping(
                        conversationId: testConversationId,
                        userId: testUserId
                    )
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("How to Test:")
                    .font(.subheadline)
                    .bold()
                
                Text("1. Open this view on 2 devices/simulators")
                Text("2. Tap 'Start Typing' on device 1")
                Text("3. See 'Test User is typing...' on device 2")
                Text("4. Wait 5 seconds → auto-removes")
                Text("5. Or tap 'Stop Typing' → removes immediately")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .onAppear {
            setupTypingObserver()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Setup Observer
    
    /// Set up observer for typing users
    /// In Vue: onMounted(() => { ... })
    private func setupTypingObserver() {
        print("👂 Setting up typing observer for conversation: \(testConversationId)")
        
        // Start observing typing users (they'll be published to typingService.typingUsers)
        // In Vue: const { typingUsers } = useTypingIndicator(conversationId)
        typingService.observeTypingUsers(
            conversationId: testConversationId,
            currentUserId: testUserId
        )
        
        // Watch for changes in the published typingUsers property
        // In Vue: watch(() => typingService.typingUsers[conversationId], (users) => { ... })
        typingService.$typingUsers
            .map { typingUsersDict in
                typingUsersDict[testConversationId]?.map { $0.displayName } ?? []
            }
            .sink { users in
                // Update state when typing users change
                // Note: No [weak self] needed - structs don't create retain cycles
                self.typingUsers = users
                self.typingText = self.typingService.formatTypingText(for: testConversationId)
                
                print("📝 Typing users updated: \(users)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup
    
    /// Clean up when view disappears
    /// In Vue: onUnmounted(() => { ... })
    private func cleanup() {
        print("🧹 Cleaning up typing service...")
        typingService.cleanup(
            conversationId: testConversationId,
            userId: testUserId
        )
        cancellables.removeAll()
    }
}

// MARK: - Preview

#Preview {
    TypingServiceTestView()
}

// MARK: - Vue Component Equivalent

/*
 This Swift view is equivalent to this Vue component:
 
 ```vue
 <template>
   <div class="typing-test">
     <h2>Typing Service Test</h2>
     
     <div class="typing-status">
       <h3>Currently Typing:</h3>
       <p v-if="typingText" class="typing-indicator">{{ typingText }}</p>
       <p v-else class="no-typing">No one is typing</p>
       <small>Raw users: {{ typingUsers.join(', ') }}</small>
     </div>
     
     <div class="controls">
       <button @click="startTyping">Start Typing</button>
       <button @click="stopTyping">Stop Typing</button>
     </div>
     
     <div class="instructions">
       <h4>How to Test:</h4>
       <ol>
         <li>Open this view on 2 devices/browsers</li>
         <li>Click 'Start Typing' on device 1</li>
         <li>See 'Test User is typing...' on device 2</li>
         <li>Wait 5 seconds → auto-removes</li>
         <li>Or click 'Stop Typing' → removes immediately</li>
       </ol>
     </div>
   </div>
 </template>
 
 <script setup lang="ts">
 import { ref, onMounted, onUnmounted } from 'vue'
 import { getDatabase, ref as dbRef, onValue } from 'firebase/database'
 
 const testConversationId = 'test-conversation-123'
 const testUserId = `test-user-${Math.random().toString(36).substr(2, 6)}`
 const testDisplayName = 'Test User'
 
 const typingUsers = ref<string[]>([])
 const typingText = computed(() => {
   if (typingUsers.value.length === 0) return null
   if (typingUsers.value.length === 1) return `${typingUsers.value[0]} is typing...`
   if (typingUsers.value.length === 2) return `${typingUsers.value[0]} and ${typingUsers.value[1]} are typing...`
   return `${typingUsers.value[0]} and ${typingUsers.value.length - 1} others are typing...`
 })
 
 let unsubscribe: (() => void) | null = null
 
 onMounted(() => {
   const db = getDatabase()
   const conversationRef = dbRef(db, `typing/${testConversationId}`)
   
   unsubscribe = onValue(conversationRef, (snapshot) => {
     const users: string[] = []
     const data = snapshot.val() || {}
     
     Object.entries(data).forEach(([userId, info]: [string, any]) => {
       if (userId !== testUserId) {
         users.push(info.displayName)
       }
     })
     
     typingUsers.value = users
   })
 })
 
 onUnmounted(() => {
   if (unsubscribe) unsubscribe()
   // cleanup typing status
 })
 
 const startTyping = () => {
   // Call typing service
 }
 
 const stopTyping = () => {
   // Call typing service
 }
 </script>
 ```
 
 Key Concepts:
 - @State = ref()
 - .sink { } = watchEffect(() => {})
 - .onAppear = onMounted()
 - .onDisappear = onUnmounted()
 - Combine cancellables = unsubscribe functions in Vue
 */

