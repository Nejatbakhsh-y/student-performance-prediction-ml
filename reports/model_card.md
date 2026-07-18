# Model Card

## 1. Model

- **Model name:** Student Academic Success Random Forest
- **Model type:** Random Forest classifier
- **Selection status:** Final selected model for the current study
- **Project:** Predicting Student Academic Success Using Interpretable Machine Learning
- **Version:** 1.0
- **Documentation date:** 2026-07-18

## 2. Model Purpose

The model estimates whether a student may be at risk of an unfavorable academic outcome. It is designed to support early, constructive intervention. A prediction is a decision-support signal, not a judgment about a student's ability, character, motivation, or future.

## 3. Intended Use

Appropriate intended use includes identifying students who may benefit from voluntary tutoring, advising, mentoring, or other academic support. Predictions may also support approved research on responsible early-warning systems when they are combined with professional judgment and appropriate privacy safeguards.

## 4. Intended Users

Intended users are authorized researchers, educators, academic advisers, and student-support personnel who understand the model's limitations and have a legitimate educational purpose for accessing its results.

## 5. Unintended and Prohibited Uses

The model must not be used to punish, discipline, exclude, publicly rank, or permanently label students. It must not determine admission, financial aid, course access, or other high-stakes opportunities. It must not replace communication with students, justify surveillance, or make an automatic consequential decision without qualified human review.

## 6. Data

The study uses the public educational data documented in this repository. The data may contain academic, engagement, demographic, and related variables. Outcome-revealing variables that are unavailable at the intended prediction time must be excluded to reduce data leakage. Dataset composition, preprocessing, and split details should be interpreted from the repository's recorded data and evaluation artifacts rather than inferred from this model card.

The development data may not represent every institution, geographic setting, age group, socioeconomic group, or educational system. Student data are sensitive even when a source is public, so access, retention, and reporting must follow applicable privacy and governance requirements.

## 7. Model Inputs

Inputs are limited to predictors approved by the research design and available at the selected prediction time. Variables that reveal the final outcome, act as inappropriate proxies, or become available only after the prediction point must not be used.

## 8. Model Output

The model produces an at-risk or academic-success classification and may produce an estimated probability. The result indicates a need for further review; it is not a confirmed fact and must not be interpreted as causation.

## 9. Performance

| Metric | Result |
|---|---:|
| Accuracy | Not evaluated in the current study. |
| Precision | Not evaluated in the current study. |
| Recall | Not evaluated in the current study. |
| F1 score | Not evaluated in the current study. |
| ROC AUC | Not evaluated in the current study. |

**Performance source:** No verified classification leaderboard was available.

Only held-out results recorded by the project should be treated as final. A metric marked "Not evaluated in the current study" must not be interpreted as zero or estimated from other results.

## 10. Interpretation

Random Forest combines predictions from multiple decision trees. Built-in and permutation importance can describe associations used by the fitted model, but feature importance does not prove that a variable causes an academic outcome. Correlated variables may divide or redistribute importance.

## 11. Ethical Limitations

### 11.1 Privacy and confidentiality

Educational information is sensitive. Access should be restricted, data should be protected, and individual results should not be disclosed to unauthorized people.

### 11.2 Historical and measurement bias

Historical data may reflect unequal access to resources, institutional practices, and social inequalities. Recorded variables may measure student circumstances imperfectly, and proxy variables may reproduce bias.

### 11.3 False positive risk

A false positive may incorrectly identify a student as at risk. This can cause unnecessary concern, stigma, unwanted intervention, or lower expectations. Supportive human review is required before action.

### 11.4 False negative risk

A false negative may fail to identify a student who needs support. This can delay useful assistance. The model must therefore supplement, not replace, educator and student communication.

### 11.5 Labeling and stigmatization

An at-risk prediction must not become a permanent label or definition of a student. Predictions should initiate confidential, constructive review and should be revisable when new information becomes available.

### 11.6 Surveillance and punitive use

The model must not justify continuous or invasive surveillance. It must not be used to punish students, deny opportunities, or automate disciplinary or high-stakes decisions.

### 11.7 Unequal error rates and fairness

Aggregate performance can conceal different false positive and false negative rates across student groups. Fairness must be evaluated with appropriate subgroup metrics before practical use; it must not be assumed from overall accuracy.

### 11.8 Generalization limits

Results from one dataset or institution may not transfer to another population or setting. The model requires validation on the intended population before deployment.

### 11.9 Prediction is not causation

An association used for prediction does not establish causation. Interventions must not be selected solely from feature importance or model output.

### 11.10 Model uncertainty

The model can make mistakes, and predictions near a decision threshold may be especially uncertain. Uncertainty must be explained during review rather than hidden behind a single label.

## 12. Fairness Review

Before practical use, reviewers should compare performance and error rates across relevant groups, investigate possible proxy variables, document representation problems, evaluate whether support is distributed fairly, and record any analysis that was not performed. The model must not be described as fair unless the claim is supported by evidence.

## 13. Human Oversight

A trained educator or adviser should review predictions before any action. Students should have an opportunity to provide context, question the result, and request correction of inaccurate information. No high-stakes decision should be based solely on this model.

## 14. Recommended Use

Use the model only to initiate confidential consideration of supportive resources. Prefer low-risk, voluntary interventions that preserve student agency and educational opportunity.

## 15. Monitoring and Maintenance

If the model is used beyond the research setting, monitor data quality, missingness, overall and subgroup performance, false positive and false negative rates, calibration, distribution shift, complaints, and intervention outcomes. Revalidate after material changes to data, population, policy, or modeling code.

## Human-Review Statement

This model card and its ethical-limitations section were checked against the documented Session 46 requirements and the project's responsible-AI purpose. Automated text and model outputs are documentation aids rather than evidence. Unsupported numerical claims are reported as not evaluated, and qualified human review remains mandatory before publication or operational use.
