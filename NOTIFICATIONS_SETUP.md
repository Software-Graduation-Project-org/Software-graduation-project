# إعداد إشعارات Firebase Cloud Messaging

## نظرة عامة
تم إعداد نظام الإشعارات ليعمل على **Android و iOS فقط** (لا يشمل الويب).

## الملفات المطلوبة

### Android
- ✅ `android/app/google-services.json` - موجود
- ✅ `android/app/build.gradle.kts` - يحتوي على `com.google.gms.google-services`
- ✅ `android/app/src/main/AndroidManifest.xml` - يحتوي على Firebase Messaging Service
- ✅ `MedicalLabFirebaseMessagingService.kt` - تم إنشاؤه

### iOS
- ✅ `ios/Runner/GoogleService-Info.plist` - موجود
- ✅ `ios/Runner/AppDelegate.swift` - مهيأ لـ Firebase

## كيفية الاختبار

### 1. تشغيل التطبيق على جهاز
```bash
flutter run
```

### 2. طلب إذن الإشعارات
سيطلب التطبيق تلقائياً إذن الإشعارات عند التشغيل الأول.

### 3. إرسال إشعار تجريبي من Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر مشروع `medical-lab-6a8d4`
3. Cloud Messaging → Send your first message
4. أدخل:
   - Title: `اختبار الإشعارات`
   - Text: `هذا إشعار تجريبي`
   - Target: اختر `User segment` أو `Token` محدد
5. اضغط Send test message

### 4. التحقق من التوكن
شاهد Console للرسالة: `FCM Token: [token]` - هذا يعني أن الإعداد صحيح.

## أنواع الإشعارات المتاحة

### 1. إشعار نتائج تحليل
```dart
await NotificationService().showTestResultNotification('اسم المريض', 'نوع التحليل');
```

### 2. إشعار عام
```dart
await NotificationService().showGeneralNotification('عنوان الإشعار', 'محتوى الإشعار');
```

## إرسال إشعارات من Backend

### Node.js مع Firebase Admin SDK

```javascript
const admin = require('firebase-admin');

// إرسال إشعار لمستخدم محدد
async function sendToUser(userToken, title, body, data) {
  const message = {
    token: userToken,
    notification: { title, body },
    data: data
  };

  await admin.messaging().send(message);
}

// إرسال إشعار لطائفة مستخدمين
async function sendToTopic(topic, title, body, data) {
  const message = {
    topic: topic,
    notification: { title, body },
    data: data
  };

  await admin.messaging().send(message);
}

// أمثلة استخدام
await sendToUser(
  userToken,
  'نتائج التحليل جاهزة',
  'مرحباً أحمد، نتائج فحص الدم جاهزة',
  { type: 'test_result', patient_id: '123' }
);

await sendToTopic(
  'doctor_alerts',
  'تنبيه مهم',
  'مريض يحتاج رعاية',
  { type: 'general', priority: 'normal' }
);
```

## استكشاف الأخطاء

### مشكلة: لا تصل الإشعارات
1. تأكد من أن التطبيق يعمل في الخلفية (لا في Debug mode)
2. تحقق من FCM Token في Console
3. تأكد من إعطاء إذن الإشعارات

### مشكلة: Android لا يعمل
1. تحقق من `google-services.json`
2. تأكد من وجود `MedicalLabFirebaseMessagingService` في Manifest

### مشكلة: iOS لا يعمل
1. تحقق من `GoogleService-Info.plist`
2. تأكد من تفعيل Push Notifications في Xcode
3. تحقق من Background Modes → Remote notifications

## الخطوات التالية

1. ✅ إعداد Firebase FCM
2. 🔄 اختبار الإشعارات على أجهزة حقيقية
3. 🔄 ربط مع Backend API
4. 🔄 إضافة منطق الأعمال (نتائج، مواعيد، طوارئ)