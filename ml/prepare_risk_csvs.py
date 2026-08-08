"""Prepare app-compatible flood and landslide CSV files from downloaded datasets."""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]


def prepare_flood() -> None:
    source = ROOT / "datasets" / "flood_raw" / "flood_risk_dataset_india.csv"
    target = ROOT / "datasets" / "flood" / "flood.csv"
    df = pd.read_csv(source)
    rainfall = df["Rainfall (mm)"]
    water = df["Water Level (m)"]
    historical = df["Historical Floods"]
    occurred = df["Flood Occurred"]

    medium = (
        (rainfall >= rainfall.quantile(0.70))
        | (water >= water.quantile(0.70))
        | (historical == 1)
    )
    risk = pd.Series(0, index=df.index)
    risk[medium] = 1
    risk[occurred == 1] = 2

    out = pd.DataFrame(
        {
            "rainfall_24h": rainfall,
            "water_level_m": water,
            "drainage_percent": (100 - df["Infrastructure"] * 35).clip(0, 100),
            "risk_label": risk,
        }
    )
    target.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(target, index=False)
    print(f"Wrote {target} with labels {out['risk_label'].value_counts().to_dict()}")


def prepare_landslide() -> None:
    source = ROOT / "datasets" / "landslide_raw" / "wsn_landslide_data.csv"
    target = ROOT / "datasets" / "landslide" / "landslide.csv"
    df = pd.read_csv(source)
    rainfall = df["Rainfall_3Day"]
    slope = df["Slope_Angle"]
    moisture = df["Soil_Moisture_Content"] * 100
    label = df["Label"]

    medium = (
        (rainfall >= rainfall.quantile(0.70))
        | (slope >= slope.quantile(0.70))
        | (moisture >= moisture.quantile(0.70))
    )
    risk = pd.Series(0, index=df.index)
    risk[medium] = 1
    risk[label == 1] = 2

    out = pd.DataFrame(
        {
            "rainfall_72h": rainfall,
            "slope_degrees": slope,
            "soil_moisture_percent": moisture,
            "risk_label": risk,
        }
    )
    target.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(target, index=False)
    print(f"Wrote {target} with labels {out['risk_label'].value_counts().to_dict()}")


def main() -> None:
    prepare_flood()
    prepare_landslide()


if __name__ == "__main__":
    main()
