# Training datasets

Place real labelled datasets here before training. Codex will not invent data.

Expected structure:

```text
datasets/
  elephant/
    data.yaml
    train/images/
    train/labels/
    valid/images/
    valid/labels/
    test/images/
    test/labels/
  flood/
    flood.csv
  landslide/
    landslide.csv
  garbage/
    train/<class_name>/*.jpg
    validation/<class_name>/*.jpg
```

CSV schemas:

```text
flood.csv:
rainfall_24h,water_level_m,drainage_percent,risk_label

landslide.csv:
rainfall_72h,slope_degrees,soil_moisture_percent,risk_label
```

`risk_label` must be:

- `0` low
- `1` medium
- `2` high

After datasets are added, run:

```powershell
& "C:\Users\sa\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m pip install ultralytics tensorflow kaggle pandas
& "C:\Users\sa\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" ml\train_all.py --epochs 50
```

Kaggle garbage dataset downloader:

```powershell
& "C:\Users\sa\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" ml\download_datasets.py --garbage
```
