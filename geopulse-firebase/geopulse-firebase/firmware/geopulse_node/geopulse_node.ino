// GeoPulse soil and motion monitor (ESP32 -> Wi-Fi -> Firebase Realtime Database)
//
// ADXL345: VCC -> 3V3, GND -> GND, SDA -> GPIO21, SCL -> GPIO22,
//          CS -> 3V3 (I2C), SDO -> GND (address 0x53).
// Soil module: AO -> GPIO34, GND -> GND, VCC -> 3V3.
// Serial Monitor: 115200 baud. Type r and press Enter to reset soil min/max.
//
// How motion detection works:
//   * A dedicated FreeRTOS task reads the ADXL345 at ~100 Hz, so slow Firebase
//     uploads in loop() can never make the sensor miss a shake.
//   * A slow-moving baseline (gravity + gentle tilt) is subtracted from every
//     reading. What is left over is the "dynamic" acceleration = vibration.
//   * Tilt is measured from the baseline, so shaking does not count as tilting.
#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>
#include <math.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_ADXL345_U.h>
#include <Firebase_ESP_Client.h>
#include <time.h>
#include "secrets.h"

// ---------------------------------------------------------------- pins / paths
const int PIN_SOIL = 34;
const int PIN_ADXL_SDA = 21;
const int PIN_ADXL_SCL = 22;
const char *STATUS_PATH = "/geopulse/nodes/GP-01/status";
const char *READINGS_PATH = "/geopulse/nodes/GP-01/readings";
const char *HISTORY_PATH = "/geopulse/nodes/GP-01/history";
const char *THRESHOLDS_PATH = "/geopulse/nodes/GP-01/thresholds";

// ---------------------------------------------------------------- timing
const unsigned long UPLOAD_INTERVAL_MS = 1000;
const unsigned long SENSOR_HISTORY_INTERVAL_MS = 300000;
const unsigned long THRESHOLD_REFRESH_INTERVAL_MS = 30000;
const unsigned long ADXL_SAMPLE_INTERVAL_MS = 10;   // ~100 Hz
const unsigned long VIBRATION_MIN_GAP_MS = 100;     // max 10 counted events per second
const uint32_t VIBRATION_CONFIRM_WINDOW_SECONDS = 5;
const uint32_t VIBRATION_CONFIRM_ACTIVE_SECONDS = 3;

// Baseline smoothing: higher = baseline follows the sensor faster
// (less vibration seen, tilt reacts faster). 0.05 at 100 Hz is about 0.2 s.
const float BASELINE_ALPHA = 0.05f;

// ---------------------------------------------------------------- calibration / thresholds
// Calibration: put your own readings here.
int SOIL_DRY_RAW = 3200; // reading in the dry soil you will use = 0 %
int SOIL_WET_RAW = 1400; // reading in water or soaked soil     = 100 %
int soilWatchPercent = 70;
int soilCriticalPercent = 90;
int vibrationThresholdPerMin = 5;
float tiltThresholdDegrees = 2.0f;
// Written by loop() (Firebase thresholds) and read by the ADXL task.
volatile float vibrationDeltaM_S2 = 1.0f;

// ---------------------------------------------------------------- loop-side state
int rawMin = 4095, rawMax = 0;
unsigned long lastUploadMs = 0;
unsigned long lastHistoryUploadMs = 0;
unsigned long lastSoilReadMs = 0;
unsigned long lastThresholdRefreshMs = 0;
unsigned long lastHistoryErrorLogMs = 0;
int soilRaw = 0, soilPercent = 0;
time_t calibratedAt = 0;
char lastUploadedLevel[16] = "";
char lastHazardKind[16] = "";

// Copies of the motion state, refreshed from the ADXL task by syncMotionState().
float tiltX = 0, tiltY = 0, tiltDegrees = 0;
int vibrationPerMin = 0;
int vibrationPeakPerMin = 0;
bool sustainedVibration = false;
time_t vibrationPeakAt = 0;

// ---------------------------------------------------------------- ADXL task state
struct MotionState
{
  float tiltX;
  float tiltY;
  float tiltDegrees;
  int perMin;
  int peakPerMin;
  bool sustained;
  time_t peakAt;
};

Adafruit_ADXL345_Unified accel(12345);
bool adxlReady = false;

MotionState motionShared = {}; // written by the task, read by loop() (guarded by motionMux)
portMUX_TYPE motionMux = portMUX_INITIALIZER_UNLOCKED;
MotionState motionLocal = {};  // private to the task

float referenceX = 0, referenceY = 0, referenceZ = 0; // still position from calibration
float referencePitch = 0, referenceRoll = 0;
float baseX = 0, baseY = 0, baseZ = 0; // slow baseline
uint16_t vibrationBuckets[60] = {};
uint32_t lastBucketSecond = 0;
unsigned long lastVibrationEventMs = 0;

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ---------------------------------------------------------------- forward declarations
void connectToWiFi();
void syncClock();
void setupFirebase();
bool refreshThresholds(bool force);
bool uploadStatus(int soilValue);
bool uploadSensorReading(int soilValue);

// ---------------------------------------------------------------- motion helpers
float pitchOf(float x, float y, float z)
{
  return atan2f(x, sqrtf(y * y + z * z)) * 180.0f / PI;
}

float rollOf(float x, float y, float z)
{
  return atan2f(y, sqrtf(x * x + z * z)) * 180.0f / PI;
}

// Clears buckets for seconds that have passed, then totals the last 60 seconds.
void advanceVibrationBuckets(uint32_t currentSecond)
{
  if (currentSecond != lastBucketSecond)
  {
    uint32_t elapsed = currentSecond - lastBucketSecond;
    if (elapsed > 60)
      elapsed = 60;
    for (uint32_t i = 1; i <= elapsed; i++)
    {
      vibrationBuckets[(lastBucketSecond + i) % 60] = 0;
    }
    lastBucketSecond = currentSecond;
  }

  int total = 0;
  for (uint16_t count : vibrationBuckets)
    total += count;
  motionLocal.perMin = total;
}

bool hasSustainedVibration(uint32_t currentSecond)
{
  uint32_t activeSeconds = 0;
  for (uint32_t offset = 0;
       offset < VIBRATION_CONFIRM_WINDOW_SECONDS && offset <= currentSecond;
       offset++)
  {
    if (vibrationBuckets[(currentSecond - offset) % 60] > 0)
    {
      activeSeconds++;
    }
  }
  return activeSeconds >= VIBRATION_CONFIRM_ACTIVE_SECONDS;
}

void calibrateADXL()
{
  Serial.println("Keep the node still while calibrating ADXL345...");
  float x = 0, y = 0, z = 0;
  for (int i = 0; i < 50; i++)
  {
    sensors_event_t event;
    accel.getEvent(&event);
    x += event.acceleration.x;
    y += event.acceleration.y;
    z += event.acceleration.z;
    delay(20);
  }

  referenceX = x / 50.0f;
  referenceY = y / 50.0f;
  referenceZ = z / 50.0f;
  referencePitch = pitchOf(referenceX, referenceY, referenceZ);
  referenceRoll = rollOf(referenceX, referenceY, referenceZ);
  baseX = referenceX;
  baseY = referenceY;
  baseZ = referenceZ;

  memset(vibrationBuckets, 0, sizeof(vibrationBuckets));
  lastBucketSecond = millis() / 1000;
  calibratedAt = time(nullptr);

  memset(&motionLocal, 0, sizeof(motionLocal));
  motionLocal.peakAt = calibratedAt;
  motionShared = motionLocal;

  Serial.println("ADXL345 calibrated");
}

// One ADXL345 sample. Runs only inside adxlTask().
void sampleMotion()
{
  sensors_event_t event;
  accel.getEvent(&event);
  const float x = event.acceleration.x;
  const float y = event.acceleration.y;
  const float z = event.acceleration.z;
  const unsigned long now = millis();
  const uint32_t currentSecond = now / 1000;

  advanceVibrationBuckets(currentSecond);

  // Vibration = how far this reading is from the slow baseline, on all 3 axes.
  const float dx = x - baseX;
  const float dy = y - baseY;
  const float dz = z - baseZ;
  const float dynamic = sqrtf(dx * dx + dy * dy + dz * dz);

  baseX += BASELINE_ALPHA * dx;
  baseY += BASELINE_ALPHA * dy;
  baseZ += BASELINE_ALPHA * dz;

  if (dynamic >= vibrationDeltaM_S2 &&
      now - lastVibrationEventMs >= VIBRATION_MIN_GAP_MS)
  {
    lastVibrationEventMs = now;
    vibrationBuckets[currentSecond % 60]++;
    motionLocal.perMin++;
    if (motionLocal.perMin > motionLocal.peakPerMin)
    {
      motionLocal.peakPerMin = motionLocal.perMin;
      motionLocal.peakAt = time(nullptr);
    }
  }
  motionLocal.sustained = hasSustainedVibration(currentSecond);

  // Tilt comes from the baseline, so shaking is not mistaken for tilting.
  motionLocal.tiltX = pitchOf(baseX, baseY, baseZ) - referencePitch;
  motionLocal.tiltY = rollOf(baseX, baseY, baseZ) - referenceRoll;
  const float baseMag = sqrtf(baseX * baseX + baseY * baseY + baseZ * baseZ);
  const float refMag =
      sqrtf(referenceX * referenceX + referenceY * referenceY + referenceZ * referenceZ);
  if (baseMag > 0.01f && refMag > 0.01f)
  {
    const float dot = baseX * referenceX + baseY * referenceY + baseZ * referenceZ;
    motionLocal.tiltDegrees =
        acosf(constrain(dot / (baseMag * refMag), -1.0f, 1.0f)) * 180.0f / PI;
  }

  portENTER_CRITICAL(&motionMux);
  motionShared = motionLocal;
  portEXIT_CRITICAL(&motionMux);
}

void adxlTask(void *)
{
  for (;;)
  {
    sampleMotion();
    vTaskDelay(pdMS_TO_TICKS(ADXL_SAMPLE_INTERVAL_MS));
  }
}

// Copies the latest motion state from the task into the globals used by loop().
void syncMotionState()
{
  if (!adxlReady)
    return;

  MotionState s;
  portENTER_CRITICAL(&motionMux);
  s = motionShared;
  portEXIT_CRITICAL(&motionMux);

  tiltX = s.tiltX;
  tiltY = s.tiltY;
  tiltDegrees = s.tiltDegrees;
  vibrationPerMin = s.perMin;
  vibrationPeakPerMin = s.peakPerMin;
  sustainedVibration = s.sustained;
  vibrationPeakAt = s.peakAt;
}

// ---------------------------------------------------------------- setup / loop
void setup()
{
  Serial.begin(115200);
  analogReadResolution(12);

  Wire.begin(PIN_ADXL_SDA, PIN_ADXL_SCL);
  Wire.setClock(400000);
  adxlReady = accel.begin(0x53) || accel.begin(0x1D);
  if (adxlReady)
  {
    accel.setRange(ADXL345_RANGE_4_G);
    accel.setDataRate(ADXL345_DATARATE_100_HZ);
  }
  else
  {
    Serial.println("ADXL345 not found; check I2C wiring and address");
  }

  connectToWiFi();
  if (WiFi.status() == WL_CONNECTED)
  {
    syncClock();
    setupFirebase();
    refreshThresholds(true);
  }

  // Calibrate last, so the timestamps are valid and the node is still after setup.
  if (adxlReady)
  {
    calibrateADXL();
    xTaskCreatePinnedToCore(adxlTask, "adxl", 4096, nullptr, 2, nullptr, 1);
  }

  Serial.println("GeoPulse sensor monitor started");
}

int readSoilRaw()
{
  long sum = 0;
  for (int i = 0; i < 20; i++)
  {
    sum += analogRead(PIN_SOIL);
    delay(2);
  }
  return sum / 20;
}

void loop()
{
  const unsigned long now = millis();

  if (Serial.available() && Serial.read() == 'r')
  {
    rawMin = 4095;
    rawMax = 0;
    Serial.println("min/max reset");
  }

  syncMotionState();

  if (WiFi.status() == WL_CONNECTED &&
      now - lastThresholdRefreshMs >= THRESHOLD_REFRESH_INTERVAL_MS)
  {
    refreshThresholds(false);
  }

  if (now - lastSoilReadMs >= 1000)
  {
    lastSoilReadMs = now;
    soilRaw = readSoilRaw();
    rawMin = min(rawMin, soilRaw);
    rawMax = max(rawMax, soilRaw);
    soilPercent = constrain(map(soilRaw, SOIL_DRY_RAW, SOIL_WET_RAW, 0, 100), 0, 100);

    syncMotionState();
    const char *state = soilPercent < 30 ? "DRY" : (soilPercent < 70 ? "MOIST" : "WET");
    Serial.printf("soil raw=%4d %3d%% %-5s | tilt=%5.1f X=%5.1f Y=%5.1f | vibration=%d/min%s\n",
                  soilRaw, soilPercent, state, tiltDegrees, tiltX, tiltY, vibrationPerMin,
                  sustainedVibration ? " SUSTAINED" : "");
  }

  if (now - lastUploadMs >= UPLOAD_INTERVAL_MS)
  {
    syncMotionState();
    const bool uploaded = uploadStatus(soilPercent);
    lastUploadMs = millis();
    if (uploaded &&
        (lastHistoryUploadMs == 0 || now - lastHistoryUploadMs >= SENSOR_HISTORY_INTERVAL_MS))
    {
      syncMotionState();
      if (uploadSensorReading(soilPercent))
        lastHistoryUploadMs = now;
    }
  }

  delay(5);
}

// ---------------------------------------------------------------- Firebase / Wi-Fi
void setupFirebase()
{
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);
  Serial.println("Firebase client started");
}

void syncClock()
{
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now = time(nullptr);
  for (int attempt = 0; attempt < 20 && now < 1700000000; attempt++)
  {
    delay(500);
    now = time(nullptr);
  }
  if (now >= 1700000000)
  {
    Serial.println("Clock synchronized");
  }
  else
  {
    Serial.println("Clock sync failed; Firebase uploads need a valid timestamp");
  }
}

const char *levelForSensors(int soilValue)
{
  const int soilHighPercent =
      (soilWatchPercent + soilCriticalPercent + 1) / 2;
  int rank = 0;
  if (soilValue >= soilWatchPercent)
    rank = 1;
  if (soilValue >= soilHighPercent)
    rank = 2;
  if (soilValue >= soilCriticalPercent)
    rank = 3;
  if (adxlReady && sustainedVibration &&
      vibrationPerMin >= vibrationThresholdPerMin)
    rank = max(rank, 3);
  if (adxlReady && tiltDegrees >= tiltThresholdDegrees)
    rank = max(rank, 3);
  switch (rank)
  {
  case 3:
    return "critical";
  case 2:
    return "high";
  case 1:
    return "watch";
  default:
    return "stable";
  }
}

const char *kindForSensors(int soilValue)
{
  const bool soilTriggered = soilValue >= soilCriticalPercent;
  const bool vibrationTriggered = adxlReady && sustainedVibration &&
                                  vibrationPerMin >= vibrationThresholdPerMin;
  const bool tiltTriggered = adxlReady && tiltDegrees >= tiltThresholdDegrees;
  const bool motionTriggered = vibrationTriggered || tiltTriggered;
  if (soilTriggered && motionTriggered)
    return "combined";
  if (vibrationTriggered)
    return "earthquake";
  if (tiltTriggered)
    return "groundMovement";
  return "landslide";
}

bool refreshThresholds(bool force)
{
  const unsigned long now = millis();
  if (!force && now - lastThresholdRefreshMs < THRESHOLD_REFRESH_INTERVAL_MS)
  {
    return true;
  }
  lastThresholdRefreshMs = now;
  if (!Firebase.ready())
    return false;

  if (!Firebase.RTDB.getJSON(&fbdo, THRESHOLDS_PATH))
  {
    if (fbdo.errorReason().indexOf("path not exist") < 0)
    {
      Serial.print("Threshold read failed: ");
      Serial.println(fbdo.errorReason());
    }
    return false;
  }

  FirebaseJson &json = fbdo.jsonObject();
  FirebaseJsonData value;
  int nextSoilWatch = soilWatchPercent;
  int nextSoilCritical = soilCriticalPercent;
  int nextVibrationThreshold = vibrationThresholdPerMin;
  float nextTiltThreshold = tiltThresholdDegrees;
  float nextVibrationDelta = vibrationDeltaM_S2;

  if (json.get(value, "soilWatchPercent") && value.success)
    nextSoilWatch = value.intValue;
  if (json.get(value, "soilCriticalPercent") && value.success)
    nextSoilCritical = value.intValue;
  if (json.get(value, "vibrationPerMin") && value.success)
    nextVibrationThreshold = value.intValue;
  if (json.get(value, "tiltDegrees") && value.success)
    nextTiltThreshold = value.floatValue;
  if (json.get(value, "sensitivity") && value.success)
  {
    // Distance from the baseline in m/s^2: smaller = more sensitive.
    if (value.stringValue == "low")
      nextVibrationDelta = 1.5f;
    else if (value.stringValue == "medium")
      nextVibrationDelta = 1.0f;
    else if (value.stringValue == "high")
      nextVibrationDelta = 0.6f;
  }

  if (nextSoilWatch < 1 || nextSoilCritical > 100 ||
      nextSoilWatch >= nextSoilCritical ||
      nextVibrationThreshold < 1 || nextVibrationThreshold > 60 ||
      nextTiltThreshold < 0.1f || nextTiltThreshold > 10.0f)
  {
    Serial.println("Threshold values invalid; retaining previous settings");
    return false;
  }

  soilWatchPercent = nextSoilWatch;
  soilCriticalPercent = nextSoilCritical;
  vibrationThresholdPerMin = nextVibrationThreshold;
  tiltThresholdDegrees = nextTiltThreshold;
  vibrationDeltaM_S2 = nextVibrationDelta;
  Serial.println("Thresholds refreshed from Firebase");
  return true;
}

void addSensorFields(FirebaseJson &data, int soilValue)
{
  data.set("soil", soilValue);
  data.set("adxlReady", adxlReady);
  data.set("soilWatchPercent", soilWatchPercent);
  data.set("soilCriticalPercent", soilCriticalPercent);
  data.set("vibrationThresholdPerMin", vibrationThresholdPerMin);
  data.set("tiltThresholdDegrees", tiltThresholdDegrees);
  if (adxlReady)
  {
    data.set("tilt", tiltDegrees);
    data.set("tiltX", tiltX);
    data.set("tiltY", tiltY);
    data.set("vibration", vibrationPerMin);
    data.set("sustainedVibration", sustainedVibration);
    data.set("vibrationPeakPerMin", vibrationPeakPerMin);
    data.set("vibrationPeakAt", static_cast<double>(vibrationPeakAt) * 1000.0);
    data.set("calibratedAt", static_cast<double>(calibratedAt) * 1000.0);
  }
  data.set("rssi", WiFi.RSSI());
  data.set("ts", static_cast<double>(time(nullptr)) * 1000.0);
}

bool uploadStatus(int soilValue)
{
  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("Skipping Firebase upload: Wi-Fi disconnected");
    return false;
  }
  if (time(nullptr) < 1700000000)
  {
    Serial.println("Skipping Firebase upload: clock is not synchronized");
    return false;
  }
  if (!Firebase.ready())
  {
    Serial.println("Waiting for Firebase authentication");
    return false;
  }

  FirebaseJson status;
  status.set("nodeId", "GP-01");
  status.set("name", "GeoPulse Node GP-01");
  status.set("board", "ESP32");
  status.set("firmware", "1.1.0");
  const char *level = levelForSensors(soilValue);
  status.set("level", level);
  addSensorFields(status, soilValue);

  if (Firebase.RTDB.setJSON(&fbdo, STATUS_PATH, &status))
  {
    Serial.println("Firebase status uploaded");
    const char *currentKind = strcmp(level, "stable") == 0
                                  ? lastHazardKind
                                  : kindForSensors(soilValue);
    const bool levelChanged = strcmp(lastUploadedLevel, level) != 0;
    const bool hazardChanged = strcmp(level, "stable") != 0 &&
                               strcmp(lastHazardKind, currentKind) != 0;
    if (levelChanged || hazardChanged)
    {
      if (lastUploadedLevel[0] != '\0' || strcmp(level, "stable") != 0)
      {
        const char *eventKind = currentKind;
        FirebaseJson event;
        event.set("kind", eventKind);
        event.set("level", level);
        addSensorFields(event, soilValue);
        if (!Firebase.RTDB.pushJSON(&fbdo, HISTORY_PATH, &event))
        {
          if (lastHistoryErrorLogMs == 0 ||
              millis() - lastHistoryErrorLogMs >= 30000)
          {
            Serial.print("Alert history upload failed: ");
            Serial.println(fbdo.errorReason());
            lastHistoryErrorLogMs = millis();
          }
          return true;
        }
        if (strcmp(level, "stable") == 0)
        {
          lastHazardKind[0] = '\0';
        }
        else
        {
          strncpy(lastHazardKind, eventKind, sizeof(lastHazardKind) - 1);
          lastHazardKind[sizeof(lastHazardKind) - 1] = '\0';
        }
      }
      strncpy(lastUploadedLevel, level, sizeof(lastUploadedLevel) - 1);
      lastUploadedLevel[sizeof(lastUploadedLevel) - 1] = '\0';
    }
    return true;
  }
  else
  {
    Serial.print("Firebase upload failed: ");
    Serial.println(fbdo.errorReason());
    return false;
  }
}

bool uploadSensorReading(int soilValue)
{
  FirebaseJson reading;
  addSensorFields(reading, soilValue);
  if (Firebase.RTDB.pushJSON(&fbdo, READINGS_PATH, &reading))
  {
    Serial.println("Sensor history uploaded");
    return true;
  }
  Serial.print("Sensor history upload failed: ");
  Serial.println(fbdo.errorReason());
  return false;
}

void connectToWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  Serial.print("Connecting to Wi-Fi");
  unsigned long startedAt = millis();

  while (WiFi.status() != WL_CONNECTED &&
         millis() - startedAt < 20000)
  {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    Serial.print("\nConnected. ESP32 IP: ");
    Serial.println(WiFi.localIP());
  }
  else
  {
    Serial.println("\nWi-Fi connection failed. Check secrets.h and try again.");
  }
}