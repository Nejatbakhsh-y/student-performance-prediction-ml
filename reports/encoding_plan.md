# Encoding Plan

## Project

Predicting Student Academic Success Using Interpretable Machine Learning, Public Educational Data, and Prompt-Engineered Research Workflows

## Session

Session 11: Categorical Variables

## Purpose

This plan documents how categorical variables will be converted into numeric features before machine-learning modeling.

## Encoding Rules

- Use binary 0/1 encoding for categorical variables with exactly two categories.
- Use one-hot encoding for nominal variables with more than two unordered categories.
- Keep numeric ordinal variables as ordered numeric features.
- Do not assign arbitrary numeric rankings to nominal categories.
- Review any future high-cardinality variable before one-hot encoding.

## Categorical Variable Encoding Plan

| Column | Example values | Variable type | Encoding method | Reason |
|---|---|---|---|---|
| school | GP, MS | Binary nominal | Binary encoding | Two unordered school categories |
| sex | F, M | Binary nominal | Binary encoding | Two categories |
| address | U, R | Binary nominal | Binary encoding | Urban and rural are labels |
| famsize | GT3, LE3 | Binary nominal | Binary encoding | Two family-size groups |
| Pstatus | A, T | Binary nominal | Binary encoding | Two parent-status categories |
| Mjob | teacher, health, services, other, at_home | Nominal | One-hot encoding | Job categories have no natural order |
| Fjob | teacher, health, services, other, at_home | Nominal | One-hot encoding | Job categories have no natural order |
| reason | course, home, reputation, other | Nominal | One-hot encoding | School-choice reasons are unordered |
| guardian | mother, father, other | Nominal | One-hot encoding | Guardian categories have no ranking |
| schoolsup | yes, no | Binary | Binary encoding | Yes/no variable |
| famsup | yes, no | Binary | Binary encoding | Yes/no variable |
| paid | yes, no | Binary | Binary encoding | Yes/no variable |
| activities | yes, no | Binary | Binary encoding | Yes/no variable |
| nursery | yes, no | Binary | Binary encoding | Yes/no variable |
| higher | yes, no | Binary | Binary encoding | Yes/no variable |
| internet | yes, no | Binary | Binary encoding | Yes/no variable |
| romantic | yes, no | Binary | Binary encoding | Yes/no variable |

Suggested yes/no mapping:

```text
no = 0
yes = 1
```

## Numeric Ordinal Variables

The following variables are already numeric and have meaningful order, so they should remain numeric:

- Medu
- Fedu
- traveltime
- studytime
- failures
- famrel
- freetime
- goout
- Dalc
- Walc
- health

## High-Cardinality Check

The dataset has no major high-cardinality categorical variables. `Mjob`, `Fjob`, `reason`, and `guardian` contain more than two categories, but their category counts are small enough for one-hot encoding.

## Why Ordinal Encoding Can Be Misleading

Ordinal encoding is misleading when categories are nominal rather than genuinely ordered. For example, encoding `Mjob` as `teacher = 1`, `health = 2`, `services = 3`, `other = 4`, and `at_home = 5` would create a false ranking and false numeric distances.

Models such as linear regression, logistic regression, KNN, SVM, and neural networks may interpret those values as meaningful magnitudes or distances. One-hot encoding is safer for unordered categories.

## Final Recommendation

1. Use binary encoding for all two-category variables.
2. Use one-hot encoding for `Mjob`, `Fjob`, `reason`, and `guardian`.
3. Keep numeric ordinal variables as ordered numeric features.
4. Avoid ordinal encoding for unordered categories.
5. Fit encoders using training data only and apply the fitted encoders consistently to validation and test data.

## Reflection Question

Ordinal encoding misleads a model when categories do not have a real order or when the distances between category levels are not meaningful. Nominal categories should therefore use binary or one-hot encoding rather than arbitrary integer codes.
