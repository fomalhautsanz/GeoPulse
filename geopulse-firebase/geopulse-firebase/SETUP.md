# GeoPulse: connect the ESP32 to the Flutter app with Firebase

Data flow: ESP32 --Wi-Fi--> Firebase Realtime Database --> Flutter app
(the app also writes thresholds back; the ESP32 reads them every ~30 s)

## 1. Firebase console (once)
1. Create a project (Google Analytics not needed).
2. Build > **Realtime Database** > Create database (pick Singapore) > start in locked mode.
3. Build > **Authentication** > Sign-in method: enable **Email/Password** and **Anonymous**.
4. Authentication > Users > **Add user**: `gp01@geopulse.test` + a password (this is the ESP32's account).
5. Realtime Database > **Rules**: paste `database.rules.json` and Publish.
   (If you use a different email for the ESP32, change it in the rules too.)
6. Note: Project settings > General > **Web API Key**, and the database URL.

## 2. Flutter app (in the `app/` folder)
```
flutter pub add firebase_core firebase_auth firebase_database
dart pub global activate flutterfire_cli
flutterfire configure        # creates lib/firebase_options.dart
```
Copy over your project (keep the folder structure):
- `lib/data/firebase_source.dart`  (new)
- `lib/data/status_repository.dart` (replaces yours; adds `useFirebase`)
- `lib/main.dart` (replaces yours; adds Firebase init + anonymous sign-in)

`useFirebase = false` in status_repository.dart brings back the sample data for demos.
Add `lib/firebase_options.dart` to .gitignore if the repo is public.

## 3. ESP32 (Arduino IDE)
1. Install libraries: "Firebase Arduino Client Library for ESP8266 and ESP32" (mobizt), "Adafruit ADXL345", "Adafruit Unified Sensor".
2. Copy `secrets.h.example` to `secrets.h` and fill it in. Never commit `secrets.h`.
3. Wire it as in the header comment of `geopulse_node.ino`, upload, open Serial Monitor (115200).
4. **Calibrate soil**: note `soil raw=` in dry air/dry soil and in a glass of water; put them in `SOIL_DRY_RAW` / `SOIL_WET_RAW`.
5. Keep the node still for the first 2 s after reset: that position becomes "0 degrees tilt".

## Database layout
```
/geopulse/nodes/GP-01/status      level, soil, tilt, tiltX, tiltY, vibration, rssi, ts
/geopulse/nodes/GP-01/history/..  one entry each time the level escalates
/geopulse/nodes/GP-01/thresholds  written by the app
```

## What is still sample data / not wired
- Sensor charts (Sensors screen), contacts, notifications list: still mock.
- Battery shows 100 (not measured); the "signal" slot shows Wi-Fi bars; siren/SMS counts are 0.
- Phone notifications only fire while the app is running. Alerts when the app is closed need Firebase Cloud Messaging plus a Cloud Function (Blaze plan), or an SMS API.
- "Vibration" is now derived from the ADXL345 (shake events per minute), not an SW-420.
