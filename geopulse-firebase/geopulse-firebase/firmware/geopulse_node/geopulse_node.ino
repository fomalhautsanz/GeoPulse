// GeoPulse soil monitor (ESP32 -> Wi-Fi -> Firebase Realtime Database)
//
// Wiring: soil module AO -> GPIO34, GND -> GND, VCC -> 3V3.
// To power the probe only while reading, wire VCC -> GPIO25 and set
// USE_POWER_PIN to true.
//
// Serial Monitor: 115200 baud. Type r and press Enter to reset min/max.
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <time.h>
#include "secrets.h"

const int  PIN_SOIL      = 34;
const int  PIN_SOIL_PWR  = 25;
const bool USE_POWER_PIN = false;
const char* STATUS_PATH = "/geopulse/nodes/GP-01/status";
const unsigned long UPLOAD_INTERVAL_MS = 10000;

// Calibration: put your own readings here (see the steps in the chat).
int SOIL_DRY_RAW = 3200;   // reading in the dry soil you will use = 0 %
int SOIL_WET_RAW = 1400;   // reading in water or soaked soil     = 100 %

int rawMin = 4095, rawMax = 0;
unsigned long lastUploadMs = 0;
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

void setup() {
  Serial.begin(115200);
  connectToWiFi();
  if (WiFi.status() == WL_CONNECTED) {
    syncClock();
    setupFirebase();
  }
  analogReadResolution(12);
  if (USE_POWER_PIN) {
    pinMode(PIN_SOIL_PWR, OUTPUT);
    digitalWrite(PIN_SOIL_PWR, LOW);
  }
  Serial.println("Soil test started");
}

int readRaw() {
  if (USE_POWER_PIN) { digitalWrite(PIN_SOIL_PWR, HIGH); delay(30); }
  long sum = 0;
  for (int i = 0; i < 20; i++) { sum += analogRead(PIN_SOIL); delay(2); }
  if (USE_POWER_PIN) digitalWrite(PIN_SOIL_PWR, LOW);
  return sum / 20;
}

void loop() {
  if (Serial.available() && Serial.read() == 'r') {
    rawMin = 4095; rawMax = 0;
    Serial.println("min/max reset");
  }

  int raw = readRaw();
  rawMin = min(rawMin, raw);
  rawMax = max(rawMax, raw);

  int pct = constrain(map(raw, SOIL_DRY_RAW, SOIL_WET_RAW, 0, 100), 0, 100);
  const char* state = pct < 30 ? "DRY" : (pct < 70 ? "MOIST" : "WET");

  Serial.printf("raw=%4d  soil=%3d%%  %-5s  (min %d, max %d)\n",
                raw, pct, state, rawMin, rawMax);

  if (millis() - lastUploadMs >= UPLOAD_INTERVAL_MS) {
    uploadStatus(pct);
    lastUploadMs = millis();
  }

  delay(1000);
}

void setupFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);
  Serial.println("Firebase client started");
}

void syncClock() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now = time(nullptr);
  for (int attempt = 0; attempt < 20 && now < 1700000000; attempt++) {
    delay(500);
    now = time(nullptr);
  }
  if (now >= 1700000000) {
    Serial.println("Clock synchronized");
  } else {
    Serial.println("Clock sync failed; Firebase uploads need a valid timestamp");
  }
}

const char* levelForSoil(int soilPercent) {
  if (soilPercent >= 90) return "critical";
  if (soilPercent >= 80) return "high";
  if (soilPercent >= 70) return "watch";
  return "stable";
}

void uploadStatus(int soilPercent) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Skipping Firebase upload: Wi-Fi disconnected");
    return;
  }
  if (time(nullptr) < 1700000000) {
    Serial.println("Skipping Firebase upload: clock is not synchronized");
    return;
  }
  if (!Firebase.ready()) {
    Serial.println("Waiting for Firebase authentication");
    return;
  }

  FirebaseJson status;
  status.set("nodeId", "GP-01");
  status.set("level", levelForSoil(soilPercent));
  status.set("soil", soilPercent);
  status.set("tilt", 0);
  status.set("vibration", 0);
  status.set("rssi", WiFi.RSSI());
  status.set("ts", static_cast<double>(time(nullptr)) * 1000.0);

  if (Firebase.RTDB.setJSON(&fbdo, STATUS_PATH, &status)) {
    Serial.println("Firebase status uploaded");
  } else {
    Serial.print("Firebase upload failed: ");
    Serial.println(fbdo.errorReason());
  }
}

void connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  Serial.print("Connecting to Wi-Fi");
  unsigned long startedAt = millis();

  while (WiFi.status() != WL_CONNECTED &&
         millis() - startedAt < 20000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\nConnected. ESP32 IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWi-Fi connection failed. Check secrets.h and try again.");
  }
}