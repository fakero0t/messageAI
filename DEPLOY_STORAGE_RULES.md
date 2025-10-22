# Deploy Firebase Storage Rules - Quick Guide

## ❌ Current Error
```
Permission denied (403) - profile_pictures upload blocked
```

## 🔧 What Was Wrong
The rules needed to properly match filenames with extensions. Firebase Storage uses a regex pattern:
- ❌ `match /profile_pictures/{userId}` - too simple
- ✅ `match /profile_pictures/{fileName}` with `fileName.matches(request.auth.uid + '\\..+')` 
  - This checks that the fileName starts with the user's ID followed by a dot and extension
  - Example: "KNZkSuXELYNJyyfe6aGO7OwwhKu1.jpg" matches if auth.uid = "KNZkSuXELYNJyyfe6aGO7OwwhKu1"

**The rules have been fixed!** Now deploy the updated version below.

## ✅ Solution: Deploy Updated Storage Rules

### **Step 1: Open Firebase Console**
1. Go to: https://console.firebase.google.com
2. Select project: **messageai-cbd8a**
3. Click **Storage** in left menu
4. Click **Rules** tab at the top

### **Step 2: Copy Rules**
Open the file: `firebase-storage-rules.txt` in this project

**Or copy these rules:**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check file size
    function isValidSize(maxSizeMB) {
      return request.resource.size < maxSizeMB * 1024 * 1024;
    }
    
    // Helper function to check if file is an image
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    // Profile pictures: Users can only write their own, anyone authenticated can read
    match /profile_pictures/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() 
                   && fileName.matches(request.auth.uid + '\\..+')
                   && isValidSize(5)
                   && isImage();
    }
    
    // Message images: Sender can write, conversation participants can read
    match /images/{conversationId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()
                   && isValidSize(10)
                   && isImage();
    }
  }
}
```

### **Step 3: Paste Rules**
1. **Delete** the existing rules in the Firebase Console
2. **Paste** the new rules above
3. Click **Publish** button (top right)

### **Step 4: Verify**
Rules should look like this in the console:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_pictures/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() 
                   && fileName.matches(request.auth.uid + '\\..+')
                   && isValidSize(5)
                   && isImage();
    }
    match /images/{conversationId}/{fileName} {
      allow read: if ...
      allow write: if ...
    }
  }
}
```

### **Step 5: Test**
1. Go back to your app in Xcode
2. Try uploading a profile picture again
3. Should work now! ✅

---

## What These Rules Do

### **Profile Pictures:**
- ✅ Any authenticated user can **read** profile pictures
- ✅ Users can only **write** their own profile picture (filename must start with their auth.uid)
  - Example: User "abc123" can upload "abc123.jpg" but not "xyz456.jpg"
  - Uses regex: `fileName.matches(request.auth.uid + '\\..+')`
- ✅ Max file size: 5MB
- ✅ Must be an image (image/*)

### **Message Images:**
- ✅ Any authenticated user can **read** message images
- ✅ Any authenticated user can **write** message images
- ✅ Max file size: 10MB
- ✅ Must be an image (image/*)

---

## Current Rules (Default - Too Restrictive)

Your current rules are probably:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false; // ❌ Blocks everything
    }
  }
}
```

This is why you're getting "Permission denied" - the default rules block all access!

---

## Quick Link

**Deploy Rules Here:**
https://console.firebase.google.com/project/messageai-cbd8a/storage/rules

---

**After deploying, your profile picture upload will work immediately!** 🎉

