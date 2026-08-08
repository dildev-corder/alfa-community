# Alpha Community IoT Hardware

This folder contains the hardware code for the Alpha Community app.

Implemented boards:

- `esp32_elephant_detection/esp32_elephant_detection.ino`
- `esp32_flood_landslide/esp32_flood_landslide.ino`
- `arduino_uno_garbage_bin/arduino_uno_garbage_bin.ino`
- `esp32_smart_bin/esp32_smart_bin.ino` legacy ESP32 smart-bin prototype

## Data Flow

```text
Hardware sensors
  -> ESP32 or gateway uploads JSON to Firebase Firestore
  -> Flutter app reads the latest sensor document
  -> App shows live risk, bin status, and alerts
```

## Firestore Collections

Elephant beam:

```text
alpha_iot_elephant / ESP32-ELEPHANT-001
```

Flood and landslide:

```text
alpha_iot_environment / ESP32-ENV-001
```

Garbage bin:

```text
garbage_bins / BIN-UNO-001
```

## Required Arduino Libraries

Install these from Arduino IDE Library Manager:

```text
ArduinoJson
Servo
```

Install the ESP32 board package from Arduino Boards Manager.

For `esp32_smart_bin` legacy prototype also install:

```text
HX711
```

## Firebase Config

In each ESP32 sketch, replace:

```cpp
const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* FIREBASE_API_KEY = "YOUR_FIREBASE_WEB_API_KEY";
```

Project ID is already set:

```text
alpha-community-95a5c
```

For demo testing, Firestore rules must allow device writes. A simple development rule is:

```text
allow read, write: if true;
```

For production, use Firebase Auth, App Check, or a server gateway.

## Flutter Integration

App files:

```text
lib/src/services/iot_sensor_service.dart
lib/src/screens/detection_screen.dart
lib/src/plugins/flood/flood_screen.dart
lib/src/plugins/landslide/landslide_screen.dart
lib/src/services/garbage_bin_sensor_service.dart
```

App behavior:

- Elephant screen reads `alpha_iot_elephant`.
- Elephant screen can save an alert when beam sensor is broken.
- Flood screen button `Use ESP32 flood sensor reading` reads `alpha_iot_environment`.
- Landslide screen button `Use ESP32 landslide sensor reading` reads `alpha_iot_environment`.
- Garbage screen reads `garbage_bins`.

## Arduino Uno Garbage Note

Arduino Uno has no Wi-Fi. The Uno sketch controls LED/buzzer/servo and prints JSON over Serial.

To connect Uno to the app, upload that Serial JSON to Firestore with one of these:

- ESP8266 or ESP32 serial bridge
- PC Python/Node gateway
- Replace Uno with ESP32 and use `esp32_smart_bin/esp32_smart_bin.ino`

The app expects this Firestore document shape:

```json
{
  "binId": "BIN-UNO-001",
  "areaLabel": "Arduino Uno smart bin",
  "fillPercent": 72,
  "capacityKg": 30.0,
  "currentWeightKg": 21.6,
  "latitude": 7.2906,
  "longitude": 80.6337,
  "updatedAt": "2026-07-28T10:30:00"
}
```

## Demo Order

1. Flash `esp32_elephant_detection`.
2. Flash `esp32_flood_landslide`.
3. Upload `arduino_uno_garbage_bin` to Uno.
4. Confirm Firestore documents update.
5. Open app:
   - Elephant Monitoring -> refresh/start beam watch.
   - Flood Monitoring -> use ESP32 reading.
   - Landslide Monitoring -> use ESP32 reading.
   - Garbage Monitoring -> refresh bin sensor card.
