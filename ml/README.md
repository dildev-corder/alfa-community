# Independent model pipelines

Each safety plug-in owns a separate dataset, model, and TFLite export.

| Plug-in | Training entry point | Mobile asset |
| --- | --- | --- |
| Elephant | `train_elephant_detector.py` | `elephant_model.tflite` |
| Flood | `flood/train.py` | `flood_model.tflite` |
| Landslide | `landslide/train.py` | `landslide_model.tflite` |
| Garbage | `garbage/train.py` | `garbage_model.tflite` |

Install training dependencies in Google Colab or a GPU environment. Keep raw
datasets outside Git. Do not train disaster-risk models from invented labels;
use historical, sensor, terrain, and authority-validated data with documented
provenance.

The Flutter app loads flood, landslide, and garbage TFLite files automatically
when they exist in `assets/models/`. Elephant object detection needs the exact
YOLO export contract before decoding boxes safely in the app.

To train all available datasets at once:

```powershell
& "C:\Users\sa\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m pip install ultralytics tensorflow kaggle pandas
& "C:\Users\sa\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" ml\train_all.py --epochs 50
```

Confirmed public garbage dataset candidate:

- Kaggle: `sumn2u/garbage-classification-v2`

Download it after adding `kaggle.json`:

```powershell
& "C:\Users\sa\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" ml\download_datasets.py --garbage
```
