# IoT Presentation Notes

## Short explanation

My IoT module is a smart garbage-bin monitoring system. The bin uses an ultrasonic
sensor to measure how full the bin is and a load-cell sensor to estimate the weight
of waste inside the bin. An ESP32 reads those sensor values and uploads the bin
status to Firebase Firestore. The Flutter app reads the latest bin status and shows
citizens whether the nearest bin is free, nearly full, or full.

## Why this IoT part matches the ML project

The ML garbage model identifies the waste type from an image. The IoT bin module
checks whether the selected bin has space before the citizen goes there. Together,
the system supports cleaner waste collection:

- ML: “What type of waste is this?”
- IoT: “Is the nearest bin available?”
- Mobile app: “Show status, save report, and give directions.”

## Important paths to remember

- Flutter IoT service: `lib/src/services/garbage_bin_sensor_service.dart`
- Garbage app screen: `lib/src/plugins/garbage/garbage_screen.dart`
- ESP32 Arduino code: `iot/esp32_smart_bin/esp32_smart_bin.ino`
- IoT explanation: `iot/README.md`
- Firebase collection: `garbage_bins`

## Lecturer Q&A

### 1. What is the IoT part of your project?

The IoT part is a smart garbage-bin monitoring system. It measures bin fill level
and weight using sensors, sends readings through an ESP32, and displays the status
inside the Flutter app.

### 2. What sensors did you use?

The design uses an HC-SR04 ultrasonic sensor for fill level and a load-cell sensor
with HX711 amplifier for weight measurement.

### 3. Why use an ultrasonic sensor?

It can measure the distance from the top of the bin to the garbage level without
touching the waste. From that distance, the system calculates how full the bin is.

### 4. Why use a load cell?

The load cell helps estimate how heavy the bin is. This is useful because some waste
can be heavy even when the bin is not visually full.

### 5. Why use ESP32?

ESP32 has built-in Wi-Fi, enough GPIO pins for sensors, and is low cost, so it is
suitable for a smart community-bin prototype.

### 6. How does the IoT device communicate with the app?

The ESP32 uploads sensor readings to Firebase Firestore. The Flutter app reads the
latest document from Firestore and displays the nearest bin status.

### 7. What happens if the internet is not available?

The app has a fallback simulated reading, so the demo and basic user interface still
work. In a production version, the ESP32 could retry upload when the network returns.

### 8. How do you calculate fill percentage?

The app uses the bin depth and measured empty distance:

```text
fillPercent = ((emptyDepth - measuredDistance) / emptyDepth) * 100
```

### 9. When do you mark a bin as full?

In this prototype, a bin is treated as almost full when the fill percentage is 80%
or higher.

### 10. How is this useful to the community?

Citizens can avoid full bins, officers can identify bins that need collection, and
the system can reduce overflow and improve waste-management planning.

## Demo script

“This is the IoT section of my project. The smart bin sends fill level and weight
data to Firebase. In the app, I open the Garbage module. Here you can see the bin ID,
location name, fill percentage, used weight, and free capacity. If the bin is not
full, the user can open directions. If the bin is full, the citizen can report it
and officers can clear it. I also included an offline fallback, so the app continues
working during the presentation even if the hardware or internet is unavailable.”
