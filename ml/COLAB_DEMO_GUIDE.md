# Alfa Community Colab Demonstration Guide

## Files to prepare tonight

1. Open `Alfa_Community_ML_Colab_A_to_Z.ipynb` in Google Colab.
2. Confirm that the configured Google Drive file is shared as **Anyone with the link**.
3. Run the download cell; it uses Drive file ID
   `1tbyF4wMqwrYS4Ab6JZWe_lLi1eLXF_As` automatically.
4. Select **Runtime > Change runtime type > T4 GPU**.

The ZIP must have this structure:

```text
datasets/
  flood/flood.csv
  landslide/landslide.csv
  garbage/train/<class>/*.jpg
  garbage/validation/<class>/*.jpg
  elephant_raw/elephant-dataset-yolov/
    train/images and labels
    valid/images and labels
    test/images and labels
```

## Recommended settings

Keep `DEMO_MODE = True` for the first complete run. It uses:

- Flood: 5 neural-network epochs
- Landslide: 5 neural-network epochs
- Garbage: 2 MobileNetV2 epochs
- Elephant: 2 YOLO epochs using 10% of training data

After the demonstration, change `DEMO_MODE = False` for final training.

## Outputs to show the lecturer

1. Flood summary, distributions, correlation heatmap and class balance.
2. Flood Logistic Regression versus Random Forest comparison.
3. RandomizedSearchCV parameters, classification report and confusion matrix.
4. Landslide correlation heatmap showing the strong slope relationship.
5. Garbage class distribution and random sample-image grid.
6. MobileNetV2 model summary, learning curves and confusion matrix.
7. Elephant annotation examples with bounding boxes.
8. YOLO precision, recall, mAP curves and confusion matrix.
9. Exported TFLite tensor shapes.
10. The downloaded `alfa_ml_colab_artifacts.zip`.

## Presentation advice

Do not start full image training during the presentation. Open the already
completed notebook and explain the saved outputs. If asked to run code live,
run a quick EDA cell, baseline prediction or one sample inference.

Explain that flood and landslide are classification tasks because the current
datasets have no timestamps. Use accuracy and macro-F1 for classification;
use precision, recall and mAP for elephant object detection.
