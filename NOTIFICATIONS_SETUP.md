# Notification setup (one-time, platform folders)

Run `flutter create .` first so `android/` and `ios/` exist. Needs Flutter >= 3.38.1.

## Android

1. `android/app/src/main/AndroidManifest.xml`
   - Before `<application ...>`:

         <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
         <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
         <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

   - Inside `<application ...>` (next to the existing `<activity>`):

         <receiver android:exported="false"
             android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
         <receiver android:exported="false"
             android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
           <intent-filter>
             <action android:name="android.intent.action.BOOT_COMPLETED"/>
             <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
             <action android:name="android.intent.action.QUICKBOOT_POWERON" />
             <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
           </intent-filter>
         </receiver>

2. `android/app/build.gradle.kts` (Groovy `build.gradle`: same idea):

       android {
           compileOptions {
               isCoreLibraryDesugaringEnabled = true
               sourceCompatibility = JavaVersion.VERSION_17
               targetCompatibility = JavaVersion.VERSION_17
           }
       }
       dependencies {
           coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")  // or newer
       }

   Also set `jvmTarget = "17"` under `kotlinOptions` / `compilerOptions` if present.

## iOS

In `ios/Runner/AppDelegate.swift`, inside `application(_:didFinishLaunchingWithOptions:)`,
before the `return`:

    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate

(If you use the UIScene lifecycle, follow the plugin README's UIScene note.)

## Notes
- Permission is requested the first time you set a reminder.
- Android without the exact-alarm permission still works, but reminders may arrive a few minutes late.
- iOS keeps at most 64 pending notifications; the app schedules the soonest 60.
- Reminders do not work on a plain desktop/web run; the app falls back to a no-op scheduler.
- If the plugin's API changed again, the only file to adjust is
  `features/tasks/data/local_notification_scheduler.dart`.

## How reminders are scheduled
- Task reminders, habit reminders and the focus timer alarm share one notification plugin.
- Habit reminders are one-off notifications planned for the next ~2 weeks (soonest 24),
  skipping days already completed. They are re-planned on every change and each time the
  app comes to the foreground, so open the app now and then to keep them coming.
- iOS allows 64 pending notifications: 36 for tasks, 24 for habits, 1 for the focus alarm.

## Task and subtask reminders
A task can have several reminders and each subtask can have its own. They share the task budget
(36 pending notifications on iOS, soonest first) and are re-planned on every change and whenever
the app returns to the foreground.

## Home-screen shortcuts
Long-press the app icon for "New task", "New habit" and "Start focus" (Android 7.1+ and iOS).
They are registered each time the app starts. No manifest changes are needed. On web and desktop
the shortcuts are simply skipped. Android launchers may need a moment to show new shortcuts
after the first install.
