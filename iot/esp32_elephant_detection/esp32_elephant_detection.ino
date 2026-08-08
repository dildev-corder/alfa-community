/*
  Alpha Community - ESP32 1: Elephant Beam Detection

  Wiring from project plan:
    Beam relay NC  -> GPIO 27, INPUT_PULLUP
    Beam relay COM -> ESP32 GND
    Red LED        -> GPIO 25
    Yellow LED     -> GPIO 26
    Buzzer/Siren   -> GPIO 23
    Relay IN       -> GPIO 19 optional

  Logic:
    Normal beam  -> GPIO 27 LOW
    Beam broken  -> GPIO 27 HIGH

  Uploads to Firestore:
    collection: alpha_iot_elephant
    document:   ESP32-ELEPHANT-001
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

const char* WIFI_SSID = "SLT-Fiber-2.4G_5b00";
const char* WIFI_PASSWORD = "Dildev@200108300848";

const char* FIREBASE_PROJECT_ID = "alpha-community-95a5c";
const char* FIREBASE_API_KEY = "AIzaSyA8FMQb8HWOBFXoMoIDWXa1eDUuxhjhqqM";

const char* DEVICE_ID = "ESP32-ELEPHANT-001";
const char* AREA_LABEL = "Elephant crossing beam";

const int BEAM_PIN = 27;
const int RED_LED_PIN = 25;
const int YELLOW_LED_PIN = 26;
const int BUZZER_PIN = 23;
const int RELAY_PIN = 19;

unsigned long lastUploadMs = 0;
bool lastBeamBroken = false;

String nowIso() {
  struct tm timeInfo;
  if (!getLocalTime(&timeInfo)) {
    return "1970-01-01T00:00:00";
  }
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeInfo);
  return String(buffer);
}

String firestoreUrl() {
  return String("https://firestore.googleapis.com/v1/projects/") +
         FIREBASE_PROJECT_ID +
         "/databases/(default)/documents/alpha_iot_elephant/" +
         DEVICE_ID +
         "?key=" +
         FIREBASE_API_KEY;
}

void uploadBeamStatus(bool beamBroken) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi not connected. Skipping upload.");
    return;
  }

  StaticJsonDocument<1024> doc;
  JsonObject fields = doc.createNestedObject("fields");
  fields["deviceId"]["stringValue"] = DEVICE_ID;
  fields["areaLabel"]["stringValue"] = AREA_LABEL;
  fields["beamBroken"]["booleanValue"] = beamBroken;
  fields["gpio27"]["integerValue"] = digitalRead(BEAM_PIN);
  fields["risk"]["stringValue"] = beamBroken ? "high" : "low";
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

void setOutputs(bool beamBroken) {
  digitalWrite(RED_LED_PIN, beamBroken ? HIGH : LOW);
  digitalWrite(YELLOW_LED_PIN, beamBroken ? LOW : HIGH);
  digitalWrite(BUZZER_PIN, beamBroken ? HIGH : LOW);
  digitalWrite(RELAY_PIN, beamBroken ? HIGH : LOW);
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

  pinMode(BEAM_PIN, INPUT_PULLUP);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);

  setOutputs(false);
  connectWifi();
  uploadBeamStatus(false);
}

void loop() {
  bool beamBroken = digitalRead(BEAM_PIN) == HIGH;
  setOutputs(beamBroken);

  if (beamBroken != lastBeamBroken || millis() - lastUploadMs > 10000) {
    Serial.print("Beam status: ");
    Serial.println(beamBroken ? "BROKEN / HIGH RISK" : "NORMAL");
    uploadBeamStatus(beamBroken);
    lastBeamBroken = beamBroken;
    lastUploadMs = millis();
  }

  delay(150);
}
