"""Create train/validation folders from the downloaded garbage dataset."""

from __future__ import annotations

import argparse
import os
import random
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "datasets" / "garbage_raw" / "standardized_256"
TARGET = ROOT / "datasets" / "garbage"


def link_or_copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
      os.link(source, target)
    except OSError:
      shutil.copy2(source, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validation-ratio", default=0.15, type=float)
    parser.add_argument("--seed", default=42, type=int)
    args = parser.parse_args()

    if not SOURCE.exists():
        raise FileNotFoundError(f"Missing source dataset: {SOURCE}")

    if TARGET.exists():
        shutil.rmtree(TARGET)

    rng = random.Random(args.seed)
    for class_dir in sorted(path for path in SOURCE.iterdir() if path.is_dir()):
        images = sorted(
            file
            for file in class_dir.iterdir()
            if file.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        )
        rng.shuffle(images)
        validation_count = max(1, int(len(images) * args.validation_ratio))
        validation = set(images[:validation_count])
        for image in images:
            split = "validation" if image in validation else "train"
            link_or_copy(image, TARGET / split / class_dir.name / image.name)

    print(f"Prepared dataset at {TARGET}")


if __name__ == "__main__":
    main()
