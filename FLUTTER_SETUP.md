# Flutter setup (safe to keep beside generated files)

This repository is a hand-authored `lib/`, `test/`, documentation, and dependency starter. If `flutter create` warns that a README will be overwritten, copy the root README and this file elsewhere first and restore them afterward.

```bash
flutter create --platforms=android,ios --project-name pocketcode .
flutter pub get
flutter run
```

The source targets Flutter >=3.27 / Dart >=3.6. Add Android `<uses-permission android:name="android.permission.INTERNET" />` under `<manifest>`. For explicitly enabled local HTTP, use `android:usesCleartextTraffic="true"` only in development and enable PocketCode's **Allow insecure HTTP** switch. On iOS, use a scoped localhost `NSAppTransportSecurity` exception in `Info.plist`, never a global ATS bypass; a phone's `localhost` is the phone, not the development computer.

See README.md for security, protocol, persistence, and testing details.
