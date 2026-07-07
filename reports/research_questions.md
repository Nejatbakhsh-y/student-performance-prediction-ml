# Research Questions and Hypotheses

## Six Research Questions

| # | Research Question | Type | Connected Hypothesis |
|---|---|---|---|
| RQ1 | Which student-related variables are most strongly associated with academic performance? | Factor analysis | H4 |
| RQ2 | Which machine-learning algorithm gives the best predictive performance for final-grade prediction? | Prediction | H1 |
| RQ3 | Do ensemble models, such as Random Forest and Gradient Boosting, outperform simpler models, such as Linear or Logistic Regression and Decision Trees? | Prediction | H1 |
| RQ4 | How does performance change when prior grades G1 and G2 are removed from the feature set? | Intervention / prediction comparison | H2, H3 |
| RQ5 | Which model best balances accuracy, interpretability, robustness, and educational usefulness? | Prediction / model evaluation | H3, H4 |
| RQ6 | Can prompt-engineered workflows improve clarity, reproducibility, and documentation quality? | Process | H5 |

## Five Hypotheses

| # | Hypothesis | Answers / Connects To |
|---|---|---|
| H1 | Ensemble tree-based models, especially Random Forest and Gradient Boosting, will outperform Linear Regression and Decision Trees. | RQ2, RQ3 |
| H2 | Models that include prior grades G1 and G2 will perform substantially better than models that exclude them. | RQ4 |
| H3 | The early-warning model, which excludes G1 and G2, will be less accurate but more useful for intervention decisions. | RQ4, RQ5 |
| H4 | Feature importance will highlight prior achievement, failures, study time, attendance, and support variables. | RQ1, RQ5 |
| H5 | Prompt-engineered documentation will improve students' ability to explain methods and produce a reproducible report. | RQ6 |

## Two-Scenario Design

This project uses two modeling scenarios: a full-information scenario and an early-warning scenario.

In the full-information scenario, models may use G1 and G2 to predict G3. This usually improves predictive performance because G1 and G2 are closely related to the final grade.

In the early-warning scenario, G1 and G2 are removed from the feature set. This may reduce accuracy, but it makes the model more realistic for early intervention by avoiding reliance on information that may arrive too late to help students.

## Shared Research Questions Activity Table

| Pair | Assigned RQ | Refined Measurable Sentence | Target Variable | Predictor(s) | Task Type | Matching Hypothesis | Category | G1/G2 Leakage? |
|---|---|---|---|---|---|---|---|---|
| Pair 1 | RQ1 | | | | | | | |
| Pair 2 | RQ2 | | | | | | | |
| Pair 3 | RQ3 | | | | | | | |
| Pair 4 | RQ4 | | | | | | | |
| Pair 5 | RQ5 | | | | | | | |
| Pair 6 | RQ6 | | | | | | | |