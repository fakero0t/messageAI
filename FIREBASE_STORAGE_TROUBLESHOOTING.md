# Firebase Storage Upload Troubleshooting

## Issue: "Object does not exist" after upload

If you're seeing errors like:
```
❌ [ImageUpload] Upload failed: Object images/.../....jpg does not exist.
```

This happens when the upload completes but the download URL fetch fails immediately after.

## Solutions Implemented

### 1. **Retry Logic with Delay** ✅
Added automatic retry logic in `ImageUploadService`:
- Initial 0.5s delay after upload completes
- 3 retry attempts with exponential backoff (0.5s, 1s, 2s)
- This handles Firebase Storage timing issues

### 2. **Deploy Firebase Storage Rules**

Make sure your Storage rules are deployed:

#### **Step 1: Go to Firebase Console**
1. Open https://console.firebase.google.com/
2. Select your project
3. Click **Storage** in left sidebar
4. Click **Rules** tab

#### **Step 2: Copy and paste these rules:**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check file size (in MB)
    function isValidSize(maxSizeMB) {
      return request.resource.size < maxSizeMB * 1024 * 1024;
    }
    
    // Helper function to check if file is an image
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    // Profile pictures
    match /profile_pictures/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() 
                   && request.auth.uid == userId
                   && isValidSize(5)
                   && isImage();
    }
    
    // Message images
    match /images/{conversationId}/{messageId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()
                   && isValidSize(10)
                   && isImage();
    }
  }
}
```

#### **Step 3: Click "Publish"**

⚠️ **Important:** Rules take a few seconds to propagate after publishing.

## Testing

After deploying rules and rebuilding the app:

1. **Test upload:** Send an image in a chat
2. **Check console logs:**
   - Should see: `✅ [ImageUpload] Upload complete`
   - Should see: `✅ [ImageUpload] Download URL: https://...`
   - Should NOT see: `❌ Upload failed: Object does not exist`

3. **Test retry:** If an image fails, tap the retry button
   - Should automatically retry up to 3 times
   - Should succeed if rules are deployed

## Common Issues

### Rules not deployed
- **Symptom:** Uploads reach 100% but fail to get URL
- **Fix:** Deploy rules in Firebase Console → Storage → Rules

### Wrong path format
- **Symptom:** Error mentions unexpected path
- **Fix:** Check that paths match: `images/{conversationId}/{messageId}.jpg`

### Network timeout
- **Symptom:** Upload never reaches 100%
- **Fix:** Check internet connection, Firebase project configured correctly

### Authentication issue
- **Symptom:** Upload fails immediately (0%)
- **Fix:** Make sure user is signed in to Firebase Auth

## How the Retry Logic Works

```typescript
// Similar to this in Vue/JavaScript:
async function getDownloadURL(ref, attempt = 1, maxAttempts = 3) {
  try {
    const url = await ref.getDownloadURL()
    return url
  } catch (error) {
    if (attempt < maxAttempts) {
      const delay = 0.5 * attempt * 1000 // ms
      await sleep(delay)
      return getDownloadURL(ref, attempt + 1, maxAttempts)
    } else {
      throw error
    }
  }
}
```

Swift equivalent:
- Attempt 1: Immediate
- Attempt 2: After 0.5s delay
- Attempt 3: After 1s delay (total 1.5s)
- Attempt 4: After 2s delay (total 3.5s)

---

**If issue persists after:**
1. ✅ Deploying Storage rules
2. ✅ Rebuilding app
3. ✅ Checking authentication

Then check Firebase Console → Storage to see if images are actually being uploaded.

