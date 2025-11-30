# Firebase Integration Guide

## Setup Firebase Project

1. Tạo Firebase project tại: https://console.firebase.google.com
2. Thêm Flutter app (Android/iOS/Web)
3. Tải file `google-services.json` (Android) và `GoogleService-Info.plist` (iOS)

## Features sử dụng Firebase

### 1. **Firestore Database**
- Lưu lịch sử cảm biến
- Logs sự kiện security
- User settings

### 2. **Firebase Authentication**
- Email/Password login
- Google Sign-In

### 3. **Cloud Messaging (FCM)**
- Push notification khi intruder detected
- Alerts khi temperature > threshold

## Collections Structure

```
/users/{userId}
  - email: string
  - displayName: string
  - createdAt: timestamp

/sensor_logs/{logId}
  - temperature: number
  - humidity: number
  - distance: number
  - pirActive: boolean
  - timestamp: timestamp
  - userId: string

/security_events/{eventId}
  - type: string (intruder/door/fan)
  - message: string
  - timestamp: timestamp
  - userId: string

/device_states/{userId}
  - led2: boolean
  - fan: boolean
  - door: boolean
  - securityMode: boolean
  - lastUpdate: timestamp
```

## Next Steps

1. Run: `cd FlutterApp && flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging`
2. Follow Firebase setup wizard
3. Update server to push data to Firestore
