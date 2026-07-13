# Scaling Plan

## Session 12: Numerical Variables

## Project Context

This project predicts student academic success using public educational data and interpretable machine-learning workflows. Session 12 identifies numerical variables and establishes the scaling strategy for each model family.

## Purpose

This scaling plan documents:

- Why numeric feature scaling matters.
- Which models require scaling.
- Which models usually do not require scaling.
- How scaling should be incorporated into the modeling pipeline.
- How preprocessing data leakage will be prevented.

## Numeric Variable Review

The numerical columns are identified and summarized using:

~~~python
num_cols = df.select_dtypes(include="number").columns.tolist()
print(df[num_cols].agg(["min", "max", "mean"]).T)
~~~

This code reports the minimum, maximum, and mean of every numeric variable. These statistics reveal whether the predictors use materially different numerical ranges.

## Why Scaling Matters

Scaling is important for models that depend on distances, margins, gradients, coefficients, or numerical optimization.

When one feature has a substantially larger range than another feature, it may dominate the model even when it is not more informative.

For example, a variable ranging from 0 to 100 may exert considerably more influence than a variable ranging from 0 to 4 in a distance-based model unless the variables are standardized.

## Models That Require Scaling

| Model | Requires Scaling? | Reason |
|---|---:|---|
| Linear Regression | Yes | Scaling improves numerical conditioning and is particularly useful when regularization is applied. |
| Logistic Regression | Yes | Scaling improves optimization stability and convergence. |
| K-Nearest Neighbors | Yes | KNN directly uses distances, so large-range variables can dominate the calculation. |
| Support Vector Machine | Yes | SVM depends on margins and the geometry of the predictor space. |
| Neural Network | Yes | Standardized inputs support more stable gradient-based optimization. |

## Models That Usually Do Not Require Scaling

| Model | Requires Scaling? | Reason |
|---|---:|---|
| Decision Tree | No | Decision trees use ordered threshold splits rather than distance calculations. |
| Random Forest | No | Random forests inherit the scale insensitivity of decision trees. |
| Gradient Boosting | No | Tree-based gradient-boosting models also use threshold-based splits. |

## Summary

Scaling is recommended for:

- Linear Regression.
- Logistic Regression.
- K-Nearest Neighbors.
- Support Vector Machine.
- Neural Networks.

Scaling is generally unnecessary for:

- Decision Tree.
- Random Forest.
- Tree-based Gradient Boosting.

## Interpretation

The project includes linear, distance-based, margin-based, neural-network, and tree-based models.

A single universal numeric preprocessing strategy should not be applied to every model. Instead, the preprocessing procedure should reflect the mathematical structure of the selected algorithm.

Linear, distance-based, margin-based, and neural-network models should receive standardized numerical predictors. Tree-based models should ordinarily receive the original numerical values.

## Recommended Pipeline Approach

The project should use separate scikit-learn preprocessing pipelines.

### Pipeline 1: Scaled Numeric Features

Apply `StandardScaler()` to numerical predictors for:

- Linear Regression.
- Logistic Regression.
- K-Nearest Neighbors.
- Support Vector Machine.
- Neural Networks.

Example:

~~~python
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

scaled_preprocessor = ColumnTransformer(
    transformers=[
        ("numeric", StandardScaler(), numeric_features),
        (
            "categorical",
            OneHotEncoder(handle_unknown="ignore"),
            categorical_features,
        ),
    ]
)

scaled_pipeline = Pipeline(
    steps=[
        ("preprocessor", scaled_preprocessor),
        ("model", model),
    ]
)
~~~

### Pipeline 2: Unscaled Numeric Features

Use `"passthrough"` for numerical predictors with:

- Decision Tree.
- Random Forest.
- Tree-based Gradient Boosting.

Example:

~~~python
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

tree_preprocessor = ColumnTransformer(
    transformers=[
        ("numeric", "passthrough", numeric_features),
        (
            "categorical",
            OneHotEncoder(handle_unknown="ignore"),
            categorical_features,
        ),
    ]
)

tree_pipeline = Pipeline(
    steps=[
        ("preprocessor", tree_preprocessor),
        ("model", model),
    ]
)
~~~

## Data Leakage Warning

The scaler must be fitted only on the training data.

The correct procedure is:

1. Split the dataset into training and testing sets.
2. Fit the preprocessing pipeline using only the training data.
3. Transform the training data using the fitted preprocessing components.
4. Transform validation and test data using the same fitted components.
5. Never calculate scaling parameters from the complete dataset before splitting it.

The target variable must not be included among the scaled predictors.

Using scikit-learn `Pipeline` and `ColumnTransformer` objects ensures that preprocessing is fitted inside the training workflow and reduces the risk of data leakage.

## Student Activity: Model Scaling Decisions

| Model | Decision | Primary Reason |
|---|---:|---|
| Linear Regression | Scale | Supports numerical conditioning and regularized estimation. |
| Logistic Regression | Scale | Supports optimization and coefficient stability. |
| K-Nearest Neighbors | Scale | Prevents large-range variables from dominating distances. |
| Support Vector Machine | Scale | Prevents feature scale from distorting margins. |
| Neural Network | Scale | Supports stable gradient-based training. |
| Decision Tree | Do not require scaling | Uses ordered threshold splits. |
| Random Forest | Do not require scaling | Uses collections of decision trees. |
| Gradient Boosting | Do not require scaling | Tree-based implementations use threshold splits. |

## Reflection Question

### Why do tree-based models care less about feature scaling than KNN or SVM?

Tree-based models divide observations using threshold rules and mainly depend on the ordering of feature values. A monotonic scaling transformation changes the numerical threshold but generally preserves the ordering of the observations. Therefore, the tree can usually produce an equivalent split.

KNN calculates distances directly. When one variable has a much larger numerical range than another, the large-range variable can dominate the distance calculation.

SVM is also scale-sensitive because its optimization process and separating margin depend on the numerical geometry of the predictor space.

Therefore, scaling is important for KNN and SVM but is usually unnecessary for decision trees, random forests, and tree-based gradient-boosting models.

## Final Scaling Decision

The project will standardize numerical predictors for linear, distance-based, margin-based, and neural-network models.

The project will ordinarily retain unscaled numerical predictors for tree-based models.

All preprocessing will be implemented using model-specific scikit-learn `Pipeline` and `ColumnTransformer` objects. Scaling parameters will be estimated exclusively from training data.
