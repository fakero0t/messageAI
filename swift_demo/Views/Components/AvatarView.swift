//
//  AvatarView.swift
//  swift_demo
//
//  Created for PR-13: Reusable avatar component
//

import SwiftUI

struct AvatarView: View {
    let user: User?
    let size: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    // Generate consistent color based on user ID
    private var backgroundColor: Color {
        guard let user = user else { return .gray }
        
        let colors: [Color] = [
            .blue, .green, .orange, .purple, 
            .pink, .red, .teal, .indigo
        ]
        
        let index = abs(user.id.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
            
            if let image = image {
                // Profile picture
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let user = user {
                // Initials
                Text(user.initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
            } else {
                // Placeholder (no user)
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: user?.profileImageUrl) { _, _ in
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        guard let urlString = user?.profileImageUrl,
              let url = URL(string: urlString) else {
            image = nil
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🖼️ [AvatarView] Loading profile image for user: \(user?.displayName ?? "Unknown")")
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: urlString) {
            image = cachedImage
            print("✅ [AvatarView] Loaded from cache")
            return
        }
        
        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                ImageCache.shared.set(downloadedImage, forKey: urlString)
                image = downloadedImage
                print("✅ [AvatarView] Downloaded profile image")
            }
        } catch {
            print("❌ [AvatarView] Failed to load profile image: \(error)")
            image = nil
        }
    }
}

// MARK: - Size Presets

extension AvatarView {
    static let sizeSmall: CGFloat = 32
    static let sizeMedium: CGFloat = 48
    static let sizeLarge: CGFloat = 80
    static let sizeExtraLarge: CGFloat = 120
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB
        print("📦 [ImageCache] Initialized with 100 image limit, 50MB max")
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
        print("🗑️ [ImageCache] Cache cleared")
    }
}

