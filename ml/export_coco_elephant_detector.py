"""Export a pretrained COCO YOLO model that already includes the elephant class.

This is not a Sri Lanka custom-trained detector. It is a practical baseline
until a labelled local elephant dataset is available.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "models"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="yolo11n.pt")
    args = parser.parse_args()

    ASSETS.mkdir(parents=True, exist_ok=True)
    model = YOLO(args.model)
    exported = Path(model.export(format="tflite", imgsz=640))
    target = ASSETS / "elephant_model.tflite"
    target.write_bytes(exported.read_bytes())
    print(f"Exported baseline detector to {target}")
    print("Important: Flutter YOLO output decoding still must match this export.")


if __name__ == "__main__":
    main()
