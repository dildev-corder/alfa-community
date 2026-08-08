"""Train a waste image classifier and export TensorFlow Lite.

Dataset layout:
dataset/train/<class_name>/*.jpg
dataset/validation/<class_name>/*.jpg
"""

import argparse
import json
from pathlib import Path

import tensorflow as tf

IMAGE_SIZE = (224, 224)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, type=Path)
    parser.add_argument("--output", default=Path("garbage_model.tflite"), type=Path)
    args = parser.parse_args()

    train = tf.keras.utils.image_dataset_from_directory(
        args.dataset / "train", image_size=IMAGE_SIZE, batch_size=32
    )
    validation = tf.keras.utils.image_dataset_from_directory(
        args.dataset / "validation", image_size=IMAGE_SIZE, batch_size=32
    )
    class_names = train.class_names

    base = tf.keras.applications.MobileNetV2(
        input_shape=(*IMAGE_SIZE, 3), include_top=False, weights="imagenet"
    )
    base.trainable = False
    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3))
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(len(class_names), activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    model.fit(train, validation_data=validation, epochs=15)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    args.output.write_bytes(converter.convert())
    args.output.with_suffix(".labels.json").write_text(json.dumps(class_names, indent=2))
    print(f"Exported {args.output} with labels {class_names}")


if __name__ == "__main__":
    main()
