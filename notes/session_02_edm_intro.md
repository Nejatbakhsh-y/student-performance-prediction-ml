# Session 2: Introduction to Educational Data Mining

## Session Summary

Session 2 introduced the connection between educational data mining, machine learning, and student performance prediction. The main goal was to move from a broad project topic to clear research questions and hypotheses.

Students discussed how public educational data can be used to study academic performance, identify important predictors, and compare machine learning models.

## Key Concepts

### Educational Data Mining

Educational data mining uses data analysis, statistics, and machine learning to study educational questions. In this project, it helps us understand which factors are related to student performance.

### Target Variable

The target variable is the outcome the model tries to predict. In this project, the target may be final grade, student success, or at-risk status.

### Predictor Variables

Predictor variables are the input features used by the model. Examples may include study time, absences, family background, school support, and prior academic performance.

### Regression

Regression is used when the target variable is numeric. For example, predicting a final grade as a number is a regression task.

### Classification

Classification is used when the target variable is a category. For example, predicting whether a student is successful or at risk is a classification task.

### Target Leakage

Target leakage happens when a model uses information that would not be available at the time of prediction. In this project, prior grades such as G1 and G2 must be handled carefully.

## Student Activity

Students worked in pairs to refine research questions. Each pair identified:

- The target variable
- The predictor variables
- The task type
- The hypothesis
- Whether the question may be affected by G1/G2 leakage

## Reflection Question

Why is it important to separate a full-information model from an early-warning model?

## Reflection Answer

It is important because the two models answer different questions. A full-information model may show the strongest prediction accuracy because it can use prior grades. However, an early-warning model is more useful for intervention because it avoids using information that may not be available early enough to help students.
