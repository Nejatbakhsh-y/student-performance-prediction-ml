# Leakage-Decision Note

## Session Information

- Program: GSSRP 2026
- Project: Predicting Student Performance Using Machine Learning
- Session: 18 of 48
- Target variable: G3
- Variables under review: G1 and G2
- Dataset: **data/student-mat.csv**
- Complete observations: **395**
- Generated: **2026-07-14**

## 1. Decision Purpose

This note establishes how G1 and G2 will be handled when predicting the final
grade, G3.

The decision considers predictive accuracy, feature availability, prediction
timing, and practical intervention value.

## 2. Correlation Evidence

The Session 18 analysis produced the following Pearson correlations:

- Correlation between G1 and G3: **0.801**
- Correlation between G2 and G3: **0.905**
- Stronger prior-grade relationship: **G2 (0.905)**

The G1-G3 relationship is classified as **very strong**.

The G2-G3 relationship is classified as **very strong**.

These correlations show that G1 and G2 contain substantial predictive
information about G3. Correlation indicates association and does not establish
causation.

## 3. Data-Leakage Interpretation

Data leakage occurs when a model uses information that would not realistically
be available at the intended prediction time.

G1 and G2 are not automatically leakage variables in every context. They are
legitimate predictors when the model is used after those grades have been
recorded.

They are inappropriate for a beginning-of-course early-warning model because
they are unavailable at that prediction time. G2 may also become available too
late to allow meaningful early intervention.

The project will therefore use two separate modeling scenarios.

## 4. Scenario 1: Full-Information Model

### Decision

The full-information model will include G1 and G2.

### Purpose

Measure predictive performance after prior course grades are available.

### Expected Advantage

This model is expected to achieve higher predictive accuracy because G1 and G2
directly measure academic progress during the same course.

### Intended Uses

- Full-information benchmark
- Maximum predictive-performance assessment
- Measurement of the contribution of prior grades
- Late-stage student-risk prediction
- Final-exam preparation and late-course academic support

### Limitation

The model may provide limited early-warning value because much of the academic
term has passed before G1 and G2 become available.

It must not be presented as a beginning-of-course early-warning model.

## 5. Scenario 2: Early-Warning Model

### Decision

The early-warning model will exclude G1 and G2.

### Purpose

Identify students at risk before prior course grades become available.

### Eligible Predictors

The model may use early-available variables such as:

- Study time
- Previous failures
- Family support
- School support
- Travel time
- Internet access
- Educational aspirations
- Demographic characteristics
- Social and behavioral characteristics
- Other eligible early-available variables

Absence information may be used only when its measurement period is consistent
with the intended prediction time.

### Expected Advantage

Earlier predictions provide more time for tutoring, advising, attendance
support, study assistance, counseling, instructor outreach, and other academic
interventions.

### Limitation

The early-warning model is expected to have lower predictive accuracy because
it excludes two strong predictors of G3.

## 6. Scenario Comparison

| Criterion | Full-Information Model | Early-Warning Model |
|---|---|---|
| Includes G1 | Yes | No |
| Includes G2 | Yes | No |
| Prediction timing | After prior grades are available | Before prior grades are available |
| Expected accuracy | Higher | Lower |
| Expected prediction error | Lower | Higher |
| Time available for intervention | Less | More |
| Primary purpose | Maximum predictive performance | Early risk identification |
| Leakage treatment | Valid when timing is correctly defined | G1 and G2 excluded to match prediction timing |
| Main limitation | Limited early-warning value | Reduced statistical accuracy |

## 7. Evaluation Plan

The two scenarios will be trained and evaluated separately.

Where appropriate, both scenarios will use the same:

- Training and testing split
- Cross-validation procedure
- Model algorithms
- Random seed
- Preprocessing procedures
- Evaluation metrics

Regression performance will be evaluated using:

- Mean absolute error
- Mean squared error
- Root mean squared error
- R-squared

The comparison will also consider prediction timing, feature availability,
interpretability, intervention time, and operational usefulness.

The model with the highest statistical accuracy will not automatically be
treated as the most useful model.

## 8. Final Project Decision

The project will retain and report two separate modeling scenarios:

1. **Full-information scenario:** Include G1 and G2.
2. **Early-warning scenario:** Exclude G1 and G2.

The full-information model measures predictive performance after prior grades
are known.

The early-warning model evaluates whether student risk can be identified early
enough to support meaningful intervention.

The scenarios answer different research and operational questions and will be
reported separately.
