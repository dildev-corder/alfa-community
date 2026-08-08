/*
  Alpha Community - Arduino Uno: Garbage Bin + LED Alert

  Wiring:
    HC-SR04 TRIG -> D6
    HC-SR04 ECHO -> D7
    Green LED    -> D8
    Yellow LED   -> D9
    Red LED      -> D10
    Buzzer       -> D11
    Servo signal -> D5 optional

  Status:
    0-60%   Safe   -> Green LED
    61-79%  Medium -> Yellow LED
    80-100% Full   -> Red LED + Buzzer

  Uno has no Wi-Fi. This sketch prints JSON on Serial at 9600 baud.
  Use an ESP32/ESP8266/PC bridge to upload the JSON to Firestore collection:
    garbage_bins / BIN-UNO-001
*/

#include <Servo.h>

const int TRIG_PIN = 6;
const int ECHO_PIN = 7;
const int GREEN_LED_PIN = 8;
const int YELLOW_LED_PIN = 9;
const int RED_LED_PIN = 10;
const int BUZZER_PIN = 11;
const int SERVO_PIN = 5;

const float EMPTY_BIN_DEPTH_CM = 10.0;
const float BIN_CAPACITY_KG = 30.0;
const char* BIN_ID = "BIN-UNO-001";
const char* AREA_LABEL = "Arduino Uno smart bin";

Servo lidServo;

float readDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  unsigned long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration == 0) return EMPTY_BIN_DEPTH_CM;
  return duration * 0.0343 / 2.0;
}

int fillPercentFromDistance(float distanceCm) {
  float filledHeight = EMPTY_BIN_DEPTH_CM - distanceCm;
  float percent = (filledHeight / EMPTY_BIN_DEPTH_CM) * 100.0;
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;
  return round(percent);
}

const char* statusFor(int fillPercent) {
  if (fillPercent >= 80) return "full";
  if (fillPercent >= 61) return "medium";
  return "safe";
}

void setOutputs(int fillPercent) {
  bool safe = fillPercent <= 60;
  bool medium = fillPercent >= 61 && fillPercent <= 79;
  bool full = fillPercent >= 80;

  digitalWrite(GREEN_LED_PIN, safe ? HIGH : LOW);
  digitalWrite(YELLOW_LED_PIN, medium ? HIGH : LOW);
  digitalWrite(RED_LED_PIN, full ? HIGH : LOW);
  digitalWrite(BUZZER_PIN, full ? HIGH : LOW);

  if (full) {
    lidServo.write(0);
  } else {
    lidServo.write(90);
  }
}

void printJson(int fillPercent, float distanceCm) {
  float currentWeightKg = BIN_CAPACITY_KG * fillPercent / 100.0;
  Serial.print("{\"binId\":\"");
  Serial.print(BIN_ID);
  Serial.print("\",\"areaLabel\":\"");
  Serial.print(AREA_LABEL);
  Serial.print("\",\"fillPercent\":");
  Serial.print(fillPercent);
  Serial.print(",\"status\":\"");
  Serial.print(statusFor(fillPercent));
  Serial.print("\",\"capacityKg\":");
  Serial.print(BIN_CAPACITY_KG, 1);
  Serial.print(",\"currentWeightKg\":");
  Serial.print(currentWeightKg, 1);
  Serial.print(",\"distanceCm\":");
  Serial.print(distanceCm, 1);
  Serial.println("}");
}

void setup() {
  Serial.begin(9600);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  lidServo.attach(SERVO_PIN);
}

void loop() {
  float distanceCm = readDistanceCm();
  int fillPercent = fillPercentFromDistance(distanceCm);
  setOutputs(fillPercent);
  printJson(fillPercent, distanceCm);
  delay(3000);
}
