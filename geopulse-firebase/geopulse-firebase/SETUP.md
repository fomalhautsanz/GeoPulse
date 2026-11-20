# GeoPulse: connect the ESP32 to the Flutter app with Firebase

Data flow: ESP32 --Wi-Fi--> Firebase Realtime Database --> Flutter app.
The current soil-monitor sketch uploads status about every 10 seconds.

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
1. Install the "Firebase Arduino Client Library for ESP8266 and ESP32" (mobizt).
2. Copy `secrets.h.example` to `secrets.h` and fill it in. Never commit `secrets.h`.
3. Wire the soil sensor as in the header comment of `geopulse_node.ino`, upload, and open Serial Monitor at 115200 baud.
4. Confirm Wi-Fi connects, then look for `Firebase status uploaded`. Each upload writes to `/geopulse/nodes/GP-01/status`.
5. **Calibrate soil**: note `raw=` in dry soil and in soaked soil; put those readings in `SOIL_DRY_RAW` / `SOIL_WET_RAW`.

## Database layout
```
/geopulse/nodes/GP-01/status      nodeId, level, soil, tilt, vibration, rssi, ts
/geopulse/nodes/GP-01/history/..  reserved for alert history
/geopulse/nodes/GP-01/thresholds  app settings; current soil sketch does not read them
```

## What is still sample data / not wired
- The current firmware reads soil moisture only. It writes `tilt` and `vibration` as zero; the ADXL345 and other sensor readings are not implemented in this sketch.
- Threshold settings are saved by the app but are not yet read by this firmware; alert levels currently use fixed soil cutoffs.
- Sensor charts (Sensors screen), contacts, notifications list: still mock.
- Battery shows 100 (not measured); the "signal" slot shows Wi-Fi bars; siren/SMS counts are 0.
- Phone notifications only fire while the app is running. Alerts when the app is closed need Firebase Cloud Messaging plus a Cloud Function (Blaze plan), or an SMS API.
- Tilt and vibration are placeholders in the current soil-only firmware; they need sensor-reading code before they show real values.
