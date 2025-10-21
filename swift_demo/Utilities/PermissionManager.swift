//
//  PermissionManager.swift
//  swift_demo
//
//  Created for PR-8: Handle camera and photo library permissions
//
//  Vue Analogy: This is like permission handling in a PWA
//  - requestCameraPermission() → like navigator.mediaDevices.getUserMedia({ video: true })
//  - requestPhotoLibraryPermission() → like <input type="file"> (auto-granted in web)
//  - showPermissionDeniedAlert() → like showing a UI notification/modal
//

import AVFoundation
import Photos
import UIKit

/// Manages permission requests for camera and photo library
/// In Vue: class PermissionManager { requestCamera, requestPhotoLibrary }
class PermissionManager {
    // Singleton pattern
    // In Vue: export const permissionManager = new PermissionManager()
    static let shared = PermissionManager()
    
    private init() {
        print("🔐 [PermissionManager] Initialized")
    }
    
    // MARK: - Camera Permissions
    
    /// Request camera permission from user
    /// In Vue: const requestCamera = async () => await navigator.mediaDevices.getUserMedia({ video: true })
    ///
    /// - Returns: True if granted, false if denied
    func requestCameraPermission() async -> Bool {
        print("🔐 [PermissionManager] Requesting camera permission...")
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            print("✅ [PermissionManager] Camera already authorized")
            return true
            
        case .notDetermined:
            // First time asking
            print("ℹ️ [PermissionManager] Camera permission not determined, requesting...")
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            
            print(granted ? "✅ [PermissionManager] Camera permission granted" : "❌ [PermissionManager] Camera permission denied")
            return granted
            
        case .denied, .restricted:
            print("❌ [PermissionManager] Camera permission denied or restricted")
            return false
            
        @unknown default:
            print("❌ [PermissionManager] Unknown camera permission status")
            return false
        }
    }
    
    /// Check if camera permission is already granted
    /// In Vue: const hasCameraPermission = () => cameraStream !== null
    ///
    /// - Returns: True if authorized
    func checkCameraPermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .authorized
    }
    
    // MARK: - Photo Library Permissions
    
    /// Request photo library permission from user
    /// In Vue: In web, file input auto-requests permission, no explicit API needed
    ///
    /// - Returns: True if granted, false if denied
    func requestPhotoLibraryPermission() async -> Bool {
        print("🔐 [PermissionManager] Requesting photo library permission...")
        
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            print("✅ [PermissionManager] Photo library already authorized")
            return true
            
        case .notDetermined:
            // First time asking
            print("ℹ️ [PermissionManager] Photo library permission not determined, requesting...")
            let granted = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized || status == .limited)
                }
            }
            
            print(granted ? "✅ [PermissionManager] Photo library permission granted" : "❌ [PermissionManager] Photo library permission denied")
            return granted
            
        case .denied, .restricted:
            print("❌ [PermissionManager] Photo library permission denied or restricted")
            return false
            
        @unknown default:
            print("❌ [PermissionManager] Unknown photo library permission status")
            return false
        }
    }
    
    /// Check if photo library permission is already granted
    /// In Vue: Not needed in web, file input always works
    ///
    /// - Returns: True if authorized
    func checkPhotoLibraryPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        return status == .authorized || status == .limited
    }
    
    // MARK: - Permission Denied Alerts
    
    /// Show alert when permission is denied, with link to Settings
    /// In Vue: const showPermissionAlert = (type) => showModal({ message, actions: ['Settings', 'Cancel'] })
    ///
    /// - Parameter permission: Type of permission (camera or photo library)
    func showPermissionDeniedAlert(for permission: PermissionType) {
        print("⚠️ [PermissionManager] Showing permission denied alert for: \(permission.rawValue)")
        
        DispatchQueue.main.async {
            // Get the root view controller to present alert
            // In Vue: Use a modal/dialog component at root level
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ [PermissionManager] Failed to get root view controller")
                return
            }
            
            // Create alert
            // In Vue: showAlert({ title, message, actions })
            let alert = UIAlertController(
                title: "\(permission.rawValue) Access Required",
                message: "Please enable \(permission.rawValue) access in Settings to use this feature.",
                preferredStyle: .alert
            )
            
            // Settings button
            // In Vue: { text: 'Settings', onClick: () => openSettings() }
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                print("🔐 [PermissionManager] User tapped Settings")
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            
            // Cancel button
            // In Vue: { text: 'Cancel', onClick: () => closeModal() }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                print("🔐 [PermissionManager] User tapped Cancel")
            })
            
            // Present alert
            // In Vue: modalIsVisible.value = true
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Permission Types

/// Types of permissions the app can request
/// In Vue: type PermissionType = 'camera' | 'photoLibrary'
enum PermissionType: String {
    case camera = "Camera"
    case photoLibrary = "Photo Library"
}

