# Info.plist Setup for Camera and Photo Library Permissions

## Overview
iOS requires usage descriptions for camera and photo library access.

## Steps to Add Permission Descriptions

### Method 1: Using Xcode (Recommended)

1. **Open project in Xcode**
2. Select the project in the navigator (top item)
3. Select the **swift_demo target**
4. Go to the **Info** tab
5. Hover over any key and click the **+** button

6. **Add Camera Permission:**
   - Key: `Privacy - Camera Usage Description` (or `NSCameraUsageDescription`)
   - Value: `MessageAI needs camera access to take photos for messages`

7. **Add Photo Library Permission:**
   - Key: `Privacy - Photo Library Usage Description` (or `NSPhotoLibraryUsageDescription`)
   - Value: `MessageAI needs photo library access to share images in messages`

### Method 2: Create Info.plist File

If you prefer a file-based approach:

1. **Create `Info.plist` in `swift_demo/` directory**
2. **Add this content:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSCameraUsageDescription</key>
    <string>MessageAI needs camera access to take photos for messages</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>MessageAI needs photo library access to share images in messages</string>
</dict>
</plist>
```

3. **Add to project:**
   - Right-click `swift_demo` folder in Xcode
   - Select "Add Files to swift_demo..."
   - Select the `Info.plist` file
   - Make sure "Copy items if needed" is checked
   - Click "Add"

4. **Configure target:**
   - Select project → Target → Build Settings
   - Search for "Info.plist File"
   - Set value to: `swift_demo/Info.plist`

## Verification

After adding, when you run the app and try to:

- **Take Photo**: Alert appears asking "MessageAI would like to access the camera" with your custom message
- **Choose Photo**: Alert appears asking for photo library access with your custom message

## What Happens Without These

If you don't add these keys:
- ❌ App will crash when trying to access camera/photos
- ❌ Error: "This app has crashed because it attempted to access privacy-sensitive data..."

## Testing Permissions

### First Time:
1. Run app
2. Tap photo icon
3. Choose "Take Photo" or "Choose from Library"
4. Permission alert should appear
5. Tap "Allow" or "Don't Allow"

### After Denying:
1. Settings alert should appear
2. Tap "Settings" → Opens app settings
3. Toggle Camera/Photos permission
4. Return to app

### Reset Permissions for Testing:
```bash
# On simulator
xcrun simctl privacy booted reset all com.yourcompany.swift-demo

# On device
Settings → General → Reset → Reset Location & Privacy
```

## What the Descriptions Mean

**`NSCameraUsageDescription`**
- Shown when app requests camera access
- Explains why you need the camera
- User-facing message

**`NSPhotoLibraryUsageDescription`**
- Shown when app requests photo library access
- Explains why you need photo access
- User-facing message

## Best Practices

✅ **Do:**
- Be specific about why you need access
- Use clear, user-friendly language
- Keep it short and concise

❌ **Don't:**
- Use technical jargon
- Be vague ("We need access")
- Make it too long

## Example Messages

**Camera:**
- "Take photos to share in your conversations"
- "Capture moments to send to friends"
- "Send photos directly from your camera"

**Photo Library:**
- "Share photos from your library in chats"
- "Choose images to send in messages"
- "Access your photos to share with contacts"

---

**After adding these**, rebuild the app and the image picker will work correctly!

