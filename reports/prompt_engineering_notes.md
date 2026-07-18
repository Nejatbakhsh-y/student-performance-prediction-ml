# Session 45: AI-Assisted Research Summary

## Summary

This study evaluates interpretable machine-learning approaches for predicting
student academic success using the public UCI student-performance data. The
workflow compares regression models for numerical grade prediction and
classification models for identifying students who may need additional support.
All reported winners below were selected from the repository's saved result
tables rather than invented examples.

The best saved regression model is **Bagging Regressor**, selected because
it has the lowest reported RMSE of **3.7619**. Additional regression metrics are MAE = 2.9887, R-squared = 0.3098.
The best saved classification model is **SVM**, selected
because it has the highest reported F1 score of
**0.8785**. Additional classification metrics are accuracy = 0.8354, recall = 0.9038, ROC AUC = 0.9387.

The predictor ranking is documented in figures/feature_importance.png. The figure is treated as evidence of predictive association, not causation.

## Interpretation

The model rankings describe predictive performance on the study's evaluation
design; they do not demonstrate that any predictor causes a student's outcome.
Feature importance is used to explain what the fitted model relied upon, but it
must be interpreted cautiously when predictors are correlated.

The full-information model uses later academic information, while the early-warning design excludes G1 and G2 to reduce target leakage and support earlier intervention. No unsupported numerical gap is stated.

The full-information and early-warning models answer different operational
questions. A full-information model may achieve stronger numerical performance
because it can use later-grade information. The early-warning model is more
appropriate for timely support because it excludes later-grade variables such
as G1 and G2. A lower early-warning score therefore does not automatically make
that model less useful or less responsible.

## Limitation

The dataset represents a limited population and may not generalize to every
school, course, year, or student group. The results are observational and do not
support causal conclusions. Performance can also change with the train/test
split, preprocessing choices, class balance, model tuning, and metric selection.
Feature-importance rankings can be unstable when predictors are correlated.
Sensitive educational decisions should not be based on a model score alone.

## Recommendation

Use the model only as a human-supervised decision-support tool for offering
resources and timely assistance. Do not use it for surveillance, punishment,
automatic labeling, or denial of educational opportunities. Monitor performance
and error rates across relevant student groups, document changes to data and
models, and provide a process for educators and students to question or correct
the information used.

For deployment-oriented early intervention, prefer the leakage-aware
early-warning feature set even when the full-information model reports a better
score. Interpretability, prediction timing, fairness, privacy, and the
availability of a beneficial intervention should be considered together with
accuracy.

## Human-Review Statement

The original AI-assisted wording was checked against the repository evidence
listed below. Model names and metric values were taken directly from saved
tables. Unsupported predictor claims were omitted when machine-readable evidence
was unavailable. Causal and overly certain language was removed, and the
full-information scenario was distinguished from the leakage-aware early-warning
scenario. The summary supports human judgment and does not replace it.

## Correction Log

- Verified the regression winner using the lowest saved RMSE.
- Verified the classification winner using the highest saved F1 score.
- Treated feature importance as predictive association rather than causation.
- Distinguished later-information performance from responsible early warning.
- Added generalizability, fairness, privacy, and human-oversight limitations.
- Removed unsupported certainty and avoided invented numerical results.

## Evidence Used

- `reports/regression_leaderboard.csv`
- `reports/classification_leaderboard.csv`
- `figures/feature_importance.png`

## Reflection

The AI-assisted summary required correction wherever model results could have
been overstated, feature importance could have been mistaken for causation, or
the full-information model could have been confused with the early-warning
model. This demonstrates that AI should be used as a drafting assistant rather
than an authoritative source. Important claims must be checked against saved
evidence, and educational recommendations require responsible human oversight.
