/*
  GeoPulse node GP-01  -  landslide alert (ESP32)

  Sensors : resistive soil probe (MH module, analog out) + ADXL345 (I2C)
  Outputs : 3 LEDs (local, works with no internet) + Firebase Realtime DB

  Libraries (Library Manager):
    - "Firebase Arduino Client Library for ESP8266 and ESP32"  (mobizt)
    - "Adafruit ADXL345"  and  "Adafruit Unified Sensor"

  Wiring
    ADXL345 : VCC->3V3  GND->GND  SDA->GPIO21  SCL->GPIO22
              CS->3V3 (I2C mode)  SDO->GND (address 0x53)
    Soil    : AO->GPIO34   GND->GND   VCC->GPIO25 (powered only while reading,
              so the probe corrodes much less)
    LEDs    : green GPIO26, yellow GPIO27, red GPIO14, each through 220 ohm to GND
    Speaker : GPIO13 -> 1k resistor -> 10uF capacitor (+ toward resistor) -> aux plug tip
              ESP32 GND -> aux plug sleeve. Power the speaker's USB from a power bank.
              (A bare 8 ohm speaker also works: GPIO13 -> 150 ohm -> speaker -> GND.)
*/
#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>
#include <math.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_ADXL345_U.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "secrets.h"

// ---------- settings you will tune ----------
const char* NODE_ID = "GP-01";

const int PIN_SOIL = 34, PIN_SOIL_PWR = 25;
const int PIN_LED_G = 26, PIN_LED_Y = 27, PIN_LED_R = 14;
const int PIN_SPK = 13;

// Soil calibration: read the raw value in dry air/dry soil and in a glass of
// water (see the Serial Monitor), then put the numbers here.
int SOIL_DRY_RAW = 3200;   // 0 %
int SOIL_WET_RAW = 1400;   // 100 %

// Defaults; the app can change these (Settings > Thresholds) every ~30 s.
int   soilWatch = 70, soilCritical = 90;
float tiltLimit = 2.0;      // degrees away from the position at power-on
int   vibLimit  = 5;        // shake events per minute
bool  sirenEnabled = true;  // the app's siren switch mutes the speaker
const float VIB_DELTA = 1.5;      // m/s^2 jump between readings = 1 event
const int   TILT_HOLD_SECONDS = 3; // tilt must last this long (ignores bumps)
// --------------------------------------------

enum Level { LV_STABLE, LV_WATCH, LV_HIGH, LV_CRITICAL };
const char* LEVEL_NAME[] = {"stable", "watch", "high", "critical"};

Adafruit_ADXL345_Unified accel(12345);
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

float refX, refY, refZ, refPitch, refRoll;   // position at power-on
float sumX, sumY, sumZ; int sumN = 0;
float lastMag = 0;
uint16_t vibBucket[60]; uint32_t bucketSec = 0;
int tiltHold = 0;

int   soilPct = 0, vibPerMin = 0;
float tiltDeg = 0, tiltX = 0, tiltY = 0;
Level level = LV_STABLE, lastSentLevel = LV_STABLE;
bool  historyPending = false;

uint32_t tRead = 0, tEval = 0, tSend = 0, tThr = 0;
String base() { return String("/geopulse/nodes/") + NODE_ID; }

float pitchOf(float x, float y, float z) { return atan2(x, sqrt(y * y + z * z)) * 180.0 / PI; }
float rollOf (float x, float y, float z) { return atan2(y, sqrt(x * x + z * z)) * 180.0 / PI; }

void calibrateTilt() {
  float x = 0, y = 0, z = 0;
  for (int i = 0; i < 50; i++) {
    sensors_event_t e; accel.getEvent(&e);
    x += e.acceleration.x; y += e.acceleration.y; z += e.acceleration.z;
    delay(20);
  }
  refX = x / 50; refY = y / 50; refZ = z / 50;
  refPitch = pitchOf(refX, refY, refZ);
  refRoll  = rollOf(refX, refY, refZ);
  lastMag = sqrt(refX * refX + refY * refY + refZ * refZ);
}

int readSoilPercent() {
  digitalWrite(PIN_SOIL_PWR, HIGH);
  delay(30);
  long s = 0;
  for (int i = 0; i < 10; i++) { s += analogRead(PIN_SOIL); delay(2); }
  digitalWrite(PIN_SOIL_PWR, LOW);
  int raw = s / 10;
  Serial.printf("soil raw=%d\n", raw);          // use this to calibrate
  int pct = map(raw, SOIL_DRY_RAW, SOIL_WET_RAW, 0, 100);
  return constrain(pct, 0, 100);
}

void bucketsTick() {
  uint32_t s = millis() / 1000;
  if (s == bucketSec) return;
  for (uint32_t t = bucketSec + 1; t <= s && t <= bucketSec + 60; t++) vibBucket[t % 60] = 0;
  bucketSec = s;
}

void readAccel() {                       // every 100 ms
  sensors_event_t e; accel.getEvent(&e);
  float x = e.acceleration.x, y = e.acceleration.y, z = e.acceleration.z;
  sumX += x; sumY += y; sumZ += z; sumN++;
  float mag = sqrt(x * x + y * y + z * z);
  bucketsTick();
  if (fabs(mag - lastMag) > VIB_DELTA) vibBucket[bucketSec % 60]++;
  lastMag = mag;
}

void evaluate() {                        // every 1 s
  // tilt = angle between the average reading and the power-on position
  if (sumN > 0) {
    float x = sumX / sumN, y = sumY / sumN, z = sumZ / sumN;
    sumX = sumY = sumZ = 0; sumN = 0;
    float dot = x * refX + y * refY + z * refZ;
    float m1 = sqrt(x * x + y * y + z * z), m2 = sqrt(refX * refX + refY * refY + refZ * refZ);
    tiltDeg = acos(constrain(dot / (m1 * m2), -1.0f, 1.0f)) * 180.0 / PI;
    tiltX = pitchOf(x, y, z) - refPitch;
    tiltY = rollOf(x, y, z) - refRoll;
  }
  tiltHold = (tiltDeg >= tiltLimit) ? tiltHold + 1 : 0;

  bucketsTick();
  vibPerMin = 0;
  for (int i = 0; i < 60; i++) vibPerMin += vibBucket[i];

  soilPct = readSoilPercent();

  int soilHigh = soilWatch + (soilCritical - soilWatch) / 2;
  Level lv = LV_STABLE;
  if (soilPct >= soilCritical) lv = LV_CRITICAL;
  else if (soilPct >= soilHigh) lv = LV_HIGH;
  else if (soilPct >= soilWatch) lv = LV_WATCH;

  bool moving = (tiltHold >= TILT_HOLD_SECONDS) || (vibPerMin >= vibLimit);
  if (moving) lv = (soilPct >= soilWatch) ? LV_CRITICAL : (lv > LV_HIGH ? lv : LV_HIGH);

  if (lv > level && lv >= LV_WATCH) historyPending = true;   // log escalations
  level = lv;

  digitalWrite(PIN_LED_G, level == LV_STABLE);
  digitalWrite(PIN_LED_Y, level == LV_WATCH || level == LV_HIGH);
  digitalWrite(PIN_LED_R, level == LV_CRITICAL || level == LV_HIGH);

  Serial.printf("soil=%d%% tilt=%.1f vib=%d/min level=%s\n",
                soilPct, tiltDeg, vibPerMin, LEVEL_NAME[level]);
}

// Speaker: no delay(), so sensors and Firebase keep running while it sounds.
// Critical = siren sweep, High = beeps, Stable/Watch = silent.
void updateSound() {
  static uint32_t last = 0;
  uint32_t t = millis();
  if (t - last < 20) return;
  last = t;
  if (!sirenEnabled) { noTone(PIN_SPK); return; }
  if (level == LV_CRITICAL)  tone(PIN_SPK, 800 + (t / 3) % 1000);
  else if (level == LV_HIGH) { if (t % 1000 < 200) tone(PIN_SPK, 1800); else noTone(PIN_SPK); }
  else noTone(PIN_SPK);
}

void startupBeep() {                      // three rising notes = speaker works
  int notes[] = {523, 659, 784};
  for (int i = 0; i < 3; i++) { tone(PIN_SPK, notes[i]); delay(120); }
  noTone(PIN_SPK);
}

void fillJson(FirebaseJson& j) {
  j.set("nodeId", NODE_ID);
  j.set("level", LEVEL_NAME[level]);
  j.set("soil", soilPct);
  j.set("tilt", tiltDeg);
  j.set("tiltX", tiltX);
  j.set("tiltY", tiltY);
  j.set("vibration", vibPerMin);
  j.set("rssi", WiFi.RSSI());
  j.set("ts/.sv", "timestamp");          // server time, so no clock needed
}

void sendToFirebase() {
  FirebaseJson j; fillJson(j);
  if (!Firebase.RTDB.setJSON(&fbdo, (base() + "/status").c_str(), &j))
    Serial.println(fbdo.errorReason());
  if (historyPending) {
    FirebaseJson h; fillJson(h); h.set("kind", "landslide");
    if (Firebase.RTDB.pushJSON(&fbdo, (base() + "/history").c_str(), &h)) historyPending = false;
  }
}

void fetchThresholds() {
  String p = base() + "/thresholds/";
  if (Firebase.RTDB.getInt(&fbdo,   (p + "soilWatchPercent").c_str()))    soilWatch    = fbdo.intData();
  if (Firebase.RTDB.getInt(&fbdo,   (p + "soilCriticalPercent").c_str())) soilCritical = fbdo.intData();
  if (Firebase.RTDB.getInt(&fbdo,   (p + "vibrationPerMin").c_str()))     vibLimit     = fbdo.intData();
  if (Firebase.RTDB.getFloat(&fbdo, (p + "tiltDegrees").c_str()))         tiltLimit    = fbdo.floatData();
  if (Firebase.RTDB.getBool(&fbdo,  (p + "sirenEnabled").c_str()))        sirenEnabled = fbdo.boolData();
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_SOIL_PWR, OUTPUT); digitalWrite(PIN_SOIL_PWR, LOW);
  pinMode(PIN_LED_G, OUTPUT); pinMode(PIN_LED_Y, OUTPUT); pinMode(PIN_LED_R, OUTPUT);
  analogReadResolution(12);
  pinMode(PIN_SPK, OUTPUT);
  startupBeep();

  Wire.begin(21, 22);
  if (!accel.begin(0x53)) {
    Serial.println("ADXL345 not found - check wiring");
    while (true) { digitalWrite(PIN_LED_R, !digitalRead(PIN_LED_R)); delay(200); }
  }
  accel.setRange(ADXL345_RANGE_4_G);
  Serial.println("Keep the node still: calibrating tilt...");
  calibrateTilt();

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  for (int i = 0; i < 20 && WiFi.status() != WL_CONNECTED; i++) delay(500);

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;
  Firebase.reconnectNetwork(true);
  Firebase.begin(&config, &auth);
}

void loop() {
  uint32_t now = millis();
  if (now - tRead >= 100)  { tRead = now; readAccel(); }
  if (now - tEval >= 1000) { tEval = now; evaluate(); }   // LEDs work offline
  updateSound();                                          // speaker works offline too

  bool online = WiFi.status() == WL_CONNECTED && Firebase.ready();
  if (online && now - tSend >= 3000)  { tSend = now; sendToFirebase(); }
  if (online && now - tThr >= 30000)  { tThr = now;  fetchThresholds(); }
}