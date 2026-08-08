/*
  Alfa Community - Smart Garbage Bin IoT Prototype

  Board: ESP32
  Sensors:
    - HC-SR04 ultrasonic sensor for bin fill percentage
    - HX711 + load cell for current bin weight

  Cloud:
    - Uploads JSON data to Firebase Firestore using the Firebase REST API.

  Before uploading to the board, replace:
    WIFI_SSID, WIFI_PASSWORD, FIREBASE_PROJECT_ID, FIREBASE_API_KEY
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "HX711.h"

const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* FIREBASE_PROJECT_ID = "alpha-community-95a5c";
const char* FIREBASE_API_KEY = "YOUR_FIREBASE_WEB_API_KEY";

const char* BIN_ID = "BIN-KANDY-001";
const char* AREA_LABEL = "Kandy community smart bin";

const float LATITUDE = 7.2906;
const float LONGITUDE = 80.6337;
const float EMPTY_BIN_DEPTH_CM = 100.0;
const float BIN_CAPACITY_KG = 120.0;

const int TRIG_PIN = 5;
const int ECHO_PIN = 18;
const int HX711_DT_PIN = 19;
const int HX711_SCK_PIN = 21;

HX711 scale;

float readDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration <= 0) {
    return EMPTY_BIN_DEPTH_CM;
  }
  return duration * 0.0343 / 2.0;
}

float readWeightKg() {
  if (!scale.is_ready()) {
    return 0.0;
  }

  // For real hardware, calibrate this factor using a known weight.
  // Example: scale.set_scale(2280.f);
  float units = scale.get_units(5);
  if (units < 0) {
    units = 0;
  }
  return units;
}

int calculateFillPercent(float distanceCm) {
  float filledHeight = EMPTY_BIN_DEPTH_CM - distanceCm;
  float fillPercent = (filledHeight / EMPTY_BIN_DEPTH_CM) * 100.0;
  if (fillPercent < 0) fillPercent = 0;
  if (fillPercent > 100) fillPercent = 100;
  return round(fillPercent);
}

String firestoreUrl() {
  return String("https://firestore.googleapis.com/v1/projects/") +
         FIREBASE_PROJECT_ID +
         "/databases/(default)/documents/garbage_bins/" +
         BIN_ID +
         "?key=" +
         FIREBASE_API_KEY;
}

void uploadReading(int fillPercent, float currentWeightKg) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi not connected. Skipping upload.");
    return;
  }

  StaticJsonDocument<1024> doc;
  JsonObject fields = doc.createNestedObject("fields");
  fields["binId"]["stringValue"] = BIN_ID;
  fields["areaLabel"]["stringValue"] = AREA_LABEL;
  fields["fillPercent"]["integerValue"] = fillPercent;
  fields["capacityKg"]["doubleValue"] = BIN_CAPACITY_KG;
  fields["currentWeightKg"]["doubleValue"] = currentWeightKg;
  fields["latitude"]["doubleValue"] = LATITUDE;
  fields["longitude"]["doubleValue"] = LONGITUDE;
  fields["updatedAt"]["stringValue"] = "2026-07-28T10:30:00";

  String body;
  serializeJson(doc, body);

  HTTPClient http;
  http.begin(firestoreUrl());
  http.addHeader("Content-Type", "application/json");

  int responseCode = http.PATCH(body);
  Serial.print("Firestore response: ");
  Serial.println(responseCode);
  Serial.println(http.getString());
  http.end();
}

void setup() {
  Serial.begin(115200);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  scale.set_scale();
  scale.tare();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("Wi-Fi connected.");
}

void loop() {
  float distanceCm = readDistanceCm();
  int fillPercent = calculateFillPercent(distanceCm);
  float sensorWeightKg = readWeightKg();

  // If the load cell is not calibrated yet, estimate weight from fill percentage.
  float fallbackWeightKg = BIN_CAPACITY_KG * fillPercent / 100.0;
  float currentWeightKg = sensorWeightKg > 0 ? sensorWeightKg : fallbackWeightKg;

  Serial.print("Distance cm: ");
  Serial.print(distanceCm);
  Serial.print(" | Fill: ");
  Serial.print(fillPercent);
  Serial.print("% | Weight kg: ");
  Serial.println(currentWeightKg);

  uploadReading(fillPercent, currentWeightKg);

  delay(15000);
}
