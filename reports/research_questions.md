# Session 2: Research Questions and Hypotheses

## Purpose

This file records the finalized research questions and hypotheses for the student performance prediction project.

## Research Questions

| No. | Research Question | Target Variable | Predictor Variables | Task Type | Category | G1/G2 Leakage Risk |
|---|---|---|---|---|---|---|
| RQ1 | Which machine learning algorithm predicts final student performance most accurately? | Final grade or student success | Student, family, school, and study-related variables | Regression or classification | Prediction | Depends on feature set |
| RQ2 | How strongly do prior grades predict final student performance? | Final grade or student success | G1 and G2 prior grades | Regression or classification | Prediction | High |
| RQ3 | How are study time and absences related to final performance? | Final grade or student success | Study time and absences | Regression or classification | Factor analysis | Low |
| RQ4 | Do family and background variables improve prediction performance? | Final grade or student success | Parent education, family support, internet access, and related factors | Regression or classification | Factor analysis | Low |
| RQ5 | Can early-warning models identify students at risk before final grades are available? | At-risk status or final success | Early-available student and background variables | Classification | Prediction / intervention | Low if G1 and G2 are excluded |
| RQ6 | Which variables are most important for explaining model predictions? | Final grade or student success | All selected model features | Regression or classification | Interpretation | Depends on feature set |

## Hypotheses

| No. | Hypothesis | Connected Research Question |
|---|---|---|
| H1 | Models that include prior grades will predict final performance more accurately than models that exclude prior grades. | RQ1, RQ2 |
| H2 | Higher study time will be associated with stronger final performance. | RQ3 |
| H3 | More absences will be associated with weaker final performance. | RQ3 |
| H4 | Family and background variables will add useful predictive information beyond basic school variables. | RQ4 |
| H5 | Early-warning models can identify at-risk students before final grades are available, but with lower accuracy than full-information models. | RQ5 |

## Two-Scenario Design

This project will use two modeling scenarios.

The first scenario is the full-information model. This model may include prior grade variables such as G1 and G2. It is useful for understanding the strongest possible prediction performance, but it may include information that is too close to the final outcome.

The second scenario is the early-warning model. This model excludes G1 and G2 so that predictions are based only on information available earlier in the student experience. This design is more realistic for identifying students who may need support before the final grade is known.

## Notes on Target Leakage

Target leakage occurs when a model uses information that would not realistically be available at the time of prediction. In this project, G1 and G2 may create leakage if the goal is to predict final performance early. Therefore, the project separates full-information prediction from early-warning prediction.