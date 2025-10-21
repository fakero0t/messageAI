# **MessageAI Rubric**

## **Section 1: Core Messaging Infrastructure**

### **Real-Time Message Delivery**

* Sub-200ms message delivery on good network  
* Messages appear instantly for all online users  
* Zero visible lag during rapid messaging (20+ messages)  
* Typing indicators work smoothly  
* Presence updates (online/offline) sync immediately

### **Offline Support & Persistence**

* User goes offline → messages queue locally → send when reconnected  
* App force-quit → reopen → full chat history preserved  
* Messages sent while offline appear for other users once online  
* Network drop (30s+) → auto-reconnects with complete sync  
* Clear UI indicators for connection status and pending messages  
* Sub-1 second sync time after reconnection

**Testing Scenarios:**

1. Send 5 messages while offline → go online → all messages deliver  
2. Force quit app mid-conversation → reopen → chat history intact  
3. Network drop for 30 seconds → messages queue and sync on reconnect  
4. Receive messages while offline → see them immediately when online

### **Group Chat Functionality**

* 3+ users can message simultaneously  
* Clear message attribution (names/avatars)  
* Read receipts show who's read each message  
* Typing indicators work with multiple users  
* Group member list with online status  
* Smooth performance with active conversation

## **Section 2: Mobile App Quality**

### **Mobile Lifecycle Handling**

* App backgrounding → WebSocket maintains or reconnects instantly  
* Foregrounding → instant sync of missed messages  
* Push notifications work when app is closed  
* No messages lost during lifecycle transitions  
* Battery efficient (no excessive background activity)

### **Performance & UX**

* App launch to chat screen \<2 seconds  
* Smooth 60 FPS scrolling through 1000+ messages  
* Optimistic UI updates (messages appear instantly before server confirm)  
* Images load progressively with placeholders  
* Keyboard handling perfect (no UI jank)  
* Professional layout and transitions

## **Section 4: Technical Implementation**

* Clean, well-organized code  
* API keys secured (never exposed in mobile app)  
* Function calling/tool use implemented correctly  
* RAG pipeline for conversation context  
* Rate limiting implemented  
* Response streaming for long operations (if applicable)

### **Authentication & Data Management** 

* Robust auth system (Firebase Auth, Auth0, or equivalent)  
* Secure user management  
* Proper session handling  
* Local database (SQLite/Realm/SwiftData) implemented correctly  
* Data sync logic handles conflicts  
* User profiles with photos working

## **Section 5: Documentation & Deployment**

* Clear, comprehensive README  
* Step-by-step setup instructions  
* Architecture overview with diagrams  
* Environment variables template  
* Easy to run locally  
* Code is well-commented

