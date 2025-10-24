//
//  ImageMessageView.swift
//  swift_demo
//
//  Created for PR-9: Display image messages with progressive loading
//

import SwiftUI

struct ImageMessageView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    let onTap: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    private let maxSize: CGFloat = 300
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxSize, maxHeight: maxSize)
                    .cornerRadius(16)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            onTap()
                        }
                    )
            } else if loadError {
                errorView
            } else {
                placeholderView
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: maxSize, height: maxSize)
            .cornerRadius(16)
            .overlay(
                ProgressView()
            )
    }
    
    private var errorView: some View {
        Rectangle()
            .fill(Color.red.opacity(0.1))
            .frame(width: maxSize, height: maxSize)
            .cornerRadius(16)
            .overlay(
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        print("🖼️ [ImageMessage] Loading image for message: \(message.id)")
        
        // Try local path first (for queued/pending messages)
        if let localPath = message.imageLocalPath {
            print("   Trying local path: \(localPath)")
            if let localImage = try? ImageFileManager.shared.loadImage(withId: message.id) {
                await MainActor.run {
                    image = localImage
                }
                print("✅ [ImageMessage] Loaded from local storage")
                return
            }
        }
        
        // Load from Firebase Storage URL
        guard let urlString = message.imageUrl,
              let url = URL(string: urlString) else {
            print("❌ [ImageMessage] No valid image URL")
            await MainActor.run {
                loadError = true
            }
            return
        }
        
        print("   Downloading from URL: \(urlString)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                await MainActor.run {
                    image = downloadedImage
                }
                print("✅ [ImageMessage] Downloaded from Firebase Storage")
            } else {
                print("❌ [ImageMessage] Failed to create UIImage from data")
                await MainActor.run {
                    loadError = true
                }
            }
        } catch {
            print("❌ [ImageMessage] Download failed: \(error)")
            await MainActor.run {
                loadError = true
            }
        }
    }
}

