//
//  RealtimeDatabaseTest.swift
//  swift_demo
//
//  Test file to verify Firebase Realtime Database connection
//  Think of this like a test component in Vue to verify Firebase works
//

import SwiftUI
import FirebaseDatabase

struct RealtimeDatabaseTestView: View {
    @State private var testResult = "Not tested yet"
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase Realtime Database Test")
                .font(.headline)
            
            Text(testResult)
                .foregroundColor(testResult.contains("✅") ? .green : testResult.contains("❌") ? .red : .primary)
                .multilineTextAlignment(.center)
                .padding()
            
            if isLoading {
                ProgressView()
            }
            
            Button("Test Write & Read") {
                testRealtimeDB()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
        .padding()
    }
    
    private func testRealtimeDB() {
        isLoading = true
        testResult = "Testing..."
        
        // Get a reference to the database
        // In Vue/TypeScript: const db = getDatabase()
        let ref = Database.database().reference()
        
        // Generate a test path
        let testPath = "test/\(UUID().uuidString)"
        let testValue = "Hello Firebase! \(Date())"
        
        // Write test data
        // In Vue: await set(ref(db, testPath), testValue)
        ref.child(testPath).setValue(testValue) { error, _ in
            if let error = error {
                testResult = "❌ Write failed: \(error.localizedDescription)"
                isLoading = false
                return
            }
            
            // If write succeeded, try reading it back
            // In Vue: const snapshot = await get(ref(db, testPath))
            ref.child(testPath).observeSingleEvent(of: .value) { snapshot in
                if let readValue = snapshot.value as? String,
                   readValue == testValue {
                    testResult = "✅ Success!\n\nWrote and read: '\(readValue)'\n\nRealtime Database is working!"
                    
                    // Clean up test data
                    // In Vue: await remove(ref(db, testPath))
                    ref.child(testPath).removeValue()
                } else {
                    testResult = "❌ Read failed or value mismatch"
                }
                isLoading = false
            }
        }
    }
}

// MARK: - How to Use This Test

/*
 To test the Realtime Database setup:
 
 1. Add this view to your MainView or ProfileView temporarily:
 
    NavigationLink("Test Realtime DB") {
        RealtimeDatabaseTestView()
    }
 
 2. Run the app and tap "Test Write & Read"
 
 3. You should see "✅ Success!" if everything is working
 
 4. You can also check the Firebase Console → Realtime Database
    to see the test data (it gets deleted automatically)
 
 In Vue terms:
 - Database.database().reference() = getDatabase()
 - ref.child(path) = ref(db, path)
 - setValue() = set()
 - observeSingleEvent() = get()
 - removeValue() = remove()
 */

