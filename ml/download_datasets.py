"""Download supported public datasets.

Requires a Kaggle API token at:
    C:\\Users\\<you>\\.kaggle\\kaggle.json

Currently supported:
    - Garbage classification v2: sumn2u/garbage-classification-v2

Flood and landslide are intentionally not auto-downloaded because the app's
tabular models need trustworthy feature/label schemas. Add validated CSVs under
datasets/flood/flood.csv and datasets/landslide/landslide.csv.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATASETS = ROOT / "datasets"


def run(command: list[str]) -> None:
    print("$", " ".join(command), flush=True)
    subprocess.run(command, check=True, cwd=ROOT)


def download_kaggle(slug: str, target: Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    run(
        [
            sys.executable,
            "-m",
            "kaggle",
            "datasets",
            "download",
            "-d",
            slug,
            "-p",
            str(target),
            "--unzip",
        ]
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--garbage", action="store_true")
    args = parser.parse_args()

    if shutil.which("kaggle") is None:
        print("Kaggle CLI not on PATH. Trying `python -m kaggle` anyway.")

    if args.garbage:
        download_kaggle(
            "sumn2u/garbage-classification-v2",
            DATASETS / "garbage_raw",
        )
        print(
            "Downloaded garbage dataset. Arrange or split it into "
            "datasets/garbage/train and datasets/garbage/validation before training."
        )
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
