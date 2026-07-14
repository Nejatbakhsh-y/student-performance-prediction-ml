# Session 17: Correlation Analysis Note

## Purpose

This analysis examines Pearson correlations among the numeric variables in
the student-performance dataset, with particular attention to the final-grade
target, G3.

- **Dataset used:** `data/student-mat.csv`
- **Dataset rows:** 395
- **Numeric variables analyzed:** 16

## Strongest Correlates of G3

| Rank | Feature | Correlation with G3 | Direction |
|---:|---|---:|---|
| 1 | G2 | 0.905 | Positive |
| 2 | G1 | 0.801 | Positive |
| 3 | failures | -0.360 | Negative |
| 4 | Medu | 0.217 | Positive |
| 5 | age | -0.162 | Negative |

The strongest predictor correlation with G3 is **G2**,
with a Pearson correlation of **0.905**
(positive).

## G1 and G2 Highlight

| Feature | Meaning | Correlation with G3 | Direction |
|---|---|---:|---|
| G1 | First-period grade | 0.801 | Positive |
| G2 | Second-period grade | 0.905 | Positive |

G1 represents the first-period grade, G2 represents the second-period grade,
and G3 represents the final grade. G1 and G2 require special attention
because they are earlier measurements of the same academic-performance
process represented by G3.

The acceptability of G1 and G2 depends on the intended prediction time.
They may be valid predictors in a full-information model when those grades
are already known. They would create an unrealistic prediction setting or
temporal leakage in an early-warning model intended to make predictions
before G1 or G2 become available.

## Interpretation

The heatmap shows the direction and strength of linear relationships among
the numeric variables. Positive correlations indicate that higher feature
values tend to occur with higher G3 values. Negative correlations indicate
that higher feature values tend to occur with lower G3 values.

The strong relationships among G1, G2, and G3 can substantially improve
apparent model performance. However, strong predictive performance may be
misleading when the predictors would not have been available at the intended
prediction time.

Because G1 and G2 are prior grades, a model may depend primarily on recent
academic outcomes instead of earlier behavioral, attendance, family,
support, or demographic information.

## Recommendation

The project should evaluate two modeling scenarios:

1. **Full-information model:** Include G1 and G2 when predictions are made
   after both earlier grades are available.
2. **Early-warning model:** Exclude G1 and G2 when predictions are intended
   to identify at-risk students before those grades are recorded.

Comparing these scenarios will show how much predictive performance depends
on prior-grade information and whether the model remains useful under a
realistic early-warning deployment design.

## Leakage Concern

Temporal leakage occurs when a model uses information that would not have
been available when the prediction was supposed to be made. Including G1 or
G2 in an early-warning model could inflate evaluation metrics and produce an
overly optimistic estimate of practical model performance.

## Limitation

Correlation measures the direction and strength of a linear association.
It does not establish causation. A strong correlation between a feature and
G3 does not prove that the feature causes the final grade to increase or
decrease.

## Artifact

The corresponding visualization is stored at:

`figures/correlation_heatmap.png`
