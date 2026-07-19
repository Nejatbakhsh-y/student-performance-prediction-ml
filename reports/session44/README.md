# Session 44: Full-Information vs Early-Warning Comparison

## Objective

This deliverable compares two 300-tree Random Forest regression models for predicting final grade `G3` on the same train-test split.

- Full-information model: includes `G1` and `G2`.
- Early-warning model: excludes `G1` and `G2`.
- Training students: 316.
- Testing students: 79.
- Random state: 42.

## Actual results

| Model | MAE | RMSE | R2 |
| --- | ---: | ---: | ---: |
| Full-information | 1.1863 | 2.0023 | 0.8045 |
| Early-warning | 3.0095 | 3.7613 | 0.3100 |

The more accurate model by RMSE is **Full-information**. The early-warning model's RMSE was 1.7590 grade points higher than the full-information model, a 87.85% increase.

## Leakage-aware conclusion

`G1` and `G2` can improve accuracy, but they create timing-related leakage if they are unavailable at the intended intervention time. The early-warning result is therefore the appropriate estimate for a genuinely early support system, even when its accuracy is lower. Predictions are intended to support human review and student assistance, not automatic or punitive decisions.

## Artifacts

- `session44_leakage_aware_comparison_note.txt`: full interpretation and conclusion.
- `session44_full_vs_early_metrics.csv`: reproducible metric table.
- `session44_full_vs_early_comparison.png`: direct MAE, RMSE, and R2 comparison.
- `session44_actual_vs_predicted_comparison.png`: actual-versus-predicted plots.

The repository-root PowerShell file `08_session44_github_deliverable.ps1` reproduces the complete local analysis and GitHub delivery workflow.
