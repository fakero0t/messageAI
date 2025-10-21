//
//  ImagePickerView.swift
//  swift_demo
//
//  Created for PR-8: Image picker for camera and photo library
//

import SwiftUI
import PhotosUI

/// SwiftUI wrapper for UIImagePickerController (camera + photo library)
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    let sourceType: UIImagePickerController.SourceType
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        print("📷 [ImagePicker] Initialized with source type: \(sourceType == .camera ? "Camera" : "Photo Library")")
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator (Delegate)
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            print("📷 [ImagePicker] Image selected")
            
            if let image = info[.originalImage] as? UIImage {
                let size = image.size
                let sizeInMB = Double((image.jpegData(compressionQuality: 1.0)?.count ?? 0)) / 1024.0 / 1024.0
                
                print("   Dimensions: \(Int(size.width))x\(Int(size.height))")
                print("   Size: \(String(format: "%.2f", sizeInMB))MB")
                
                parent.selectedImage = image
            } else {
                print("❌ [ImagePicker] Failed to get image from picker")
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("📷 [ImagePicker] Cancelled by user")
            parent.dismiss()
        }
    }
}

