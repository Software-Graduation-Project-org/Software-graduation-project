# 🔥 دليل إعداد Firebase للإشعارات - خطوة بخطوة

## ✅ **النقطة 1: التحقق من كود FCM Token في Flutter**

### الكود موجود وجاهز! ✅

#### 1. **كود حفظ FCM Token:**
الموقع: `lib/services/notification_service.dart`

```dart
// عند تسجيل الدخول، يتم استدعاء:
await notificationService.registerFCMToken(
  userId: userId,
  userType: 'patient' // or 'staff'
);
```

#### 2. **كيفية عمل الكود:**

**أ. الحصول على Token من Firebase:**
```dart
// في notification_service_mobile.dart
String? token = await FirebaseMessaging.instance.getToken();
```

**ب. إرسال Token للـ Backend:**
```dart
await ApiService.post('/notifications/register-token', {
  'userId': userId,
  'token': token,
  'userType': userType, // patient, staff, doctor
});
```

**ج. تحديث Token عند التغيير:**
```dart
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
  await service.saveTokenToServer(newToken);
});
```

#### 3. **أين يتم استدعاء الكود:**

✅ **في patient_auth_provider.dart:**
- عند فتح التطبيق (إذا كان المستخدم مسجل دخول)
- بعد تسجيل الدخول مباشرة

✅ **في staff_auth_provider.dart:**
- عند فتح التطبيق (إذا كان الموظف مسجل دخول)
- بعد تسجيل الدخول مباشرة

---

## 🚀 **النقطة 2: إعداد Firebase - الخطوات العملية**

### **الخطوة 1: إنشاء مشروع Firebase**

1. **افتح Firebase Console:**
   - اذهب إلى: https://console.firebase.google.com
   - اضغط على **"Add project"** أو **"إضافة مشروع"**

2. **أدخل معلومات المشروع:**
   ```
   اسم المشروع: medical-lab-system
   ☑️ Enable Google Analytics (اختياري)
   ```

3. **اضغط Create Project**

---

### **الخطوة 2: إضافة تطبيق Android**

1. **في Firebase Console → Project Overview:**
   - اضغط على أيقونة Android (🤖)

2. **أدخل Package Name:**
   ```
   Package name: com.example.frontend_flutter
   ```
   > للتأكد من Package Name، افتح:
   > `frontend_flutter/android/app/build.gradle`
   > ابحث عن: `applicationId`

3. **Download google-services.json:**
   - اضغط **"Download google-services.json"**
   - ضعه في: `frontend_flutter/android/app/google-services.json`

4. **أكمل الخطوات واضغط Continue**

---

### **الخطوة 3: إضافة تطبيق iOS (اختياري)**

1. **في Firebase Console:**
   - اضغط على أيقونة iOS (🍎)

2. **أدخل Bundle ID:**
   - للتأكد، افتح: `frontend_flutter/ios/Runner.xcodeproj` في Xcode

3. **Download GoogleService-Info.plist:**
   - ضعه في: `frontend_flutter/ios/Runner/GoogleService-Info.plist`

---

### **الخطوة 4: الحصول على Service Account JSON**

1. **في Firebase Console:**
   - اذهب إلى: **⚙️ Project Settings** → **Service accounts**
   
2. **Generate new private key:**
   - اضغط على **"Generate new private key"**
   - احفظ الملف

3. **إعادة تسمية ووضع الملف:**
   ```bash
   # أعد تسميته إلى:
   firebase-service-account.json
   
   # ضعه في:
   backend/config/firebase-service-account.json
   ```

---

### **الخطوة 5: تفعيل Firebase في Flutter**

#### أ. التأكد من firebase.json:
الملف موجود في: `frontend_flutter/firebase.json` ✅

#### ب. التأكد من pubspec.yaml:
```yaml
dependencies:
  firebase_core: ^2.x.x
  firebase_messaging: ^14.x.x
  flutter_local_notifications: ^16.x.x
```

#### ج. تشغيل الأوامر:
```bash
cd frontend_flutter
flutter pub get
flutter clean
flutter build apk --debug  # للتأكد من التكامل
```

---

### **الخطوة 6: تفعيل Firebase Admin في Backend**

#### أ. التأكد من التثبيت:
```bash
cd backend
npm install firebase-admin --save
```

#### ب. التحقق من notificationController.js:
الكود موجود وجاهز! ✅

```javascript
// سيقرأ الملف تلقائيًا:
const serviceAccount = require('../config/firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'medical-lab-6a8d4' // استبدله بـ project_id من الملف
});
```

#### ج. إعادة تشغيل Backend:
```bash
cd backend
npm start
```

---

## 🧪 **النقطة 3: اختبار الإشعارات بعد الإعداد**

### **اختبار 1: التحقق من تسجيل FCM Token**

#### **من التطبيق:**
1. شغّل التطبيق على جهاز حقيقي (ليس Emulator)
2. سجّل دخول كمريض أو موظف
3. راقب logs في VS Code terminal

**يجب أن ترى:**
```
📱 FCM Token: ey...xyz (طويل جدًا)
✅ FCM token stored in database for Patient: 677...
```

#### **من Backend:**
```bash
cd backend
node -e "
const mongoose = require('mongoose');
const FCMToken = require('./models/FCMToken');

mongoose.connect('mongodb://localhost:27017/medical-lab').then(async () => {
  const tokens = await FCMToken.find({}).populate('user_id');
  console.log('Registered FCM Tokens:', tokens.length);
  
  tokens.forEach(token => {
    console.log('User:', token.user_id);
    console.log('Token:', token.token.substring(0, 50) + '...');
    console.log('Active:', token.is_active);
    console.log('---');
  });
  
  mongoose.disconnect();
}).catch(console.error);
"
```

---

### **اختبار 2: إرسال إشعار تجريبي من Backend**

#### **باستخدام Postman أو curl:**

```bash
# 1. احصل على userId من قاعدة البيانات
# 2. احصل على staff token (أي موظف يمكنه إرسال إشعار)

curl -X POST http://localhost:5000/api/notifications/send-to-user \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_STAFF_TOKEN" \
  -d '{
    "userId": "PATIENT_ID_HERE",
    "title": "اختبار إشعار",
    "body": "هذا إشعار تجريبي من Firebase",
    "data": {
      "type": "test",
      "timestamp": "2026-01-17"
    }
  }'
```

#### **من Backend مباشرة (Node.js):**

```javascript
// في backend directory
node -e "
const mongoose = require('mongoose');
const { sendPushNotificationToPatient } = require('./controllers/notificationController');

mongoose.connect('mongodb://localhost:27017/medical-lab').then(async () => {
  const patientId = 'PATIENT_ID_HERE'; // ضع ID المريض
  
  const sent = await sendPushNotificationToPatient(
    patientId,
    'اختبار Firebase',
    'إذا وصلك هذا الإشعار، Firebase يعمل بنجاح! 🎉',
    { type: 'test' }
  );
  
  console.log('Notification sent:', sent ? 'YES ✅' : 'NO ❌');
  mongoose.disconnect();
}).catch(console.error);
"
```

---

### **اختبار 3: إشعار نتيجة تحليل**

#### **سيناريو حقيقي:**

1. **إنشاء طلب تحليل:**
   - من Staff dashboard
   - Create new order للمريض

2. **رفع نتيجة التحليل:**
   - في Staff dashboard → Results
   - Upload result للطلب

3. **راقب الإشعار:**
   - يجب أن يصل للمريض فورًا
   - تحقق من Backend logs:

```
📱 Sending push notification to patient 677...: Test Result Available
✅ Push notification sent to patient successfully: projects/medical-lab/messages/0:xxx
```

4. **في التطبيق:**
   - يجب أن يظهر notification في notification bar
   - اضغط عليه → يفتح نتيجة التحليل

---

### **اختبار 4: التحقق من Firebase Console**

1. **اذهب إلى Firebase Console:**
   - Project → Cloud Messaging

2. **Send test message:**
   - اضغط **"Send test message"**
   - الصق FCM token من logs
   - أدخل title و body
   - اضغط **Test**

3. **يجب أن يصل الإشعار للجهاز**

---

## 🐛 **حل المشاكل الشائعة**

### **مشكلة 1: "Firebase not initialized"**

**الحل:**
```bash
cd frontend_flutter
flutter clean
flutter pub get
flutter run
```

---

### **مشكلة 2: "No FCM token found"**

**الأسباب:**
- ❌ التطبيق يعمل على Emulator (استخدم جهاز حقيقي)
- ❌ الإنترنت مقطوع
- ❌ google-services.json غير موجود

**الحل:**
```bash
# تأكد من وجود الملف:
ls frontend_flutter/android/app/google-services.json

# تأكد من Package name متطابق
grep applicationId frontend_flutter/android/app/build.gradle
```

---

### **مشكلة 3: "Firebase Admin SDK initialization failed"**

**الأسباب:**
- ❌ firebase-service-account.json غير موجود
- ❌ project_id خاطئ

**الحل:**
```bash
# تأكد من وجود الملف:
ls backend/config/firebase-service-account.json

# تحقق من project_id في الملف:
cat backend/config/firebase-service-account.json | grep project_id
```

---

### **مشكلة 4: "SIMULATED mode - not sending"**

**السبب:** Backend لم يجد firebase-service-account.json

**الحل:**
1. ضع الملف في المكان الصحيح
2. أعد تشغيل Backend:
```bash
cd backend
npm start
```

3. يجب أن ترى:
```
✅ Firebase Admin SDK initialized successfully
📱 Push notifications are now enabled
```

---

## 📊 **مقارنة: قبل وبعد Firebase**

### **قبل Firebase (SIMULATED):**
```
📱 SIMULATED: Would send push notification
📱 DEBUG: Push notification not sent (Firebase not available or no token)
```

### **بعد Firebase (REAL):**
```
📱 FCM Token: eyJhbGciOiJFUzI1NiIs...
📱 Sending push notification to patient 677...: Test Result Available
✅ Push notification sent to patient successfully: projects/medical-lab/messages/0:1234567890
```

---

## ✅ **Checklist النهائي**

- [ ] **1. Firebase Project created**
- [ ] **2. Android app added to Firebase**
- [ ] **3. google-services.json downloaded and placed**
- [ ] **4. Service account JSON downloaded and placed**
- [ ] **5. Backend restarted with Firebase enabled**
- [ ] **6. Flutter app running on real device**
- [ ] **7. User logged in and FCM token registered**
- [ ] **8. Test notification sent successfully**
- [ ] **9. Real test result notification works**

---

## 🎯 **الخطوات التالية بعد النجاح**

1. ✅ تفعيل الإشعارات لجميع أنواع الأحداث
2. ✅ إضافة notification badges
3. ✅ إضافة notification history screen
4. ✅ إضافة notification preferences للمستخدمين
5. ✅ إضافة notification sounds مخصصة

---

**🎉 بالتوفيق! إذا احتجت مساعدة في أي خطوة، أخبرني.**
