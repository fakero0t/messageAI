# PR-12: User Model and Profile Storage Updates - COMPLETE ✅

## Overview
Added profile picture support to the User model and implemented upload/delete functionality in UserService.

## Files Modified

### 1. **User.swift**
- Added `profileImageUrl: String?` property to store profile picture URL
- Added `initials` computed property:
  - Extracts first letter of first two words in display name
  - Returns uppercased initials (e.g., "John Doe" → "JD")
  - Used as fallback when no profile picture exists

### 2. **UserService.swift**
- Added imports: `FirebaseStorage`, `UIKit`
- Added `uploadProfileImage(userId:image:)` method:
  - Compresses image to 500KB (smaller than message images for faster load)
  - Uploads to Firebase Storage at `profile_pictures/{userId}.jpg`
  - Gets download URL
  - Updates Firestore user document with `profileImageUrl`
  - Updates local `AuthenticationService.currentUser` if it's the current user
  - Returns download URL string
- Added `deleteProfileImage(userId:)` method:
  - Deletes image from Firebase Storage
  - Removes `profileImageUrl` field from Firestore
  - Updates local user object to clear profile picture
- Added `ProfileImageError` enum with:
  - `compressionFailed`
  - `uploadFailed`
  - `deleteFailed`

## Technical Details

### **Profile Picture Path:**
```
profile_pictures/{userId}.jpg
```
Each user has exactly one profile picture, identified by their user ID.

### **Image Compression:**
- Target size: **500KB** (half of message images)
- Format: JPEG
- Smaller size = faster loading in avatars across the app

### **Firestore Update:**
```json
{
  "profileImageUrl": "https://firebasestorage.googleapis.com/..."
}
```

### **Initials Generation:**
- "John Doe" → "JD"
- "Alice" → "A"
- "Bob Smith Jr" → "BS" (takes first 2 words)
- Case-insensitive input, uppercase output

## User Flow (to be implemented in UI later)

1. **Upload:**
   - User selects image from photo library/camera
   - Image compressed to 500KB
   - Uploaded to Firebase Storage
   - URL saved to Firestore
   - Avatar updates across all views

2. **Delete:**
   - User taps "Remove Profile Picture"
   - Image deleted from Storage
   - Field removed from Firestore
   - Avatar shows initials fallback

## Vue/TypeScript Analogy

```typescript
// Similar to this in a Vue app:
interface User {
  id: string
  email: string
  displayName: string
  profileImageUrl?: string  // NEW
  
  // Computed property
  get initials(): string {
    const words = this.displayName.split(' ')
    return words
      .slice(0, 2)
      .map(w => w[0])
      .join('')
      .toUpperCase()
  }
}

// Upload service
async function uploadProfileImage(userId: string, file: File): Promise<string> {
  // Compress image
  const compressed = await compressImage(file, { maxSizeKB: 500 })
  
  // Upload to S3/Firebase Storage
  const url = await storage.upload(`profile_pictures/${userId}.jpg`, compressed)
  
  // Update database
  await db.users.doc(userId).update({ profileImageUrl: url })
  
  // Update local state (like Pinia/Vuex)
  if (authStore.currentUser?.id === userId) {
    authStore.currentUser.profileImageUrl = url
  }
  
  return url
}
```

## What's Next (PR-13+)
- **PR-13:** Create `AvatarView` component to display profile pictures
- **PR-14:** Add profile picture upload UI in settings
- **PR-15:** Display avatars in conversation list
- **PR-16:** Display avatars in chat headers

## Testing Checklist
- [ ] User model decodes correctly with/without `profileImageUrl`
- [ ] Initials property works for various name formats
- [ ] Upload image → Check Firebase Storage console
- [ ] Upload image → Check Firestore users document
- [ ] Delete image → Verify Storage file removed
- [ ] Delete image → Verify Firestore field removed
- [ ] Local user object updates after upload
- [ ] Local user object updates after delete
- [ ] Existing users without profile images work fine

---

**Status:** ✅ COMPLETE
**Linter Errors:** 0
**Ready for:** PR-13 (AvatarView component)

