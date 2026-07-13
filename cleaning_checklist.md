# Cleaning Checklist

## Project

Student Performance Prediction Using Machine Learning

## Session

Session 10: Missing Values and Duplicates

## Purpose

This checklist documents the data-quality checks completed before preprocessing, feature engineering, and model development. The dataset was checked for missing values and duplicate rows so downstream machine-learning models are not affected by silent data-quality problems.

## Dataset Reviewed

- Number of rows: 395
- Number of columns: 33

## 1. Missing Values Check

### Python Code Used

```python
print("Missing per column:")
print(df.isna().sum())
```

### Missing Values by Column

| Column | Missing Count | Missing Percent |
|---|---:|---:|
| school | 0 | 0% |
| sex | 0 | 0% |
| age | 0 | 0% |
| address | 0 | 0% |
| famsize | 0 | 0% |
| Pstatus | 0 | 0% |
| Medu | 0 | 0% |
| Fedu | 0 | 0% |
| Mjob | 0 | 0% |
| Fjob | 0 | 0% |
| reason | 0 | 0% |
| guardian | 0 | 0% |
| traveltime | 0 | 0% |
| studytime | 0 | 0% |
| failures | 0 | 0% |
| schoolsup | 0 | 0% |
| famsup | 0 | 0% |
| paid | 0 | 0% |
| activities | 0 | 0% |
| nursery | 0 | 0% |
| higher | 0 | 0% |
| internet | 0 | 0% |
| romantic | 0 | 0% |
| famrel | 0 | 0% |
| freetime | 0 | 0% |
| goout | 0 | 0% |
| Dalc | 0 | 0% |
| Walc | 0 | 0% |
| health | 0 | 0% |
| absences | 0 | 0% |
| G1 | 0 | 0% |
| G2 | 0 | 0% |
| G3 | 0 | 0% |

### Result

The total number of missing values is **0**.

### Decision

No imputation is needed.

### Reason

Every column has zero missing values. Applying imputation would be unnecessary and could introduce artificial information.

## 2. Total Missing Values Check

### Python Code Used

```python
total_missing = df.isna().sum().sum()
print("Total missing values:", total_missing)
```

### Result

The total missing-value count is **0**.

## 3. Duplicate Rows Check

### Python Code Used

```python
duplicate_rows = df.duplicated().sum()
print("Duplicate rows:", duplicate_rows)
```

### Result

The number of duplicate rows is **0**.

### Decision

No duplicate rows need to be removed.

### Reason

The duplicate-row count is zero, so repeated records will not receive unintended additional influence.

## 4. Cleaning Decision Summary

| Data-Quality Issue | Result | Decision |
|---|---:|---|
| Missing values | 0 | No imputation is needed. |
| Duplicate rows | 0 | No duplicate rows need to be removed. |

## 5. Prompt-Engineered Explanation

### Summary

The dataset contains 0 missing values and 0 duplicate rows.

### Interpretation

Every column has zero missing values. Applying imputation would be unnecessary and could introduce artificial information. The duplicate-row count is zero, so repeated records will not receive unintended additional influence.

### Recommendation

No cleaning action is required for missing values or duplicate rows. The dataset is ready for preprocessing and feature engineering.

## 6. Student Activity Result

The UCI Student Performance dataset was checked using `df.isna().sum()`, `df.isna().sum().sum()`, and `df.duplicated().sum()`.

- Total missing values: 0
- Duplicate rows: 0

These results provide the evidence supporting the Session 10 cleaning decisions.

## 7. Reflection Question

### Question

Why is documenting "no cleaning needed" just as important as documenting cleaning steps?

### Answer

Documenting the result confirms that the dataset was actually checked for data-quality problems. It shows why imputation or duplicate removal was or was not performed. This improves reproducibility because another researcher can identify the evidence supporting the cleaning decision. It also improves transparency by demonstrating that the decision was based on the dataset rather than an assumption.

## 8. Final Recommendation

No cleaning action is required for missing values or duplicate rows. The dataset is ready for preprocessing and feature engineering.
