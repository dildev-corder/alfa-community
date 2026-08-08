# Model asset

Expected independently trained assets:

- `elephant_model.tflite`
- `flood_model.tflite`
- `landslide_model.tflite`
- `garbage_model.tflite`

Flood, landslide, and garbage modules are wired to load these assets when they
exist. Elephant detection still needs export-specific YOLO output decoding.

Never present missing-model fallbacks as official warnings.
