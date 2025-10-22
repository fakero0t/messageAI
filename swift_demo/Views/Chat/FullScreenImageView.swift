//
//  FullScreenImageView.swift
//  swift_demo
//
//  Created for PR-10: Full-screen image viewer with zoom and pan
//

import SwiftUI

struct FullScreenImageView: View {
    let imageUrl: String?
    let localImage: UIImage?
    let message: MessageEntity
    
    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnificationGesture)
                    .gesture(dragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
                scale = min(max(scale, 1), 3)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    offset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if scale <= 1 && value.translation.height > 100 {
                    dismiss()
                } else {
                    lastOffset = offset
                }
            }
    }
    
    private func loadImage() async {
        print("🖼️ [FullScreenImageView] Loading image...")
        
        if let localImage = localImage {
            print("✅ [FullScreenImageView] Using provided local image")
            image = localImage
            return
        }
        
        if let localPath = message.imageLocalPath {
            print("   Trying local path: \(localPath)")
            if let cachedImage = try? ImageFileManager.shared.loadImage(withId: message.id) {
                print("✅ [FullScreenImageView] Loaded from local storage")
                image = cachedImage
                return
            }
        }
        
        guard let urlString = imageUrl ?? message.imageUrl,
              let url = URL(string: urlString) else {
            print("❌ [FullScreenImageView] No valid image URL")
            return
        }
        
        print("   Downloading from: \(urlString)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                image = downloadedImage
                print("✅ [FullScreenImageView] Downloaded successfully")
            }
        } catch {
            print("❌ [FullScreenImageView] Download failed: \(error)")
        }
    }
}

