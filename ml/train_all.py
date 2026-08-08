"""Train every available Alfa Citizen model and export assets for Flutter.

Expected dataset locations:
    datasets/elephant/data.yaml
    datasets/flood/flood.csv
    datasets/landslide/landslide.csv
    datasets/garbage/train/<class_name>/*.jpg
    datasets/garbage/validation/<class_name>/*.jpg

The script skips missing datasets. It does not invent data.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ML = ROOT / "ml"
DATASETS = ROOT / "datasets"
ASSETS = ROOT / "assets" / "models"


def run(command: list[str]) -> None:
    print("\n$", " ".join(command), flush=True)
    subprocess.run(command, check=True, cwd=ROOT)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", default=50, type=int)
    args = parser.parse_args()
    ASSETS.mkdir(parents=True, exist_ok=True)

    elephant_yaml = DATASETS / "elephant" / "data.yaml"
    if elephant_yaml.exists():
        run(
            [
                sys.executable,
                str(ML / "train_elephant_detector.py"),
                "--data",
                str(elephant_yaml),
                "--epochs",
                str(args.epochs),
            ]
        )
        print("Copy the exported YOLO TFLite file to assets/models/elephant_model.tflite")
    else:
        print(f"Skipping elephant: missing {elephant_yaml}")

    flood_csv = DATASETS / "flood" / "flood.csv"
    if flood_csv.exists():
        run(
            [
                sys.executable,
                str(ML / "flood" / "train.py"),
                "--csv",
                str(flood_csv),
                "--output",
                str(ASSETS / "flood_model.tflite"),
            ]
        )
    else:
        print(f"Skipping flood: missing {flood_csv}")

    landslide_csv = DATASETS / "landslide" / "landslide.csv"
    if landslide_csv.exists():
        run(
            [
                sys.executable,
                str(ML / "landslide" / "train.py"),
                "--csv",
                str(landslide_csv),
                "--output",
                str(ASSETS / "landslide_model.tflite"),
            ]
        )
    else:
        print(f"Skipping landslide: missing {landslide_csv}")

    garbage_dataset = DATASETS / "garbage"
    if (garbage_dataset / "train").exists() and (garbage_dataset / "validation").exists():
        run(
            [
                sys.executable,
                str(ML / "garbage" / "train.py"),
                "--dataset",
                str(garbage_dataset),
                "--output",
                str(ASSETS / "garbage_model.tflite"),
            ]
        )
    else:
        print(f"Skipping garbage: missing {garbage_dataset}/train and validation")


if __name__ == "__main__":
    main()
