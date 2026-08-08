"""Train and export a small elephant detector for the Flutter app.

Run this in Google Colab or a Python environment with a GPU:
    pip install ultralytics
    python train_elephant_detector.py --data /path/to/data.yaml
"""

import argparse
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--epochs", default=50, type=int)
    parser.add_argument("--image-size", default=640, type=int)
    parser.add_argument("--model", default="yolo11n.pt")
    parser.add_argument("--name", default="alfa_elephant_detector")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.data.exists():
        raise FileNotFoundError(f"Dataset config not found: {args.data}")

    model = YOLO(args.model)
    result = model.train(
        data=str(args.data),
        epochs=args.epochs,
        imgsz=args.image_size,
        project="runs/elephant",
        name=args.name,
        patience=12,
        plots=True,
    )

    best_model = YOLO(Path(result.save_dir) / "weights" / "best.pt")
    best_model.val(data=str(args.data))
    best_model.export(format="tflite", imgsz=args.image_size)


if __name__ == "__main__":
    main()
