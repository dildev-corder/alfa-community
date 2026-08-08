"""Generate the end-to-end Alfa Community Google Colab notebook."""

from __future__ import annotations

import json
from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "ml" / "Alfa_Community_ML_Colab_A_to_Z.ipynb"


def md(text: str) -> dict:
    return {"cell_type": "markdown", "metadata": {}, "source": dedent(text).strip().splitlines(True)}


def code(text: str) -> dict:
    return {"cell_type": "code", "execution_count": None, "metadata": {}, "outputs": [],
            "source": dedent(text).strip().splitlines(True)}


cells = [
md("""
# Alfa Community - Machine Learning Project (A to Z)

**Modules:** Flood risk, landslide risk, garbage classification and elephant detection  
**Platform:** Google Colab -> TensorFlow Lite -> Flutter mobile application

This notebook is designed for a lecturer demonstration and a reproducible final submission. Run the cells in order.

### Presentation route (10 minutes)
1. Explain the four real-world problems and datasets.
2. Run the EDA summary cells.
3. Show preprocessing and baseline comparisons.
4. Show tuning, confusion matrices and training curves.
5. Export TFLite models and connect them to the Flutter app.

> Safety note: these models are educational decision-support prototypes. They are not official emergency-warning systems.
"""),
md("""
## 1. Runtime configuration

For tomorrow, keep `DEMO_MODE = True`. It uses fewer epochs and a sample of large image datasets. For final training, change it to `False` and use a GPU runtime: **Runtime -> Change runtime type -> T4 GPU**.
"""),
code("""
DEMO_MODE = True
RANDOM_SEED = 42

FLOOD_EPOCHS = 5 if DEMO_MODE else 60
LANDSLIDE_EPOCHS = 5 if DEMO_MODE else 60
GARBAGE_EPOCHS = 2 if DEMO_MODE else 15
ELEPHANT_EPOCHS = 2 if DEMO_MODE else 50
ELEPHANT_FRACTION = 0.10 if DEMO_MODE else 1.0

print("Demo mode:", DEMO_MODE)
print("Select a GPU runtime for image-model training.")
"""),
md("## 2. Install and import dependencies"),
code("""
!pip -q install ultralytics seaborn scikit-learn pyyaml gdown
"""),
code("""
import json, os, random, shutil, warnings
from collections import Counter
from pathlib import Path

import cv2
import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import tensorflow as tf
import yaml

from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, classification_report,
                             confusion_matrix, f1_score)
from sklearn.model_selection import RandomizedSearchCV, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_class_weight

warnings.filterwarnings("ignore")
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)
tf.random.set_seed(RANDOM_SEED)
sns.set_theme(style="whitegrid")

print("TensorFlow:", tf.__version__)
print("GPU devices:", tf.config.list_physical_devices("GPU"))
"""),
md("""
## 3. Download the Alfa project data

The shared Google Drive dataset link is configured below. The cell downloads
the archive directly and extracts it into the Colab workspace.
"""),
code("""
import shutil
from pathlib import Path

import gdown

DRIVE_FILE_ID = "1tbyF4wMqwrYS4Ab6JZWe_lLi1eLXF_As"
DRIVE_URL = f"https://drive.google.com/uc?id={DRIVE_FILE_ID}"
ZIP_PATH = Path("/content/alfa_ml_data.zip")
WORKSPACE = Path("/content/alfa_ml")
WORKSPACE.mkdir(parents=True, exist_ok=True)

downloaded = gdown.download(url=DRIVE_URL, output=str(ZIP_PATH), quiet=False, fuzzy=True)
if not downloaded or not ZIP_PATH.exists():
    raise RuntimeError(
        "Dataset download failed. Confirm that the Drive file permission is "
        "set to 'Anyone with the link'.")

print(f"Downloaded {ZIP_PATH.stat().st_size / 1024 / 1024:.1f} MB")
shutil.unpack_archive(str(ZIP_PATH), str(WORKSPACE))
print("Extracted to", WORKSPACE)
print("Top-level items:", [p.name for p in WORKSPACE.iterdir()])
"""),
md("## 4. Dataset paths and validation"),
code("""
dataset_candidates = [p for p in WORKSPACE.rglob("datasets") if p.is_dir()]
if not dataset_candidates:
    raise FileNotFoundError("The downloaded archive does not contain a datasets folder.")
DATASETS = min(dataset_candidates, key=lambda path: len(path.parts))
ARTIFACTS = WORKSPACE / "colab_artifacts"
ARTIFACTS.mkdir(exist_ok=True)

print("Using datasets folder:", DATASETS)

FLOOD_CSV = DATASETS / "flood" / "flood.csv"
LANDSLIDE_CSV = DATASETS / "landslide" / "landslide.csv"
GARBAGE_DIR = DATASETS / "garbage"
ELEPHANT_ROOT = DATASETS / "elephant_raw" / "elephant-dataset-yolov"

required = [FLOOD_CSV, LANDSLIDE_CSV, GARBAGE_DIR, ELEPHANT_ROOT]
for path in required:
    print(f"{path}: {'OK' if path.exists() else 'MISSING'}")
assert all(path.exists() for path in required), "Fix the ZIP folder structure before continuing."
"""),
md("""
# Part A - Flood Risk Classification

**Goal:** predict low, medium or high flood risk from 24-hour rainfall, water level and drainage effectiveness.
"""),
md("## 5. Flood dataset summary and EDA"),
code("""
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

flood = pd.read_csv(FLOOD_CSV)
FLOOD_FEATURES = ["rainfall_24h", "water_level_m", "drainage_percent"]
TARGET = "risk_label"

display(flood.head())
print("Shape:", flood.shape)
display(flood.dtypes.rename("dtype").to_frame())
display(flood.describe().T)
display(flood.isna().sum().rename("missing_values").to_frame())
"""),
code("""
fig, axes = plt.subplots(2, 2, figsize=(13, 8))
for feature, ax in zip(FLOOD_FEATURES, axes.flat[:3]):
    sns.histplot(flood[feature], kde=True, ax=ax, color="#1769AA")
    ax.set_title(f"Distribution of {feature}")
sns.countplot(data=flood, x=TARGET, ax=axes.flat[3], palette="RdYlGn_r")
axes.flat[3].set_xticklabels(["Low", "Medium", "High"])
axes.flat[3].set_title("Flood target class distribution")
plt.tight_layout(); plt.show()

plt.figure(figsize=(7, 5))
sns.heatmap(flood.corr(numeric_only=True), annot=True, cmap="Blues", vmin=-1, vmax=1)
plt.title("Flood correlation matrix"); plt.show()

display(flood.groupby(TARGET)[FLOOD_FEATURES].agg(["mean", "median"]).round(2))
"""),
md("""
### Flood EDA interpretation
- There are 10,000 complete records and no missing values.
- The target is imbalanced toward high risk.
- Rainfall and water level have only weak relationships with the derived target.
- Drainage has limited variation and almost no linear correlation with risk.
- Therefore, macro-F1 is reported alongside accuracy and the result must not be treated as production-ready.
"""),
md("## 6. Reusable preprocessing and split"),
code("""
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

RANDOM_SEED = globals().get("RANDOM_SEED", 42)

def make_tabular_pipeline(features, model):
    numeric = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scale", StandardScaler()),
    ])
    preprocessor = ColumnTransformer([("numeric", numeric, features)])
    return Pipeline([("preprocess", preprocessor), ("model", model)])

def split_stratified(frame, features, target="risk_label"):
    x_train_val, x_test, y_train_val, y_test = train_test_split(
        frame[features], frame[target], test_size=0.20,
        random_state=RANDOM_SEED, stratify=frame[target])
    x_train, x_val, y_train, y_val = train_test_split(
        x_train_val, y_train_val, test_size=0.25,
        random_state=RANDOM_SEED, stratify=y_train_val)
    return x_train, x_val, x_test, y_train, y_val, y_test

fx_train, fx_val, fx_test, fy_train, fy_val, fy_test = split_stratified(
    flood, FLOOD_FEATURES)
print("Train / validation / test:", len(fx_train), len(fx_val), len(fx_test))
"""),
md("## 7. Flood baseline model comparison"),
code("""
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score

flood_models = {
    "Logistic Regression": make_tabular_pipeline(
        FLOOD_FEATURES, LogisticRegression(max_iter=1000, random_state=RANDOM_SEED)),
    "Random Forest": make_tabular_pipeline(
        FLOOD_FEATURES, RandomForestClassifier(n_estimators=100, random_state=RANDOM_SEED)),
}

baseline_rows = []
for name, model in flood_models.items():
    model.fit(fx_train, fy_train)
    pred = model.predict(fx_val)
    baseline_rows.append({
        "model": name,
        "accuracy": accuracy_score(fy_val, pred),
        "macro_f1": f1_score(fy_val, pred, average="macro"),
    })
flood_baselines = pd.DataFrame(baseline_rows).sort_values("macro_f1", ascending=False)
display(flood_baselines.style.format({"accuracy": "{:.4f}", "macro_f1": "{:.4f}"}))
"""),
md("## 8. Flood hyperparameter tuning and final evaluation"),
code("""
import joblib
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (accuracy_score, classification_report,
                             confusion_matrix, f1_score)
from sklearn.model_selection import RandomizedSearchCV

DEMO_MODE = globals().get("DEMO_MODE", True)
RANDOM_SEED = globals().get("RANDOM_SEED", 42)

flood_search = RandomizedSearchCV(
    make_tabular_pipeline(FLOOD_FEATURES, RandomForestClassifier(random_state=RANDOM_SEED)),
    param_distributions={
        "model__n_estimators": [100, 200, 300, 500],
        "model__max_depth": [None, 8, 16, 24],
        "model__min_samples_split": [2, 5, 10],
        "model__class_weight": [None, "balanced"],
    },
    n_iter=6 if DEMO_MODE else 20,
    scoring="f1_macro", cv=5, random_state=RANDOM_SEED, n_jobs=-1, verbose=1)

flood_search.fit(pd.concat([fx_train, fx_val]), pd.concat([fy_train, fy_val]))
flood_best = flood_search.best_estimator_
flood_pred = flood_best.predict(fx_test)

print("Best parameters:", flood_search.best_params_)
print("Test accuracy:", round(accuracy_score(fy_test, flood_pred), 4))
print("Test macro-F1:", round(f1_score(fy_test, flood_pred, average="macro"), 4))
print(classification_report(fy_test, flood_pred, target_names=["low", "medium", "high"]))

cm = confusion_matrix(fy_test, flood_pred)
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
            xticklabels=["Low", "Medium", "High"],
            yticklabels=["Low", "Medium", "High"])
plt.xlabel("Predicted"); plt.ylabel("Actual"); plt.title("Flood test confusion matrix"); plt.show()
joblib.dump(flood_best, ARTIFACTS / "flood_best_sklearn.joblib")
"""),
md("## 9. Train and export the mobile flood neural network"),
code("""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split

RANDOM_SEED = globals().get("RANDOM_SEED", 42)
DEMO_MODE = globals().get("DEMO_MODE", True)
FLOOD_EPOCHS = globals().get("FLOOD_EPOCHS", 5 if DEMO_MODE else 60)
TARGET = globals().get("TARGET", "risk_label")
ARTIFACTS = globals().get("ARTIFACTS", Path("/content/alfa_ml/colab_artifacts"))
ARTIFACTS.mkdir(parents=True, exist_ok=True)

def train_mobile_tabular_model(frame, features, output_name, epochs):
    x = frame[features].astype("float32").to_numpy()
    y = frame[TARGET].astype("int32").to_numpy()
    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=.2, random_state=RANDOM_SEED, stratify=y)
    normalizer = tf.keras.layers.Normalization()
    normalizer.adapt(x_train)
    model = tf.keras.Sequential([
        tf.keras.Input(shape=(len(features),)), normalizer,
        tf.keras.layers.Dense(24, activation="relu"),
        tf.keras.layers.Dropout(.2),
        tf.keras.layers.Dense(12, activation="relu"),
        tf.keras.layers.Dense(3, activation="softmax"),
    ])
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    history = model.fit(x_train, y_train, validation_split=.2, epochs=epochs,
                        batch_size=32, verbose=1)
    loss, accuracy = model.evaluate(x_test, y_test, verbose=0)
    print(output_name, "test accuracy:", round(accuracy, 4))
    pd.DataFrame(history.history).plot(figsize=(9, 4), title=f"{output_name} training history")
    plt.show()
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite = converter.convert()
    path = ARTIFACTS / output_name
    path.write_bytes(tflite)
    print("Exported", path, "bytes:", len(tflite))
    return model

flood_mobile_model = train_mobile_tabular_model(
    flood, FLOOD_FEATURES, "flood_model.tflite", FLOOD_EPOCHS)
"""),
md("""
# Part B - Landslide Risk Classification

**Goal:** predict low, medium or high landslide risk from 72-hour rainfall, terrain slope and soil moisture.
"""),
md("## 10. Landslide EDA"),
code("""
landslide = pd.read_csv(LANDSLIDE_CSV)
LANDSLIDE_FEATURES = ["rainfall_72h", "slope_degrees", "soil_moisture_percent"]
display(landslide.head())
print("Shape:", landslide.shape)
display(landslide.describe().T)
display(landslide.isna().sum().rename("missing_values").to_frame())

fig, axes = plt.subplots(2, 2, figsize=(13, 8))
for feature, ax in zip(LANDSLIDE_FEATURES, axes.flat[:3]):
    sns.histplot(landslide[feature], kde=True, ax=ax, color="#1D6B49")
sns.countplot(data=landslide, x=TARGET, ax=axes.flat[3], palette="RdYlGn_r")
axes.flat[3].set_xticklabels(["Low", "Medium", "High"])
plt.tight_layout(); plt.show()

plt.figure(figsize=(7, 5))
sns.heatmap(landslide.corr(numeric_only=True), annot=True, cmap="Blues", vmin=-1, vmax=1)
plt.title("Landslide correlation matrix"); plt.show()
display(landslide.groupby(TARGET)[LANDSLIDE_FEATURES].agg(["mean", "median"]).round(2))
"""),
md("""
### Landslide EDA interpretation
- There are 9,864 complete records.
- High-risk records represent approximately half of the target.
- Slope has a strong correlation of approximately 0.81 with the label.
- This may produce strong predictions, but it also suggests that the derived target may depend heavily on a slope threshold.
"""),
md("## 11. Landslide baselines, tuning and evaluation"),
code("""
lx_train, lx_val, lx_test, ly_train, ly_val, ly_test = split_stratified(
    landslide, LANDSLIDE_FEATURES)

landslide_candidates = {
    "Logistic Regression": make_tabular_pipeline(
        LANDSLIDE_FEATURES, LogisticRegression(max_iter=1000, random_state=RANDOM_SEED)),
    "Random Forest": make_tabular_pipeline(
        LANDSLIDE_FEATURES, RandomForestClassifier(n_estimators=100, random_state=RANDOM_SEED)),
}
rows = []
for name, model in landslide_candidates.items():
    model.fit(lx_train, ly_train)
    pred = model.predict(lx_val)
    rows.append({"model": name, "accuracy": accuracy_score(ly_val, pred),
                 "macro_f1": f1_score(ly_val, pred, average="macro")})
display(pd.DataFrame(rows).sort_values("macro_f1", ascending=False))

landslide_search = RandomizedSearchCV(
    make_tabular_pipeline(LANDSLIDE_FEATURES, RandomForestClassifier(random_state=RANDOM_SEED)),
    {"model__n_estimators": [100, 200, 300], "model__max_depth": [None, 8, 16, 24],
     "model__min_samples_split": [2, 5, 10], "model__class_weight": [None, "balanced"]},
    n_iter=6 if DEMO_MODE else 18, cv=5, scoring="f1_macro",
    random_state=RANDOM_SEED, n_jobs=-1, verbose=1)
landslide_search.fit(pd.concat([lx_train, lx_val]), pd.concat([ly_train, ly_val]))
landslide_best = landslide_search.best_estimator_
landslide_pred = landslide_best.predict(lx_test)
print("Best parameters:", landslide_search.best_params_)
print(classification_report(ly_test, landslide_pred, target_names=["low", "medium", "high"]))
sns.heatmap(confusion_matrix(ly_test, landslide_pred), annot=True, fmt="d", cmap="Greens",
            xticklabels=["Low", "Medium", "High"], yticklabels=["Low", "Medium", "High"])
plt.title("Landslide test confusion matrix"); plt.xlabel("Predicted"); plt.ylabel("Actual"); plt.show()
joblib.dump(landslide_best, ARTIFACTS / "landslide_best_sklearn.joblib")
"""),
md("## 12. Train and export the mobile landslide model"),
code("""
DEMO_MODE = globals().get("DEMO_MODE", True)
LANDSLIDE_EPOCHS = globals().get("LANDSLIDE_EPOCHS", 5 if DEMO_MODE else 60)

landslide_mobile_model = train_mobile_tabular_model(
    landslide, LANDSLIDE_FEATURES, "landslide_model.tflite", LANDSLIDE_EPOCHS)
"""),
md("""
# Part C - Garbage Image Classification

**Goal:** classify a photograph into battery, biological, cardboard, clothes, glass, metal, paper, plastic, shoes or trash.
"""),
md("## 13. Garbage dataset EDA"),
code("""
def image_class_counts(directory):
    return {folder.name: len([p for p in folder.iterdir() if p.is_file()])
            for folder in sorted(directory.iterdir()) if folder.is_dir()}

garbage_train_counts = image_class_counts(GARBAGE_DIR / "train")
garbage_val_counts = image_class_counts(GARBAGE_DIR / "validation")
garbage_counts = pd.DataFrame({"train": garbage_train_counts, "validation": garbage_val_counts}).fillna(0).astype(int)
garbage_counts["total"] = garbage_counts.sum(axis=1)
garbage_counts["percentage"] = garbage_counts.total / garbage_counts.total.sum() * 100
display(garbage_counts)
garbage_counts[["train", "validation"]].plot(kind="bar", figsize=(12, 5), color=["#1D6B49", "#FFC000"])
plt.title("Garbage class distribution"); plt.ylabel("Images"); plt.xticks(rotation=35); plt.show()
"""),
code("""
import random

import cv2
import matplotlib.pyplot as plt

classes = list(garbage_train_counts)
fig, axes = plt.subplots(2, 5, figsize=(15, 6))
for class_name, ax in zip(classes, axes.flat):
    candidates = list((GARBAGE_DIR / "train" / class_name).glob("*"))
    image = cv2.cvtColor(cv2.imread(str(random.choice(candidates))), cv2.COLOR_BGR2RGB)
    ax.imshow(image); ax.set_title(class_name); ax.axis("off")
plt.suptitle("Random garbage training examples"); plt.tight_layout(); plt.show()
"""),
md("""
### Garbage EDA interpretation
- The dataset contains 12,259 images: 10,426 training and 1,833 validation.
- Clothes is the largest class; trash is the smallest.
- Macro-F1 and per-class recall are important because the classes are imbalanced.
- A separate test split is required for a rigorous final report.
"""),
md("## 14. Garbage preprocessing, transfer learning and training"),
code("""
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32

garbage_train = tf.keras.utils.image_dataset_from_directory(
    GARBAGE_DIR / "train", image_size=IMAGE_SIZE, batch_size=BATCH_SIZE,
    seed=RANDOM_SEED, shuffle=True)
garbage_val = tf.keras.utils.image_dataset_from_directory(
    GARBAGE_DIR / "validation", image_size=IMAGE_SIZE, batch_size=BATCH_SIZE,
    seed=RANDOM_SEED, shuffle=False)
GARBAGE_CLASSES = garbage_train.class_names
print(GARBAGE_CLASSES)

AUTOTUNE = tf.data.AUTOTUNE
garbage_train = garbage_train.prefetch(AUTOTUNE)
garbage_val = garbage_val.prefetch(AUTOTUNE)

augmentation = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal"),
    tf.keras.layers.RandomRotation(.08),
    tf.keras.layers.RandomZoom(.1),
    tf.keras.layers.RandomContrast(.1),
])

base = tf.keras.applications.MobileNetV2(
    input_shape=(*IMAGE_SIZE, 3), include_top=False, weights="imagenet")
base.trainable = False
inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3))
x = augmentation(inputs)
x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
x = base(x, training=False)
x = tf.keras.layers.GlobalAveragePooling2D()(x)
x = tf.keras.layers.Dropout(.25)(x)
outputs = tf.keras.layers.Dense(len(GARBAGE_CLASSES), activation="softmax")(x)
garbage_model = tf.keras.Model(inputs, outputs)
garbage_model.compile(optimizer="adam", loss="sparse_categorical_crossentropy",
                      metrics=["accuracy"])
garbage_model.summary()
"""),
code("""
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.utils.class_weight import compute_class_weight

DEMO_MODE = globals().get("DEMO_MODE", True)
GARBAGE_EPOCHS = globals().get("GARBAGE_EPOCHS", 2 if DEMO_MODE else 15)

class_ids = np.arange(len(GARBAGE_CLASSES))
class_counts = np.array([garbage_train_counts[name] for name in GARBAGE_CLASSES])
expanded_labels = np.repeat(class_ids, class_counts)
weights = compute_class_weight("balanced", classes=class_ids, y=expanded_labels)
class_weights = dict(zip(class_ids, weights))
print("Class weights:", class_weights)

garbage_history = garbage_model.fit(
    garbage_train, validation_data=garbage_val,
    epochs=GARBAGE_EPOCHS, class_weight=class_weights)

history_frame = pd.DataFrame(garbage_history.history)
history_frame[["accuracy", "val_accuracy"]].plot(title="Garbage accuracy")
plt.show()
history_frame[["loss", "val_loss"]].plot(title="Garbage loss")
plt.show()
"""),
md("## 15. Garbage evaluation and TFLite export"),
code("""
import json

garbage_true, garbage_pred = [], []
for images, labels in garbage_val:
    probabilities = garbage_model.predict(images, verbose=0)
    garbage_true.extend(labels.numpy())
    garbage_pred.extend(np.argmax(probabilities, axis=1))

print(classification_report(garbage_true, garbage_pred, target_names=GARBAGE_CLASSES))
plt.figure(figsize=(10, 8))
sns.heatmap(confusion_matrix(garbage_true, garbage_pred), annot=True, fmt="d", cmap="Greens",
            xticklabels=GARBAGE_CLASSES, yticklabels=GARBAGE_CLASSES)
plt.xticks(rotation=45, ha="right"); plt.title("Garbage validation confusion matrix")
plt.xlabel("Predicted"); plt.ylabel("Actual"); plt.tight_layout(); plt.show()

converter = tf.lite.TFLiteConverter.from_keras_model(garbage_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
(ARTIFACTS / "garbage_model.tflite").write_bytes(converter.convert())
(ARTIFACTS / "garbage_model.labels.json").write_text(json.dumps(GARBAGE_CLASSES, indent=2))
print("Garbage TFLite model and labels exported.")
"""),
md("""
# Part D - Elephant Object Detection

**Goal:** detect and locate elephants in camera or gallery images using YOLO11n.
"""),
md("## 16. Elephant dataset EDA and annotation validation"),
code("""
def yolo_split_summary(root, split):
    images = [p for p in (root / split / "images").iterdir() if p.is_file()]
    labels = list((root / split / "labels").glob("*.txt"))
    image_stems, label_stems = {p.stem for p in images}, {p.stem for p in labels}
    boxes, empty, bad = [], 0, 0
    # In demo mode inspect a deterministic sample to keep this cell fast.
    inspect_labels = labels[:500] if DEMO_MODE else labels
    for label in inspect_labels:
        rows = [row for row in label.read_text().splitlines() if row.strip()]
        empty += int(not rows)
        for row in rows:
            values = row.split()
            if len(values) != 5:
                bad += 1; continue
            class_id, x, y, width, height = map(float, values)
            if class_id != 0 or not all(0 <= value <= 1 for value in [x, y, width, height]):
                bad += 1
            boxes.append((width, height))
    return {
        "split": split, "images": len(images), "labels": len(labels),
        "unlabelled_images": len(image_stems - label_stems),
        "orphan_labels": len(label_stems - image_stems),
        "inspected_labels": len(inspect_labels), "boxes_inspected": len(boxes),
        "empty_labels": empty, "bad_rows": bad,
        "mean_box_area_pct": np.mean([w*h for w, h in boxes])*100 if boxes else 0,
    }

elephant_summary = pd.DataFrame([
    yolo_split_summary(ELEPHANT_ROOT, split) for split in ["train", "valid", "test"]])
display(elephant_summary)
"""),
code("""
def draw_yolo_example(image_path, label_path):
    image = cv2.imread(str(image_path))
    height, width = image.shape[:2]
    for row in label_path.read_text().splitlines():
        class_id, x, y, w, h = map(float, row.split())
        x1, y1 = int((x-w/2)*width), int((y-h/2)*height)
        x2, y2 = int((x+w/2)*width), int((y+h/2)*height)
        cv2.rectangle(image, (x1, y1), (x2, y2), (0,255,0), 3)
        cv2.putText(image, "elephant", (x1, max(20,y1-8)), cv2.FONT_HERSHEY_SIMPLEX,
                    .7, (0,255,0), 2)
    return cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

fig, axes = plt.subplots(2, 3, figsize=(15, 9))
for ax, image_path in zip(axes.flat, list((ELEPHANT_ROOT/"train"/"images").iterdir())[:6]):
    label_path = ELEPHANT_ROOT / "train" / "labels" / f"{image_path.stem}.txt"
    ax.imshow(draw_yolo_example(image_path, label_path)); ax.axis("off")
plt.suptitle("Elephant training images with YOLO bounding boxes"); plt.tight_layout(); plt.show()
"""),
md("## 17. Prepare Colab-safe YOLO configuration"),
code("""
import yaml

elephant_yaml = ARTIFACTS / "elephant_colab.yaml"
config = {
    "path": str(ELEPHANT_ROOT),
    "train": "train/images",
    "val": "valid/images",
    "test": "test/images",
    "nc": 1,
    "names": ["elephant"],
}
elephant_yaml.write_text(yaml.safe_dump(config, sort_keys=False))
print(elephant_yaml.read_text())
"""),
md("## 18. Train, validate and export YOLO11n"),
code("""
!pip -q install ultralytics

from pathlib import Path
from ultralytics import YOLO

DEMO_MODE = globals().get("DEMO_MODE", True)
RANDOM_SEED = globals().get("RANDOM_SEED", 42)
ELEPHANT_EPOCHS = globals().get("ELEPHANT_EPOCHS", 2 if DEMO_MODE else 50)
ELEPHANT_FRACTION = globals().get("ELEPHANT_FRACTION", 0.10 if DEMO_MODE else 1.0)

elephant_model = YOLO("yolo11n.pt")
elephant_result = elephant_model.train(
    data=str(elephant_yaml), epochs=ELEPHANT_EPOCHS,
    imgsz=320 if DEMO_MODE else 640,
    batch=8 if DEMO_MODE else 16,
    fraction=ELEPHANT_FRACTION,
    project=str(ARTIFACTS / "elephant_runs"), name="alfa_elephant",
    patience=5 if DEMO_MODE else 12, plots=True, seed=RANDOM_SEED)

best_elephant = YOLO(Path(elephant_result.save_dir) / "weights" / "best.pt")
metrics = best_elephant.val(data=str(elephant_yaml), split="test", plots=True)
print("Precision:", metrics.box.mp)
print("Recall:", metrics.box.mr)
print("mAP@0.50:", metrics.box.map50)
print("mAP@0.50:0.95:", metrics.box.map)

best_elephant.export(format="tflite", imgsz=320 if DEMO_MODE else 640)
print("YOLO training, test evaluation and TFLite export completed.")
"""),
md("## 19. Show elephant training outputs"),
code("""
run_dir = Path(elephant_result.save_dir)
for filename in ["results.png", "confusion_matrix.png", "PR_curve.png"]:
    path = run_dir / filename
    if path.exists():
        image = cv2.cvtColor(cv2.imread(str(path)), cv2.COLOR_BGR2RGB)
        plt.figure(figsize=(12, 7)); plt.imshow(image); plt.title(filename); plt.axis("off"); plt.show()
"""),
md("""
# Part E - Model Comparison, Export and Presentation
"""),
md("## 20. Compare model tasks correctly"),
code("""
comparison = pd.DataFrame([
    ["Flood", "3-class classification", "Accuracy, macro-F1, confusion matrix", "TFLite"],
    ["Landslide", "3-class classification", "Accuracy, macro-F1, confusion matrix", "TFLite"],
    ["Garbage", "10-class image classification", "Accuracy, macro-F1, per-class recall", "TFLite + JSON labels"],
    ["Elephant", "Single-class object detection", "Precision, recall, mAP@.50, mAP@.50:.95", "YOLO TFLite"],
], columns=["Module", "Task", "Correct evaluation", "Mobile export"])
display(comparison)
"""),
md("## 21. Verify exported TensorFlow Lite files"),
code("""
for model_path in ARTIFACTS.rglob("*.tflite"):
    try:
        interpreter = tf.lite.Interpreter(model_path=str(model_path))
        interpreter.allocate_tensors()
        print("\\n", model_path.name, f"({model_path.stat().st_size/1024/1024:.2f} MB)")
        print(" input:", interpreter.get_input_details()[0]["shape"])
        print(" output:", interpreter.get_output_details()[0]["shape"])
    except Exception as error:
        print("Could not inspect", model_path, error)
"""),
md("## 22. Create downloadable project artifacts"),
code("""
archive = shutil.make_archive("/content/alfa_ml_colab_artifacts", "zip", ARTIFACTS)
print("Created:", archive)
from google.colab import files
files.download(archive)
"""),
md("""
## 23. Final findings and reflection

### Main findings
- Flood prediction is limited by weak feature-target relationships and derived labels.
- Landslide slope is highly predictive, but this dominance must be checked for label leakage.
- Garbage classification benefits from transfer learning, augmentation and class weighting.
- YOLO11n provides a mobile-friendly elephant-detection baseline.

### Limitations
- The hazard datasets do not include timestamps, so this is classification rather than time-series forecasting.
- Flood and landslide targets require domain-expert validation.
- Garbage requires an independent test split.
- Elephant performance must be tested on local Sri Lankan camera footage.

### What to say to the lecturer
“We selected metrics based on the task rather than using one metric everywhere. We used stratification and reusable pipelines to prevent leakage, tuned only after baseline comparison, kept the test data held out, exported the models to TensorFlow Lite, and integrated model confidence and prediction history into Flutter. We also report limitations honestly because safety-related ML must not overclaim reliability.”
"""),
md("""
## 24. Before the demonstration

- Run this notebook once tonight with `DEMO_MODE = True`.
- Keep the completed Colab tab open so outputs remain visible.
- Download the artifacts ZIP.
- Also save a copy: **File -> Save a copy in Drive**.
- Do not start full elephant or garbage training during a short presentation.
- Replace all dataset-source placeholders in the report with exact Kaggle URLs.
"""),
]

notebook = {
    "cells": cells,
    "metadata": {
        "accelerator": "GPU",
        "colab": {"name": OUTPUT.name, "provenance": []},
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "version": "3.x"},
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}

OUTPUT.write_text(json.dumps(notebook, indent=1), encoding="utf-8")
print(OUTPUT)
