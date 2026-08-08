/*
  Alpha Community - ESP32 2: Flood + Landslide Sensors

  Wiring:
    Rain AO -> GPIO 34
    Rain DO -> GPIO 14
    Water level signal -> GPIO 35
    Soil moisture AO -> GPIO 32
    Soil moisture DO -> GPIO 13
    Vibration DO -> GPIO 12
    Vibration AO -> GPIO 33
    MPU6050 SDA -> GPIO 21
    MPU6050 SCL -> GPIO 22
    Red LED -> GPIO 25
    Yellow LED -> GPIO 26
    Green LED -> GPIO 27
    Buzzer -> GPIO 23

  Uploads to Firestore:
    collection: alpha_iot_environment
    document:   ESP32-ENV-001
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <math.h>
#include <time.h>

const char* WIFI_SSID = "SLT-Fiber-2.4G_5b00";
const char* WIFI_PASSWORD = "Dildev@200108300848";

const char* FIREBASE_PROJECT_ID = "alpha-community-95a5c";
const char* FIREBASE_API_KEY = "AIzaSyA8FMQb8HWOBFXoMoIDWXa1eDUuxhjhqqM";

const char* DEVICE_ID = "ESP32-ENV-001";
const char* AREA_LABEL = "Flood and landslide station";

const int RAIN_AO_PIN = 34;
const int RAIN_DO_PIN = 14;
const int WATER_LEVEL_PIN = 35;
const int SOIL_AO_PIN = 32;
const int SOIL_DO_PIN = 13;
const int VIBRATION_DO_PIN = 12;
const int VIBRATION_AO_PIN = 33;

const int RED_LED_PIN = 25;
const int YELLOW_LED_PIN = 26;
const int GREEN_LED_PIN = 27;
const int BUZZER_PIN = 23;

const byte MPU6050_ADDR = 0x68;

String nowIso() {
  struct tm timeInfo;
  if (!getLocalTime(&timeInfo)) {
    return "1970-01-01T00:00:00";
  }
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeInfo);
  return String(buffer);
}

void setupMpu6050() {
  Wire.begin(21, 22);
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B);
  Wire.write(0);
  Wire.endTransmission(true);
}

float readTiltMagnitude() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return 0.0;
  Wire.requestFrom(MPU6050_ADDR, (byte)6, true);
  if (Wire.available() < 6) return 0.0;

  int16_t ax = Wire.read() << 8 | Wire.read();
  int16_t ay = Wire.read() << 8 | Wire.read();
  int16_t az = Wire.read() << 8 | Wire.read();

  float x = ax / 16384.0;
  float y = ay / 16384.0;
  float z = az / 16384.0;
  float flatness = fabs(z);
  float sideTilt = sqrt(x * x + y * y);
  return constrain(sideTilt / max(flatness, 0.1f), 0.0f, 1.0f);
}

String firestoreUrl() {
  return String("https://firestore.googleapis.com/v1/projects/") +
         FIREBASE_PROJECT_ID +
         "/databases/(default)/documents/alpha_iot_environment/" +
         DEVICE_ID +
         "?key=" +
         FIREBASE_API_KEY;
}

String riskLabel(int rainAnalog, int waterRaw, int soilRaw, bool vibration, float tilt) {
  float rainWetness = (4095.0 - rainAnalog) / 4095.0;
  float water = waterRaw / 4095.0;
  float soilWetness = (4095.0 - soilRaw) / 4095.0;
  float score = rainWetness * 0.25 + water * 0.25 + soilWetness * 0.25 + tilt * 0.15 + (vibration ? 0.10 : 0.0);
  if (score >= 0.70) return "high";
  if (score >= 0.40) return "medium";
  return "low";
}

void setOutputs(String risk) {
  digitalWrite(RED_LED_PIN, risk == "high" ? HIGH : LOW);
  digitalWrite(YELLOW_LED_PIN, risk == "medium" ? HIGH : LOW);
  digitalWrite(GREEN_LED_PIN, risk == "low" ? HIGH : LOW);
  digitalWrite(BUZZER_PIN, risk == "high" ? HIGH : LOW);
}

void uploadReading(
  int rainAnalog,
  bool rainDigital,
  int waterLevelRaw,
  int soilMoistureRaw,
  bool soilDigital,
  bool vibrationDigital,
  int vibrationAnalog,
  float tiltMagnitude,
  String risk
) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi not connected. Skipping upload.");
    return;
  }

  StaticJsonDocument<1536> doc;
  JsonObject fields = doc.createNestedObject("fields");
  fields["deviceId"]["stringValue"] = DEVICE_ID;
  fields["areaLabel"]["stringValue"] = AREA_LABEL;
  fields["rainAnalog"]["integerValue"] = rainAnalog;
  fields["rainDigital"]["booleanValue"] = rainDigital;
  fields["waterLevelRaw"]["integerValue"] = waterLevelRaw;
  fields["soilMoistureRaw"]["integerValue"] = soilMoistureRaw;
  fields["soilDigital"]["booleanValue"] = soilDigital;
  fields["vibrationDigital"]["booleanValue"] = vibrationDigital;
  fields["vibrationAnalog"]["integerValue"] = vibrationAnalog;
  fields["tiltMagnitude"]["doubleValue"] = tiltMagnitude;
  fields["risk"]["stringValue"] = risk;
  fields["updatedAt"]["stringValue"] = nowIso();

  String body;
  serializeJson(doc, body);

  HTTPClient http;
  http.begin(firestoreUrl());
  http.addHeader("Content-Type", "application/json");
  int code = http.PATCH(body);
  Serial.print("Firestore response: ");
  Serial.println(code);
  Serial.println(http.getString());
  http.end();
}

void connectWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Connected IP: ");
  Serial.println(WiFi.localIP());
  configTime(0, 0, "pool.ntp.org", "time.google.com");
}

void setup() {
  Serial.begin(115200);

  pinMode(RAIN_DO_PIN, INPUT);
  pinMode(SOIL_DO_PIN, INPUT);
  pinMode(VIBRATION_DO_PIN, INPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  setupMpu6050();
  connectWifi();
}

void loop() {
  int rainAnalog = analogRead(RAIN_AO_PIN);
  bool rainDigital = digitalRead(RAIN_DO_PIN) == HIGH;
  int waterLevelRaw = analogRead(WATER_LEVEL_PIN);
  int soilMoistureRaw = analogRead(SOIL_AO_PIN);
  bool soilDigital = digitalRead(SOIL_DO_PIN) == HIGH;
  bool vibrationDigital = digitalRead(VIBRATION_DO_PIN) == HIGH;
  int vibrationAnalog = analogRead(VIBRATION_AO_PIN);
  float tiltMagnitude = readTiltMagnitude();
  String risk = riskLabel(rainAnalog, waterLevelRaw, soilMoistureRaw, vibrationDigital, tiltMagnitude);

  setOutputs(risk);
  uploadReading(
    rainAnalog,
    rainDigital,
    waterLevelRaw,
    soilMoistureRaw,
    soilDigital,
    vibrationDigital,
    vibrationAnalog,
    tiltMagnitude,
    risk
  );

  Serial.print("Rain AO: "); Serial.print(rainAnalog);
  Serial.print(" Water: "); Serial.print(waterLevelRaw);
  Serial.print(" Soil: "); Serial.print(soilMoistureRaw);
  Serial.print(" Vibration: "); Serial.print(vibrationDigital);
  Serial.print(" Tilt: "); Serial.print(tiltMagnitude);
  Serial.print(" Risk: "); Serial.println(risk);

  delay(15000);
}
