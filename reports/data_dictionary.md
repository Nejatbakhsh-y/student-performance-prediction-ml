# Data Dictionary

## Project

Student Performance Prediction Using Machine Learning

## Purpose

This data dictionary documents the variables used in the student performance dataset. The variables are organized into demographic, social, school-related, and academic feature groups.

## Summary

The dataset contains student background information, family and social information, school-related behaviors, health and attendance information, and academic performance variables.

The final-grade variable `G3` can serve as the primary prediction target. The variables `G1` and `G2` require special consideration because they may create target leakage in an early-warning prediction model.

## 1. Demographic Variables

| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| `school` | Student's school. | object | 0 |
| `sex` | Student's reported sex. | object | 0 |
| `age` | Student's age in years. | int64 | 0 |
| `address` | Student's home address category, such as urban or rural. | object | 0 |

## 2. Social Variables

| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| `famsize` | Student's family-size category. | object | 0 |
| `Pstatus` | Parent cohabitation status. | object | 0 |
| `Medu` | Mother's education level. | int64 | 0 |
| `Fedu` | Father's education level. | int64 | 0 |
| `Mjob` | Mother's occupation category. | object | 0 |
| `Fjob` | Father's occupation category. | object | 0 |
| `guardian` | Student's primary guardian. | object | 0 |
| `famrel` | Student's rating of family-relationship quality. | int64 | 0 |
| `freetime` | Amount of free time available after school. | int64 | 0 |
| `goout` | Frequency of going out with friends. | int64 | 0 |
| `Dalc` | Workday alcohol-consumption category. | int64 | 0 |
| `Walc` | Weekend alcohol-consumption category. | int64 | 0 |
| `romantic` | Whether the student reports being in a romantic relationship. | object | 0 |
| `health` | Student's reported current health-status category. | int64 | 0 |

## 3. School-Related Variables

| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| `reason` | Primary reason for selecting the school. | object | 0 |
| `traveltime` | Travel-time category from home to school. | int64 | 0 |
| `studytime` | Weekly study-time category. | int64 | 0 |
| `schoolsup` | Whether the student receives additional school support. | object | 0 |
| `famsup` | Whether the student receives family educational support. | object | 0 |
| `paid` | Whether the student receives additional paid classes. | object | 0 |
| `activities` | Whether the student participates in extracurricular activities. | object | 0 |
| `nursery` | Whether the student attended nursery school. | object | 0 |
| `higher` | Whether the student intends to pursue higher education. | object | 0 |
| `internet` | Whether the student has internet access at home. | object | 0 |
| `absences` | Number of recorded school absences. | int64 | 0 |

## 4. Academic Variables

| Variable | Description | Data Type | Missing Values |
|---|---|---:|---:|
| `failures` | Number of previous class failures. | int64 | 0 |
| `G1` | First-period academic grade. | int64 | 0 |
| `G2` | Second-period academic grade. | int64 | 0 |
| `G3` | Final academic grade and primary candidate target variable. | int64 | 0 |

## Interpretation Notes

The demographic variables describe relatively stable student-background characteristics.

The social variables describe family structure, parental education, parental occupations, relationships, social behavior, and health-related information.

The school-related variables describe study habits, educational support, extracurricular engagement, school access, internet access, and attendance.

The academic variables describe previous failures and current academic performance. `G3` represents the final grade and can serve as the primary prediction target.

## Behavioral Versus Demographic Variables

Demographic variables describe characteristics such as age, sex, address type, and family background. These characteristics are generally not directly controlled by the student.

Behavioral variables describe actions, habits, attendance patterns, social behavior, and academic behavior. Examples include `studytime`, `activities`, `goout`, `Dalc`, `Walc`, `absences`, and `failures`.

This distinction matters because demographic variables can introduce fairness and equity concerns. Behavioral variables are generally more actionable and can support interventions such as tutoring, attendance monitoring, academic advising, and study-skills programs.

## Modeling Note

For a full-information prediction model, `G1` and `G2` may be used as predictors of `G3`.

For an early-warning prediction model, `G1` and `G2` should normally be excluded because they may create target leakage. An early-warning model should use only information that would be available at the intended prediction time.

Demographic variables should be evaluated carefully for fairness, disparate impact, and interpretability before being used in operational predictions.

## Recommendation

Use this data dictionary as the official documentation for the dataset before feature engineering and model development.

Before training a model:

1. Confirm that `G3` is the intended prediction target.
2. Define whether the project is an early-warning or full-information prediction task.
3. Exclude variables that would not be available at prediction time.
4. Evaluate demographic variables for fairness and ethical implications.
5. Verify data types, category encodings, unique values, and missing-value counts against the loaded dataset.

<!-- SESSION-08-TARGETS:START -->
## Target Variables

This project uses two target variables: one for regression and one for classification.

### Regression Target

| Variable | Type | Description | Use |
|---|---|---|---|
| `G3` | Numeric | Final student grade | Regression target |

`G3` is the original final-grade variable. It is used when predicting the student's actual numeric final grade.

### Classification Target

| Variable | Type | Description | Rule | Use |
|---|---|---|---|---|
| `passed` | Binary integer | Pass/fail outcome created from `G3` | `1` if `G3 >= 10`, otherwise `0` | Classification target |

The `passed` variable is created using:

```python
df["passed"] = (df["G3"] >= 10).astype(int)
```

| Value | Meaning |
|---:|---|
| `1` | Student passed |
| `0` | Student did not pass |

### Chosen Threshold

The chosen passing threshold is `G3 >= 10`.

Students with `G3 >= 10` are labeled as passing. Students with `G3 < 10` are labeled as not passing or at risk.

### Threshold Limitation

One limitation is that this rule creates a hard cutoff. A student with `G3 = 9` is labeled as not passing, while a student with `G3 = 10` is labeled as passing, even though their academic performance may be very similar.

The binary target also loses grade detail. For example, students with `G3 = 10` and `G3 = 18` are both labeled as passing despite having different performance levels.

### Final Decision

For the first version of the project, the `G3 >= 10` threshold will be retained because it is simple, interpretable, and useful for binary classification.

The hard-cutoff limitation will be documented. Later analysis may compare alternative thresholds or use multiple risk levels.

### Project Target Summary

| Modeling Task | Target | Definition |
|---|---|---|
| Regression | `G3` | Predict the student's numeric final grade |
| Classification | `passed` | Predict `1` when `G3 >= 10`; otherwise predict `0` |
<!-- SESSION-08-TARGETS:END -->
