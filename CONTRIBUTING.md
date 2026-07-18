# Contributing to Student Performance Prediction

Thank you for your interest in contributing to this project.

This repository supports a reproducible machine-learning study of student
performance using publicly available educational data.

## Ways to Contribute

Contributions may include:

- Correcting documentation
- Improving data-validation procedures
- Adding or repairing tests
- Improving model-evaluation code
- Fixing reproducibility issues
- Improving figures, reports, or notebooks
- Reporting bugs or security concerns

## Development Setup

Use Python 3.11 and PowerShell:

1. Clone the repository.
2. Create a virtual environment with `py -3.11 -m venv .venv`.
3. Activate it with `.\.venv\Scripts\Activate.ps1`.
4. Install requirements with `python -m pip install -r requirements.txt`.

## Contribution Workflow

Create a separate branch for each contribution:

1. Update the `main` branch.
2. Create a descriptive feature branch.
3. Make and test the changes.
4. Commit only relevant files.
5. Push the branch.
6. Open a pull request against `main`.

## Project Standards

Contributions should:

- Use reproducible random seeds where applicable.
- Prevent training and test-data leakage.
- Fit preprocessing operations only using training data.
- Place scaling inside cross-validation pipelines.
- Exclude `G1` and `G2` from early-warning models.
- Document important assumptions and limitations.
- Include tests when behavior changes.
- Avoid committing generated temporary files.
- Avoid committing credentials or private information.

## Pull Request Checklist

Before submitting a pull request, confirm that:

- The code runs successfully.
- Relevant tests pass.
- Documentation reflects the changes.
- Results can be reproduced.
- No confidential information is included.
- Only relevant files are included.

## Responsible Use

This project is intended for research and educational purposes. Predictions
should support appropriate student assistance and must not be used for
surveillance, permanent labeling, or automated punitive decisions.
