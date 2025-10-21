# Firebase Storage Setup Guide

## Overview
Firebase Storage hosts all images in the app:
- **Message images**: Photos sent in chats
- **Profile pictures**: User avatars

## Storage Structure
```
firebase-storage-bucket/
├── images/
│   └── {conversationId}/
│       └── {messageId}.jpg
└── profile_pictures/
    └── {userId}.jpg
```

---

## Step-by-Step Setup

### 1. Enable Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click **Build** → **Storage** in left sidebar
4. Click **Get Started**
5. Choose **Start in production mode** (we'll add rules next)
6. Select storage location (same region as your Firestore/Realtime DB)
7. Click **Done**

### 2. Configure Security Rules

1. In Firebase Storage, click the **Rules** tab
2. **Copy the contents** of `firebase-storage-rules.txt` from this project
3. **Paste** into the Rules editor
4. Click **Publish**

### 3. Verify Rules Are Active

After publishing, you should see:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures
    match /profile_pictures/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && request.auth.uid == userId...
    }
    
    // Message images
    match /images/{conversationId}/{messageId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()...
    }
  }
}
```

### 4. Add Firebase Storage SDK to Xcode

**Check if already added:**
1. In Xcode, go to **Project Navigator** (left sidebar)
2. Click on your project (top item)
3. Select your app target
4. Go to **Frameworks, Libraries, and Embedded Content**
5. Look for `FirebaseStorage`

**If NOT present, add it:**
1. Go to **File** → **Add Package Dependencies**
2. Search: `https://github.com/firebase/firebase-ios-sdk`
3. Version: Select latest (10.0.0+)
4. In the package list, check **FirebaseStorage**
5. Click **Add Package**

### 5. Test the Setup

Run the app and use the Storage Test View (see below) to verify:
- ✅ Upload image succeeds
- ✅ Download image succeeds  
- ✅ Delete image succeeds
- ✅ Unauthorized access fails

---

## Security Rules Explained

### Profile Pictures Rule

```javascript
match /profile_pictures/{userId} {
  allow read: if isAuthenticated();              // Any authenticated user can view
  allow write: if isAuthenticated()              // User must be authenticated
               && request.auth.uid == userId     // Can only write own profile
               && isValidSize(5)                 // Max 5MB
               && isImage();                     // Must be image/* MIME type
}
```

**In Vue/API terms:**
```typescript
// Like middleware that checks:
if (!user) throw 401                           // Must be logged in
if (uploadingUserId !== user.id) throw 403    // Can't change others' profiles
if (fileSize > 5MB) throw 413                 // File too large
if (mimeType !== 'image/*') throw 415         // Wrong file type
```

### Message Images Rule

```javascript
match /images/{conversationId}/{messageId} {
  allow read: if isAuthenticated();              // Any authenticated user can view
  allow write: if isAuthenticated()              // User must be authenticated
               && isValidSize(10)                // Max 10MB
               && isImage();                     // Must be image/* MIME type
}
```

**Note:** Message images have a higher limit (10MB vs 5MB) since they may be higher quality photos.

---

## Usage Quotas & Limits

### Free Tier (Spark Plan)
- **Storage:** 5GB
- **Downloads:** 1GB/day
- **Uploads:** 1GB/day

### Recommended Limits in App
- **Profile pictures:** 5MB max (compressed to ~1MB)
- **Message images:** 10MB max (compressed to ~1MB)
- These client-side limits are MORE restrictive than Firebase rules (good practice)

---

## Testing Checklist

### ✅ Success Cases
- [ ] Authenticated user uploads profile picture <5MB → Success
- [ ] Authenticated user uploads message image <10MB → Success
- [ ] Download uploaded image → Success
- [ ] Delete uploaded image → Success

### ❌ Failure Cases (Should Fail with Permission Denied)
- [ ] Unauthenticated user tries to upload → Permission denied
- [ ] User A tries to upload User B's profile picture → Permission denied
- [ ] Upload image >5MB to profile_pictures → Permission denied
- [ ] Upload image >10MB to images → Permission denied
- [ ] Upload .txt file → Permission denied

---

## Storage Structure Details

### Profile Pictures
- **Path:** `/profile_pictures/{userId}.jpg`
- **Example:** `/profile_pictures/abc123.jpg`
- **Naming:** Always use `{userId}.jpg` (overwrites old picture automatically)
- **Access:** Any authenticated user can read, only owner can write

### Message Images
- **Path:** `/images/{conversationId}/{messageId}.jpg`
- **Example:** `/images/conv_abc_xyz/msg_123.jpg`
- **Naming:** Use message ID as filename (unique per message)
- **Access:** Any authenticated user can read/write

---

## Common Issues & Solutions

### Issue: "Permission denied" when uploading
**Solutions:**
1. Verify user is authenticated (`Auth.auth().currentUser != nil`)
2. Check Firebase Console → Storage → Rules (must be published)
3. Verify file size is under limit
4. Verify MIME type is `image/*`

### Issue: "Storage bucket not configured"
**Solutions:**
1. Check `GoogleService-Info.plist` has `STORAGE_BUCKET` key
2. Re-download `GoogleService-Info.plist` from Firebase Console
3. Clean build (`Cmd + Shift + K`) and rebuild

### Issue: Images uploading but not downloading
**Solutions:**
1. Check network connectivity
2. Verify download URL is correct (should start with `https://firebasestorage.googleapis.com`)
3. Check Firebase Console → Storage to see if file exists

---

## Monitoring & Maintenance

### Monitor Usage
1. Go to Firebase Console → Storage
2. Click **Usage** tab
3. Monitor:
   - Total storage used
   - Bandwidth used
   - Number of operations

### Set Up Billing Alerts
1. Go to Firebase Console → Project Settings
2. Click **Usage and Billing**
3. Set up budget alerts (e.g., alert at 80% of free tier)

### Clean Up Old Files
Consider implementing cleanup for:
- Deleted user profile pictures
- Images from deleted messages/conversations
- Can use Firebase Functions or Cloud Storage lifecycle rules

---

## Security Best Practices

✅ **Do:**
- Compress images client-side before upload
- Validate file types client-side (better UX)
- Use server-side validation (Firebase rules) as final check
- Monitor usage regularly
- Use unique filenames (UUIDs) to prevent overwrites

❌ **Don't:**
- Never use test mode in production
- Don't trust client-side validation alone
- Don't upload uncompressed images
- Don't store sensitive data in filenames

---

## Next Steps

After completing Storage setup:
1. Implement image compression (PR-5)
2. Create ImageService for upload/download (PR-6)
3. Build image message UI (PR-7)
4. Add profile picture features (PRs 12-16)

---

## Quick Reference

### Upload Image
```swift
import FirebaseStorage

let storage = Storage.storage()
let ref = storage.reference().child("images/\(conversationId)/\(messageId).jpg")

ref.putData(imageData, metadata: nil) { metadata, error in
    if let error = error {
        print("Upload failed: \(error)")
    } else {
        print("Upload succeeded!")
    }
}
```

### Download Image
```swift
let ref = storage.reference().child("images/\(conversationId)/\(messageId).jpg")

ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
    if let data = data, let image = UIImage(data: data) {
        print("Download succeeded!")
    }
}
```

### Delete Image
```swift
let ref = storage.reference().child("images/\(conversationId)/\(messageId).jpg")

ref.delete { error in
    if let error = error {
        print("Delete failed: \(error)")
    } else {
        print("Delete succeeded!")
    }
}
```

