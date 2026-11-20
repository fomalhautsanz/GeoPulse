# GeoPulse Firebase setup

Data flow: ESP32 → Wi-Fi → Firebase Realtime Database → Flutter app.

## Firebase

1. Create a Firebase project and a Realtime Database in locked mode.
2. Enable **Email/Password** and **Anonymous** sign-in in Authentication.
3. Create an Email/Password account for the ESP32 and put its credentials in
   `firmware/geopulse_node/secrets.h` (copy `secrets.h.example`). Do not commit
   that file.
4. Configure the Flutter app with `flutterfire configure`.
5. Publish `database.rules.json` in Realtime Database → Rules. Change the
   device email in the rules if it differs from `gp01@geopulse.test`.

The Flutter app signs into Firebase anonymously for database access. This is
separate from the app's profile/login flow, which is unchanged.

## ESP32

1. Install the Arduino libraries **Firebase Arduino Client Library for
   ESP8266 and ESP32**, **Adafruit ADXL345**, and **Adafruit Unified Sensor**.
2. Wire ADXL345 VCC to 3V3, GND to GND, SDA to GPIO21, SCL to GPIO22, CS to 3V3,
   and SDO to GND (I²C address `0x53`). Wire soil AO to GPIO34.
3. Set `SOIL_DRY_RAW` and `SOIL_WET_RAW` in the sketch using readings from the
   actual probe in dry and saturated soil.
4. Upload the sketch and open Serial Monitor at 115200 baud. Keep the node
   still during ADXL345 calibration.

The node sends live status every second and chart readings every five minutes.
It reads saved thresholds from Firebase every 30 seconds and records each
alert-level or hazard-kind transition in `/geopulse/nodes/GP-01/history`.
An earthquake alert requires vibration events in at least three different
seconds within a five-second window, as well as the configured events-per-minute
threshold. Tilt can raise a ground-movement alert but does not by itself count
as an earthquake. Keep the node fixed and still during startup calibration.

## Database paths

```text
/geopulse/nodes/GP-01/status       current readings and node metadata
/geopulse/nodes/GP-01/readings     timestamped chart samples
/geopulse/nodes/GP-01/history      actual alert-level transitions
/geopulse/nodes/GP-01/thresholds   settings saved by the app and read by the node
/geopulse/nodes/GP-01/contacts     optional stored contact records
/geopulse/nodes/GP-01/notifications app notification records
/geopulse/users/{uid}/notificationPrefs per-user app notification settings
```

## Current hardware and service limits

- Soil readings come from the analog probe. Tilt and vibration are available
  only when `adxlReady` is true; otherwise the app shows them as unavailable.
- Battery level, siren/buzzer, LEDs/OLED, GSM, and SMS are not implemented by
  this firmware. The app does not simulate their readings or actions. Stored
  contacts are informational and are not sent SMS.
- Phone notifications are recorded and shown while the app is connected.
  Delivery when the app is closed needs Firebase Cloud Messaging and a server
  trigger; this project does not currently have that service.
- The app's profile/login flow is unchanged by the removal of demo sensor and
  service data.
