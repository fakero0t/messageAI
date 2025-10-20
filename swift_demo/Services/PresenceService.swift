//
//  PresenceService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore
import UIKit
import Combine

class PresenceService: ObservableObject {
    static let shared = PresenceService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    
    private init() {}
    
    func startTracking(for userId: String) {
        currentUserId = userId
        setUserOnline(userId: userId)
        setupLifecycleObservers(userId: userId)
    }
    
    func stopTracking() {
        guard let userId = currentUserId else { return }
        setUserOffline(userId: userId)
        cancellables.removeAll()
        currentUserId = nil
    }
    
    private func setUserOnline(userId: String) {
        db.collection("users").document(userId).setData([
            "online": true,
            "lastSeen": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("Error setting user online: \(error)")
            }
        }
    }
    
    private func setUserOffline(userId: String) {
        db.collection("users").document(userId).setData([
            "online": false,
            "lastSeen": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("Error setting user offline: \(error)")
            }
        }
    }
    
    private func setupLifecycleObservers(userId: String) {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.setUserOnline(userId: userId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.setUserOffline(userId: userId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.setUserOffline(userId: userId)
            }
            .store(in: &cancellables)
    }
}

