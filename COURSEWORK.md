# Alfa Community ML Coursework Map

## Selected problem

Predict community flood-risk level (low, medium, or high) from rainfall,
water level, and drainage effectiveness. The source data is the Kaggle India
Flood Risk dataset stored at `datasets/flood_raw/flood_risk_dataset_india.csv`.
The lecturer should approve this final problem statement and dataset before
submission.

## Reproduce the ML evidence

```powershell
python -m pip install -r ml/requirements-coursework.txt
python ml/prepare_risk_csvs.py
python ml/coursework_flood_pipeline.py
python ml/flood/train.py --csv datasets/flood/flood.csv --output assets/models/flood_model.tflite
```

The coursework pipeline produces the statistical summary, feature-distribution
chart, baseline comparison, tuned parameters, classification report, and
confusion matrix in `ml/artifacts/flood/`. It uses a fixed random seed,
stratified held-out test data, median imputation, scaling, two baseline
algorithms, and cross-validated hyperparameter search.

Latest held-out result: the baseline random forest reached 46.45% accuracy and
0.3871 macro-F1; tuning reached 41.90% accuracy and 0.4098 macro-F1. Tuning
improved balance across the three classes but reduced overall accuracy. This is
not production-quality performance. The strongest next step is to retain more
of the original Kaggle predictors and obtain authority-validated target labels,
rather than repeatedly tuning a model with only three lossy features.

## Mobile demonstration

Open **Flood Monitoring**, change all three forecast parameters, and tap
**Assess flood risk**. The screen shows loading/error states, the predicted
class and confidence, whether the output came from TFLite, and a persistent
history of recent predictions. This supplies the required input, result, and
historical-comparison flow without requiring network access.

## Important academic notes

- Describe this as multiclass risk prediction, not a time-series sales forecast.
- Report accuracy and macro-F1 because the target is categorical; RMSE, MAE,
  and R-squared are not appropriate classification metrics.
- Explain that `prepare_risk_csvs.py` derives the three risk levels from source
  fields. This label design is a limitation and should be validated with a
  domain expert before real emergency use.
- Add the exact Kaggle dataset URL, team roles, screenshots, generated metric
  values, and personal reflection to the final report.
