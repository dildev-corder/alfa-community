"""Reproducible coursework evaluation for the Alfa flood-risk model.

Runs EDA, stratified train/validation/test splitting, two baseline models,
RandomizedSearchCV tuning, held-out evaluation, and chart/report generation.
The final mobile TFLite export remains in ``ml/flood/train.py``.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    accuracy_score,
    classification_report,
    f1_score,
)
from sklearn.model_selection import RandomizedSearchCV, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

FEATURES = ["rainfall_24h", "water_level_m", "drainage_percent"]
TARGET = "risk_label"
SEED = 42


def make_pipeline(model: object) -> Pipeline:
    numeric = Pipeline(
        [("imputer", SimpleImputer(strategy="median")), ("scale", StandardScaler())]
    )
    return Pipeline(
        [("preprocess", ColumnTransformer([("numeric", numeric, FEATURES)])), ("model", model)]
    )


def metrics(model: Pipeline, x: pd.DataFrame, y: pd.Series) -> dict[str, float]:
    predicted = model.predict(x)
    return {
        "accuracy": round(float(accuracy_score(y, predicted)), 4),
        "macro_f1": round(float(f1_score(y, predicted, average="macro")), 4),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("datasets/flood/flood.csv"))
    parser.add_argument("--output", type=Path, default=Path("ml/artifacts/flood"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    data = pd.read_csv(args.csv)
    missing = sorted(set(FEATURES + [TARGET]) - set(data.columns))
    if missing:
        raise ValueError(f"Dataset is missing columns: {missing}")
    data[FEATURES] = data[FEATURES].apply(pd.to_numeric, errors="coerce")
    data = data.dropna(subset=[TARGET])

    summary = {
        "rows": len(data),
        "columns": len(data.columns),
        "missing_values": data[FEATURES + [TARGET]].isna().sum().to_dict(),
        "class_distribution": data[TARGET].value_counts().sort_index().to_dict(),
        "statistics": data[FEATURES].describe().round(3).to_dict(),
    }
    (args.output / "eda_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    data[FEATURES].hist(figsize=(10, 3.5), bins=25)
    plt.tight_layout()
    plt.savefig(args.output / "feature_distributions.png", dpi=160)
    plt.close()

    x_train_val, x_test, y_train_val, y_test = train_test_split(
        data[FEATURES], data[TARGET], test_size=0.2, random_state=SEED, stratify=data[TARGET]
    )
    x_train, x_validation, y_train, y_validation = train_test_split(
        x_train_val, y_train_val, test_size=0.25, random_state=SEED, stratify=y_train_val
    )

    candidates = {
        "logistic_regression": make_pipeline(LogisticRegression(max_iter=1000, random_state=SEED)),
        "random_forest": make_pipeline(RandomForestClassifier(random_state=SEED)),
    }
    results: dict[str, dict[str, float]] = {}
    for name, candidate in candidates.items():
        candidate.fit(x_train, y_train)
        results[name] = metrics(candidate, x_validation, y_validation)

    search = RandomizedSearchCV(
        candidates["random_forest"],
        {
            "model__n_estimators": [100, 200, 300, 500],
            "model__max_depth": [None, 8, 16, 24],
            "model__min_samples_split": [2, 5, 10],
            "model__class_weight": [None, "balanced"],
        },
        n_iter=12,
        scoring="f1_macro",
        cv=5,
        random_state=SEED,
        n_jobs=-1,
    )
    search.fit(x_train_val, y_train_val)
    tuned = search.best_estimator_
    baseline_test = make_pipeline(RandomForestClassifier(random_state=SEED))
    baseline_test.fit(x_train_val, y_train_val)
    results["baseline_random_forest_test"] = metrics(baseline_test, x_test, y_test)
    results["tuned_random_forest_test"] = metrics(tuned, x_test, y_test)
    results["best_parameters"] = search.best_params_
    (args.output / "model_results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")

    predicted = tuned.predict(x_test)
    (args.output / "classification_report.txt").write_text(
        classification_report(y_test, predicted, target_names=["low", "medium", "high"]),
        encoding="utf-8",
    )
    ConfusionMatrixDisplay.from_predictions(
        y_test, predicted, display_labels=["Low", "Medium", "High"], cmap="Blues"
    )
    plt.title("Tuned random forest: held-out test set")
    plt.tight_layout()
    plt.savefig(args.output / "confusion_matrix.png", dpi=160)
    plt.close()
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
