"""Train a tabular flood-risk classifier and export TensorFlow Lite.

CSV columns: rainfall_24h, water_level_m, drainage_percent, risk_label
Labels must be integers: 0 low, 1 medium, 2 high.
"""

import argparse
from pathlib import Path

import pandas as pd
import tensorflow as tf

FEATURES = ["rainfall_24h", "water_level_m", "drainage_percent"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--output", default=Path("flood_model.tflite"), type=Path)
    args = parser.parse_args()

    data = pd.read_csv(args.csv).dropna(subset=FEATURES + ["risk_label"])
    x = data[FEATURES].astype("float32").to_numpy()
    y = data["risk_label"].astype("int32").to_numpy()

    normalizer = tf.keras.layers.Normalization()
    normalizer.adapt(x)
    model = tf.keras.Sequential(
        [
            tf.keras.Input(shape=(len(FEATURES),)),
            normalizer,
            tf.keras.layers.Dense(24, activation="relu"),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(12, activation="relu"),
            tf.keras.layers.Dense(3, activation="softmax"),
        ]
    )
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(x, y, validation_split=0.2, epochs=60, batch_size=32)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    args.output.write_bytes(converter.convert())
    print(f"Exported {args.output}")


if __name__ == "__main__":
    main()
