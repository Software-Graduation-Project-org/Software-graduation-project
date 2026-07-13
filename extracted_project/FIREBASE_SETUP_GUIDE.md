# Firebase Cloud Messaging (FCM) Setup Guide

This guide will help you implement push notifications in your Flutter medical lab application.

## 🚀 Step-by-Step Implementation

### Step 1: Firebase Console Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Create a project" or "Add project"
   - Enter your project name (e.g., "medical-lab-system")
   - Enable Google Analytics (recommended)

2. **Add Android App**
   - Click the Android icon to add your Android app
   - Package name: `com.example.frontend_flutter` (check your `android/app/build.gradle`)
   - Download `google-services.json`
   - Place it in: `android/app/google-services.json`

3. **Add iOS App**
   - Click the iOS icon to add your iOS app
   - Bundle ID: Check your `ios/Runner.xcodeproj/project.pbxproj`
   - Download `GoogleService-Info.plist`
   - Place it in: `ios/Runner/GoogleService-Info.plist`

4. **Enable Cloud Messaging**
   - Go to Project Settings → Cloud Messaging
   - Note down your Server Key and Sender ID
   - These will be used in your backend configuration

### Step 2: Flutter App Configuration

The Flutter app has been pre-configured with:
- ✅ Firebase packages added to `pubspec.yaml`
- ✅ Notification service created (`lib/services/notification_service.dart`)
- ✅ Firebase options configured (`lib/config/firebase_options.dart`)
- ✅ Main.dart updated to initialize Firebase
- ✅ Android manifest updated with permissions
- ✅ iOS AppDelegate updated for notifications

**Update Firebase Configuration:**
1. Replace the placeholder values in `lib/config/firebase_options.dart` with your actual Firebase project values
2. Update the Android package name in `android/app/build.gradle` if different
3. Update the iOS bundle ID in Xcode if different

### Step 3: Backend Configuration

1. **Install Firebase Admin SDK**
   ```bash
   cd backend
   npm install firebase-admin
   ```

2. **Configure Firebase Service Account**
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Download the JSON file
   - Rename it to `firebase-service-account.json`
   - Place it in: `backend/config/firebase-service-account.json`

3. **Update Firebase Options**
   - Edit `lib/config/firebase_options.dart` with your actual values from Firebase Console

### Step 4: Android-Specific Setup

1. **Update Android Manifest**
   - The manifest has been pre-configured with:
     - Internet permission
     - Notification permissions
     - Firebase messaging service

2. **Create Notification Sound (Optional)**
   - Place sound files in: `android/app/src/main/res/raw/`
   - Reference in notification service: `sound: RawResourceAndroidNotificationSound('urgent')`

### Step 5: iOS-Specific Setup

1. **Update Info.plist**
   - The Info.plist has been pre-configured with:
     - Background modes for remote notifications
     - Notification permissions

2. **Enable Push Notifications in Xcode**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select your target → Signing & Capabilities
   - Add "Push Notifications" capability
   - Add "Background Modes" capability and check "Remote notifications"

### Step 6: Testing Push Notifications

1. **Test Token Registration**
   ```bash
   # Start your backend
   cd backend && npm run dev

   # Start your Flutter app
   cd frontend_flutter && flutter run
   ```

2. **Test Notification Sending**
   ```bash
   # Test from backend (replace with actual values)
   curl -X POST http://localhost:5000/api/notifications/send-to-user \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
     -d '{
       "user_id": "USER_ID",
       "user_role": "patient",
       "title": "Test Notification",
       "message": "This is a test push notification",
       "data": {"type": "test"}
     }'
   ```

## 📱 Notification Types Supported

- **General Notifications**: Default notifications
- **Test Results**: When lab results are available

## 🔧 API Endpoints

### Register FCM Token
```
POST /api/notifications/register-token
Authorization: Bearer <token>
Body: { "token": "fcm_token", "user_id": "id", "user_role": "patient", "platform": "android" }
```

### Send to Single User
```
POST /api/notifications/send-to-user
Authorization: Bearer <admin_token>
Body: { "user_id": "id", "user_role": "patient", "title": "Title", "message": "Message" }
```

### Send Bulk Notifications
```
POST /api/notifications/send-bulk
Authorization: Bearer <admin_token>
Body: { "user_ids": ["id1", "id2"], "user_role": "patient", "title": "Title", "message": "Message" }
```

### Send Test Result Notification
```
POST /api/notifications/test-result
Authorization: Bearer <staff_token>
Body: { "patient_id": "id", "test_name": "Blood Test", "result_id": "result_id" }
```

## 🐛 Troubleshooting

### Common Issues:

1. **Notifications not appearing on Android**
   - Check notification permissions in app settings
   - Verify channel creation in Android 8.0+
   - Check Firebase configuration

2. **Notifications not appearing on iOS**
   - Verify push notification capability in Xcode
   - Check device token registration
   - Ensure background modes are enabled

3. **FCM Token not registering**
   - Check Firebase project configuration
   - Verify internet connection
   - Check backend logs for errors

### Debug Commands:

```bash
# Check Firebase connection
flutter pub run firebase_messaging:firebase_messaging

# Check Android logs
adb logcat | grep -i firebase

# Check iOS logs
flutter logs
```

## 📋 Checklist

- [ ] Firebase project created
- [ ] Android app added to Firebase
- [ ] iOS app added to Firebase
- [ ] google-services.json downloaded and placed
- [ ] GoogleService-Info.plist downloaded and placed
- [ ] Firebase options updated in Flutter
- [ ] Service account key downloaded and placed
- [ ] Android manifest permissions added
- [ ] iOS capabilities enabled
- [ ] Backend Firebase Admin SDK installed
- [ ] Notification routes added to server
- [ ] Test notifications working

## 🎯 Next Steps

1. Test the implementation with a real device
2. Implement notification handling in your app screens
3. Add notification badges to app icon
4. Implement notification history screen
5. Add notification preferences for users

## 📞 Support

If you encounter issues:
1. Check Firebase Console for error messages
2. Verify all configuration files are correctly placed
3. Test with Firebase's sample apps first
4. Check Flutter and Firebase documentation

---

**Note**: This implementation includes both foreground and background notification handling, with proper platform-specific configurations for Android and iOS.