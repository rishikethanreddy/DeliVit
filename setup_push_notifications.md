# Setting Up Push Notifications

Implementing real push notifications requires setting up a backend trigger (Supabase Edge Functions) and a notification provider (Firebase Cloud Messaging - FCM). Since I cannot access your external accounts, please follow this guide.

## Prerequisites
1.  **Google Account** for Firebase.
2.  **Supabase Project** with Edge Functions enabled.
3.  **Flutter Project** configured.

## Step 1: Firebase Setup
1.  Go to [Firebase Console](https://console.firebase.google.com/).
2.  Create a new project.
3.  Add an Android app:
    - Package name: `com.example.vitpick` (check your `android/app/build.gradle`).
    - Download `google-services.json` and place it in `android/app/`.
4.  Add an iOS app (if needed):
    - Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
5.  Go to **Project Settings > Cloud Messaging**.
6.  Copy the **Server Key** (legacy) or enable **Firebase Cloud Messaging API (V1)** and get the service account JSON.

## Step 2: Supabase Edge Function
We need a function that triggers when a new message is inserted.

1.  **Initialize Supabase in your project**:
    ```bash
    supabase init
    ```
2.  **Create a Function**:
    ```bash
    supabase functions new push-notification
    ```
3.  **Edit the Function** (`supabase/functions/push-notification/index.ts`):
    (You will need to write TypeScript code to listen to the webhook or use Database Webhooks).
    
    *Simpler Approach*: Use Supabase Database Webhooks.
    
    - Go to Supabase Dashboard > **Database** > **Webhooks**.
    - Create a webhook "on_message_insert".
    - Table: `messages`.
    - Events: `INSERT`.
    - Type: HTTP Request.
    - URL: Your Edge Function URL.

4.  **Edge Function Code (Concept)**:
    ```typescript
    // Import FCM library
    serve(async (req) => {
      const { record } = await req.json()
      const receiverId = record.receiver_id
      
      // Fetch receiver's FCM token from 'profiles' table (You need to add a 'fcm_token' column to profiles)
      const { data: user } = await supabase.from('profiles').select('fcm_token').eq('id', receiverId).single()
      
      if (user?.fcm_token) {
        // Send to FCM
        await sendToFCM(user.fcm_token, {
          title: 'New Message',
          body: record.content,
        })
      }
    })
    ```

## Step 3: Flutter App Changes
1.  **Add Dependencies**:
    ```yaml
    firebase_core: latest
    firebase_messaging: latest
    ```
2.  **Initialize Firebase** in `main.dart`.
3.  **Request Permission**:
    ```dart
    FirebaseMessaging.instance.requestPermission();
    ```
4.  **Get & Save Token**:
    ```dart
    final token = await FirebaseMessaging.instance.getToken();
    // Save this token to 'profiles' table in Supabase
    ```

> [!NOTE]
> This is a complex setup involving external services. For now, the **In-App Red Badge** I implemented serves as a notification while the app is open.
