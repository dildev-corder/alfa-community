# Alfa Citizen

Alfa Citizen is a Flutter platform for location-aware citizen safety modules.
It currently includes elephant, flood, landslide, garbage, local alert history,
and a citizen GenAI assistant.

For the assessed ML project, use the flood-risk module as the single coherent
case study. See `COURSEWORK.md` for the rubric map, reproducible evaluation, and
mobile demonstration steps.

## Run

```powershell
flutter pub get
flutter run
```

The home screen starts in **Demo all modules** mode. Tap **Use my location** and
turn demo mode off to apply the MVP regional relevance profiles. These broad
profiles are only feature-selection rules, not official hazard maps.

## Plug-ins

- **Elephant:** camera/gallery flow, GPS alert capture, TFLite asset boundary
- **Flood:** rainfall, water-level, and drainage prototype assessment
- **Landslide:** rainfall, slope, and soil-moisture prototype assessment
- **Garbage:** photo classification demo, IoT smart-bin status, directions, and location-aware community report

## IoT smart-bin module

The IoT final-project component is a smart garbage-bin monitoring prototype. An
ESP32 can collect fill-level and weight readings from an ultrasonic sensor and
load cell, upload them to the Firestore `garbage_bins` collection, and the
Flutter garbage screen displays the nearest bin status. The app keeps a simulated
fallback reading so the final demo remains reliable without live hardware.

See `iot/README.md` and `iot/esp32_smart_bin/esp32_smart_bin.ino`.

Each future model is independent. See `ml/README.md` for dataset contracts,
training entry points, and expected TFLite asset names.

## GenAI assistant

Without configuration, the assistant uses a small offline safety guide. To use
a hosted generative model, deploy the proxy in `backend/server.mjs`, then run:

```powershell
flutter run --dart-define=GEN_AI_ENDPOINT=https://your-server.example/assistant
```

Never place a provider API key in Flutter source or `--dart-define`; secrets in
a mobile application can be extracted. The example backend needs production
authentication, rate limiting, moderation, and provider-specific validation.

## Model status

Place trained TensorFlow Lite files in `assets/models/`:

- `flood_model.tflite`: input `[rainfall_24h, water_level_m, drainage_percent]`, output `[low, medium, high]`
- `landslide_model.tflite`: input `[rainfall_72h, slope_degrees, soil_moisture_percent]`, output `[low, medium, high]`
- `garbage_model.tflite`: input image `224x224x3` normalized to `[-1, 1]`, output class probabilities
- `garbage_model.labels.json`: class labels matching the garbage model output
- `elephant_model.tflite`: YOLO detector export; decoder must match the exact export version

Flood, landslide, and garbage modules now try to run the installed TFLite model
first. If the trained file is missing, the app shows a warning and keeps a
development fallback where available. I cannot create fully trained models
without real datasets or exported model files; disaster and wildlife models must
be trained from validated data and tested for false alarms before real use.
