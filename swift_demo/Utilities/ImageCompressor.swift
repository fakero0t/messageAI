//
//  ImageCompressor.swift
//  swift_demo
//
//  Created for PR-5: Image compression utilities
//
//  Vue Analogy: This is like an image processing service in Vue
//  - compress() → like using canvas.toDataURL() with quality reduction
//  - resize() → like CSS object-fit or canvas drawImage() with smaller dimensions
//  - generateThumbnail() → like creating preview images for lazy loading
//

import UIKit
import AVFoundation

/// Utility for compressing, resizing, and manipulating images
/// In Vue: const imageCompressor = { compress, resize, generateThumbnail }
struct ImageCompressor {
    
    // MARK: - Compression
    
    /// Compress image to target size in KB while maintaining quality
    /// In Vue: const compress = async (blob, targetKB) => { ... }
    ///
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - targetSizeKB: Target size in kilobytes (default: 1024 = 1MB)
    /// - Returns: Compressed JPEG data, or nil if compression fails
    static func compress(image: UIImage, targetSizeKB: Int = 1024) -> Data? {
        print("🔄 [Compress] Starting compression...")
        print("   Original size: \(image.size.width)x\(image.size.height)")
        
        // First, resize if too large (max 2048 on longest side)
        // This reduces file size dramatically before quality compression
        let resizedImage = resize(image: image, maxDimension: 2048)
        print("   After resize: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // Start with high quality
        var compression: CGFloat = 1.0
        var imageData = resizedImage.jpegData(compressionQuality: compression)
        
        let targetBytes = targetSizeKB * 1024
        
        // Iteratively reduce quality until under target size
        // Like adjusting canvas.toDataURL(quality) in JavaScript
        while let data = imageData, data.count > targetBytes && compression > 0.1 {
            compression -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compression)
            
            if let data = imageData {
                print("   Quality: \(String(format: "%.1f", compression)), Size: \(data.count / 1024)KB")
            }
        }
        
        if let finalData = imageData {
            print("✅ [Compress] Final size: \(finalData.count / 1024)KB (quality: \(String(format: "%.1f", compression)))")
        } else {
            print("❌ [Compress] Compression failed")
        }
        
        return imageData
    }
    
    // MARK: - Resizing
    
    /// Resize image maintaining aspect ratio, constrained within max dimension
    /// In Vue: like using canvas.drawImage() with calculated dimensions
    ///
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - maxDimension: Maximum width or height (default: 1024)
    /// - Returns: Resized UIImage
    static func resize(image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        
        // If already smaller, return as-is
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        // In Vue: const aspectRatio = width / height
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            // Landscape: width is limiting factor
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square: height is limiting factor
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Resize using graphics context
        // In Vue: const canvas = document.createElement('canvas'); ctx.drawImage(...)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    /// Resize image to fit within square bounds while maintaining aspect ratio
    /// Used for message bubbles to ensure consistent display
    /// In Vue: like CSS max-width/max-height with aspect-ratio preserved
    ///
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - maxSize: Maximum width/height (default: 300)
    /// - Returns: Resized UIImage
    static func resizeForDisplay(image: UIImage, maxSize: CGFloat = 300) -> UIImage {
        return resize(image: image, maxDimension: maxSize)
    }
    
    // MARK: - Thumbnails
    
    /// Generate thumbnail for conversation list preview
    /// In Vue: like generating preview images for lazy loading
    ///
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - size: Thumbnail size (default: 100x100)
    /// - Returns: Thumbnail UIImage
    static func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // Calculate rect to maintain aspect ratio (aspect fill)
        // This is like CSS object-fit: cover
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = size.width / size.height
        
        var drawRect = CGRect(origin: .zero, size: size)
        
        if aspectRatio > targetAspectRatio {
            // Image is wider - crop sides
            let scaledWidth = size.height * aspectRatio
            drawRect.origin.x = -(scaledWidth - size.width) / 2
            drawRect.size.width = scaledWidth
        } else {
            // Image is taller - crop top/bottom
            let scaledHeight = size.width / aspectRatio
            drawRect.origin.y = -(scaledHeight - size.height) / 2
            drawRect.size.height = scaledHeight
        }
        
        image.draw(in: drawRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Metadata
    
    /// Get image dimensions
    /// In Vue: const { width, height } = image
    ///
    /// - Parameter image: UIImage
    /// - Returns: (width, height) tuple
    static func getDimensions(_ image: UIImage) -> (width: Double, height: Double) {
        return (Double(image.size.width), Double(image.size.height))
    }
    
    /// Calculate aspect ratio
    /// In Vue: const aspectRatio = width / height
    ///
    /// - Parameter image: UIImage
    /// - Returns: Aspect ratio (width/height)
    static func getAspectRatio(_ image: UIImage) -> Double {
        return Double(image.size.width) / Double(image.size.height)
    }
}

// MARK: - Vue/TypeScript Comparison

/*
 This Swift utility is equivalent to this Vue composable:
 
 ```typescript
 // composables/useImageCompressor.ts
 export const useImageCompressor = () => {
   // Compress image to target size
   const compress = async (file: File, targetSizeKB: number = 1024): Promise<Blob> => {
     const img = await loadImage(file)
     const canvas = document.createElement('canvas')
     const ctx = canvas.getContext('2d')!
     
     // Resize first
     const { width, height } = calculateResizeSize(img, 2048)
     canvas.width = width
     canvas.height = height
     ctx.drawImage(img, 0, 0, width, height)
     
     // Iteratively reduce quality
     let quality = 1.0
     let blob = await canvasToBlob(canvas, quality)
     
     while (blob.size > targetSizeKB * 1024 && quality > 0.1) {
       quality -= 0.1
       blob = await canvasToBlob(canvas, quality)
     }
     
     return blob
   }
   
   // Resize image maintaining aspect ratio
   const resize = (img: HTMLImageElement, maxDimension: number): HTMLImageElement => {
     if (img.width <= maxDimension && img.height <= maxDimension) return img
     
     const aspectRatio = img.width / img.height
     let newWidth, newHeight
     
     if (img.width > img.height) {
       newWidth = maxDimension
       newHeight = maxDimension / aspectRatio
     } else {
       newWidth = maxDimension * aspectRatio
       newHeight = maxDimension
     }
     
     const canvas = document.createElement('canvas')
     canvas.width = newWidth
     canvas.height = newHeight
     const ctx = canvas.getContext('2d')!
     ctx.drawImage(img, 0, 0, newWidth, newHeight)
     
     const resizedImg = new Image()
     resizedImg.src = canvas.toDataURL()
     return resizedImg
   }
   
   // Generate thumbnail
   const generateThumbnail = (img: HTMLImageElement, size: number = 100): Blob => {
     const canvas = document.createElement('canvas')
     canvas.width = size
     canvas.height = size
     const ctx = canvas.getContext('2d')!
     
     // Aspect fill (like object-fit: cover)
     const aspectRatio = img.width / img.height
     let drawWidth, drawHeight, offsetX = 0, offsetY = 0
     
     if (aspectRatio > 1) {
       // Wider - crop sides
       drawWidth = size * aspectRatio
       drawHeight = size
       offsetX = -(drawWidth - size) / 2
     } else {
       // Taller - crop top/bottom
       drawWidth = size
       drawHeight = size / aspectRatio
       offsetY = -(drawHeight - size) / 2
     }
     
     ctx.drawImage(img, offsetX, offsetY, drawWidth, drawHeight)
     return canvas.toDataURL()
   }
   
   return { compress, resize, generateThumbnail }
 }
 ```
 
 Key similarities:
 - compress() → Canvas toDataURL() with quality iteration
 - resize() → Canvas drawImage() with aspect ratio math
 - generateThumbnail() → Canvas with aspect fill (object-fit: cover)
 */

