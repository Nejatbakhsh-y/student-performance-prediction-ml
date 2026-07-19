param(
    [string]$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml",
    [string]$NotebookPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor Cyan
}

function Assert-LastCommand {
    param([string]$Message)
    if ($LASTEXITCODE -ne 0) {
        throw $Message
    }
}

Write-Step "SESSION 36: GITHUB DELIVERABLE AUTOMATION"

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath ".git")) {
    throw "This folder is not a Git repository: $ProjectRoot"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found. Install Git for Windows and restart VS Code."
}

$OriginUrl = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
    throw "The Git remote named origin is missing."
}

$CurrentBranch = (& git branch --show-current).Trim()
Assert-LastCommand "Unable to determine the current Git branch."
if ([string]::IsNullOrWhiteSpace($CurrentBranch)) {
    throw "The repository is in a detached HEAD state."
}

Write-Host "Project root:   $ProjectRoot"
Write-Host "Current branch: $CurrentBranch"
Write-Host "GitHub remote:  $($OriginUrl.Trim())"

Write-Step "LOCATING PYTHON AND THE CLASSIFICATION NOTEBOOK"

$PythonExecutable = $null
$UsePyLauncher = $false

foreach ($Candidate in @(
    (Join-Path $ProjectRoot ".venv\Scripts\python.exe"),
    (Join-Path $ProjectRoot "venv\Scripts\python.exe")
)) {
    if (Test-Path -LiteralPath $Candidate) {
        $PythonExecutable = $Candidate
        break
    }
}

if (-not $PythonExecutable) {
    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($PythonCommand) {
        $PythonExecutable = $PythonCommand.Source
    }
}

if (-not $PythonExecutable) {
    $PyCommand = Get-Command py -ErrorAction SilentlyContinue
    if ($PyCommand) {
        $PythonExecutable = $PyCommand.Source
        $UsePyLauncher = $true
    }
}

if (-not $PythonExecutable) {
    throw "Python was not found. Install Python or create the project virtual environment."
}

$NotebooksDirectory = Join-Path $ProjectRoot "notebooks"
New-Item -ItemType Directory -Path $NotebooksDirectory -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($NotebookPath)) {
    foreach ($PreferredName in @(
        "classification_models.ipynb",
        "03_classification_models.ipynb",
        "classification.ipynb",
        "student_classification.ipynb",
        "model_classification.ipynb"
    )) {
        $Candidate = Join-Path $NotebooksDirectory $PreferredName
        if (Test-Path -LiteralPath $Candidate) {
            $NotebookPath = $Candidate
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($NotebookPath)) {
        $Candidates = @(
            Get-ChildItem -Path $NotebooksDirectory -Filter "*.ipynb" -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -notmatch "\\.ipynb_checkpoints\\" -and
                    ($_.Name -match "class" -or $_.Name -match "model")
                } |
                Sort-Object FullName
        )

        if ($Candidates.Count -gt 0) {
            $NotebookPath = $Candidates[0].FullName
        }
    }

    if ([string]::IsNullOrWhiteSpace($NotebookPath)) {
        $NotebookPath = Join-Path $NotebooksDirectory "classification_models.ipynb"
        Write-Host "No classification notebook was found; one will be created."
    }
}
elseif (-not [System.IO.Path]::IsPathRooted($NotebookPath)) {
    $NotebookPath = Join-Path $ProjectRoot $NotebookPath
}

New-Item -ItemType Directory -Path (Split-Path -Parent $NotebookPath) -Force | Out-Null
Write-Host "Python:   $PythonExecutable"
Write-Host "Notebook: $NotebookPath"

$NotebookPreviouslyExisted = Test-Path -LiteralPath $NotebookPath
$BackupPath = Join-Path $env:TEMP ("s36_notebook_backup_{0}.ipynb" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
if ($NotebookPreviouslyExisted) {
    Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
}

Write-Step "ADDING IDEMPOTENT SESSION 36 CELLS"

$TemporaryPythonScript = Join-Path $env:TEMP ("s36_update_{0}.py" -f ([guid]::NewGuid().ToString("N")))
$env:S36_NOTEBOOK_PATH = $NotebookPath

@'
import json
import os
from pathlib import Path

NOTEBOOK_PATH = Path(os.environ["S36_NOTEBOOK_PATH"])
SESSION_TAG = "session-36-boosting"
SESSION_MARKER = "SESSION_36_BOOSTING_GITHUB_DELIVERABLE"


def lines(text):
    values = text.strip("\n").splitlines()
    return [line + ("\n" if i < len(values) - 1 else "") for i, line in enumerate(values)]


def markdown(text):
    return {
        "cell_type": "markdown",
        "metadata": {"tags": [SESSION_TAG]},
        "source": lines(text),
    }


def code(text):
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {"tags": [SESSION_TAG]},
        "outputs": [],
        "source": lines(text),
    }


if NOTEBOOK_PATH.exists():
    try:
        notebook = json.loads(NOTEBOOK_PATH.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Invalid notebook JSON: {NOTEBOOK_PATH}") from exc
else:
    notebook = {
        "cells": [],
        "metadata": {
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python", "version": "3"},
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }

if not isinstance(notebook.get("cells"), list):
    raise RuntimeError("The notebook does not contain a valid cells list.")

# Remove only cells created by an earlier run of this automation.
retained_cells = [
    cell for cell in notebook["cells"]
    if SESSION_TAG not in cell.get("metadata", {}).get("tags", [])
]

heading = r'''
# Session 36: Gradient Boosting and AdaBoost

This section trains both boosting classifiers on the existing fixed classification
split, evaluates at-risk detection, and adds both rows to the classification leaderboard.
'''

setup = r'''
# SESSION_36_BOOSTING_GITHUB_DELIVERABLE
import time
from pathlib import Path

import numpy as np
import pandas as pd
from IPython.display import display
from sklearn.ensemble import AdaBoostClassifier, GradientBoostingClassifier
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)

required_s36 = ["Xtr_f", "Xte_f", "yctr", "ycte"]
missing_s36 = [name for name in required_s36 if name not in globals()]
if missing_s36:
    raise NameError(
        "Run the earlier classification preparation cells first. Missing: "
        + ", ".join(missing_s36)
    )

y_train_s36 = np.asarray(yctr).ravel()
y_test_s36 = np.asarray(ycte).ravel()

if Xtr_f.shape[0] != len(y_train_s36):
    raise ValueError("Xtr_f and yctr have different row counts.")
if Xte_f.shape[0] != len(y_test_s36):
    raise ValueError("Xte_f and ycte have different row counts.")

labels_s36 = np.unique(np.concatenate([y_train_s36, y_test_s36]))
if len(labels_s36) != 2:
    raise ValueError(f"Session 36 requires binary labels; detected {labels_s36}.")

AT_RISK_LABEL_S36 = 1 if 1 in labels_s36 else labels_s36[-1]
print("Session 36 inputs verified.")
print("Training shape:", Xtr_f.shape)
print("Testing shape: ", Xte_f.shape)
print("At-risk label: ", AT_RISK_LABEL_S36)
'''

training = r'''
# Train and evaluate Gradient Boosting and AdaBoost.
boosting_models_s36 = {
    "GradBoost": GradientBoostingClassifier(random_state=42),
    "AdaBoost": AdaBoostClassifier(random_state=42),
}

boosting_records_s36 = []
fitted_boosting_models_s36 = {}

for model_name, estimator in boosting_models_s36.items():
    start = time.perf_counter()
    estimator.fit(Xtr_f, y_train_s36)
    fit_seconds = time.perf_counter() - start

    predictions = estimator.predict(Xte_f)
    class_index = list(estimator.classes_).index(AT_RISK_LABEL_S36)
    probabilities = estimator.predict_proba(Xte_f)[:, class_index]
    binary_actual = (y_test_s36 == AT_RISK_LABEL_S36).astype(int)

    boosting_records_s36.append({
        "Model": model_name,
        "Accuracy": accuracy_score(y_test_s36, predictions),
        "Precision": precision_score(
            y_test_s36, predictions, pos_label=AT_RISK_LABEL_S36, zero_division=0
        ),
        "Recall": recall_score(
            y_test_s36, predictions, pos_label=AT_RISK_LABEL_S36, zero_division=0
        ),
        "F1": f1_score(
            y_test_s36, predictions, pos_label=AT_RISK_LABEL_S36, zero_division=0
        ),
        "ROC_AUC": roc_auc_score(binary_actual, probabilities),
        "Fit_Time_Seconds": fit_seconds,
    })
    fitted_boosting_models_s36[model_name] = estimator

boosting_results_s36 = (
    pd.DataFrame(boosting_records_s36)
    .sort_values(["F1", "Recall", "ROC_AUC", "Accuracy"], ascending=False)
    .reset_index(drop=True)
)
boosting_results_s36.insert(0, "Boosting_Rank", range(1, len(boosting_results_s36) + 1))
display(boosting_results_s36.style.format({
    "Accuracy": "{:.4f}", "Precision": "{:.4f}", "Recall": "{:.4f}",
    "F1": "{:.4f}", "ROC_AUC": "{:.4f}", "Fit_Time_Seconds": "{:.4f}",
}))
'''

leaderboard = r'''
# Add both Session 36 models to the project classification leaderboard.
session36_rows = boosting_results_s36[
    ["Model", "Accuracy", "Precision", "Recall", "F1", "ROC_AUC"]
].copy()
session36_rows["Model_Family"] = "Boosting Ensemble"
session36_rows["Session"] = 36

columns_s36 = [
    "Model", "Model_Family", "Session", "Accuracy", "Precision",
    "Recall", "F1", "ROC_AUC",
]

existing_s36 = None
for variable_name in [
    "classification_leaderboard", "classification_table",
    "clf_leaderboard", "model_comparison_classification",
]:
    candidate = globals().get(variable_name)
    if isinstance(candidate, pd.DataFrame):
        existing_s36 = candidate.copy()
        break

if existing_s36 is None:
    existing_s36 = pd.DataFrame(columns=columns_s36)

rename_s36 = {
    "model": "Model", "model_name": "Model", "accuracy": "Accuracy",
    "precision": "Precision", "recall": "Recall", "f1": "F1",
    "f1_score": "F1", "roc_auc": "ROC_AUC", "auc": "ROC_AUC",
}
for old_column in list(existing_s36.columns):
    normalized = str(old_column).strip().lower().replace(" ", "_")
    new_column = rename_s36.get(normalized)
    if new_column and new_column not in existing_s36.columns:
        existing_s36 = existing_s36.rename(columns={old_column: new_column})

for column in columns_s36:
    if column not in existing_s36.columns:
        if column == "Model_Family":
            existing_s36[column] = "Earlier Classifier"
        elif column == "Session":
            existing_s36[column] = pd.NA
        else:
            existing_s36[column] = np.nan

# Idempotency: remove prior boosting rows before adding current results.
existing_s36 = existing_s36[columns_s36]
existing_s36 = existing_s36[
    ~existing_s36["Model"].isin(["GradBoost", "AdaBoost"])
].copy()

classification_leaderboard = pd.concat(
    [existing_s36, session36_rows[columns_s36]], ignore_index=True
)
for metric in ["Accuracy", "Precision", "Recall", "F1", "ROC_AUC"]:
    classification_leaderboard[metric] = pd.to_numeric(
        classification_leaderboard[metric], errors="coerce"
    )

classification_leaderboard = (
    classification_leaderboard
    .sort_values(
        ["F1", "Recall", "ROC_AUC", "Accuracy", "Precision"],
        ascending=False,
        na_position="last",
    )
    .reset_index(drop=True)
)
classification_leaderboard.insert(
    0, "Rank", range(1, len(classification_leaderboard) + 1)
)

output_dir_s36 = Path("reports") / "tables"
output_dir_s36.mkdir(parents=True, exist_ok=True)
classification_leaderboard.to_csv(
    output_dir_s36 / "classification_leaderboard.csv", index=False
)
display(classification_leaderboard)
'''

verification = r'''
# Final Session 36 verification.
assert set(boosting_results_s36["Model"]) == {"GradBoost", "AdaBoost"}
assert len(boosting_results_s36) == 2
assert classification_leaderboard["Model"].eq("GradBoost").sum() == 1
assert classification_leaderboard["Model"].eq("AdaBoost").sum() == 1
assert not boosting_results_s36[
    ["Accuracy", "Precision", "Recall", "F1", "ROC_AUC"]
].isna().any().any()

print("=" * 70)
print("SESSION 36 NOTEBOOK DELIVERABLE COMPLETED")
print("Gradient Boosting and AdaBoost are in the classification leaderboard.")
print("=" * 70)
'''

new_cells = [
    markdown(heading), code(setup), code(training), code(leaderboard), code(verification)
]

# Validate every generated Python cell before changing the notebook.
for index, cell in enumerate(new_cells, start=1):
    if cell["cell_type"] == "code":
        compile("".join(cell["source"]), f"session36_cell_{index}", "exec")

notebook["cells"] = retained_cells + new_cells
notebook["nbformat"] = 4
notebook["nbformat_minor"] = max(int(notebook.get("nbformat_minor", 0)), 5)

NOTEBOOK_PATH.parent.mkdir(parents=True, exist_ok=True)
temporary = NOTEBOOK_PATH.with_suffix(NOTEBOOK_PATH.suffix + ".tmp")
temporary.write_text(
    json.dumps(notebook, indent=1, ensure_ascii=False) + "\n", encoding="utf-8"
)
temporary.replace(NOTEBOOK_PATH)

saved = json.loads(NOTEBOOK_PATH.read_text(encoding="utf-8"))
combined = "\n".join("".join(cell.get("source", [])) for cell in saved["cells"])
required_tokens = [
    SESSION_MARKER,
    "GradientBoostingClassifier",
    "AdaBoostClassifier",
    "random_state=42",
    "classification_leaderboard",
]
missing = [token for token in required_tokens if token not in combined]
if missing:
    raise RuntimeError("Notebook validation failed; missing: " + ", ".join(missing))

tagged_count = sum(
    SESSION_TAG in cell.get("metadata", {}).get("tags", []) for cell in saved["cells"]
)
if tagged_count != len(new_cells):
    raise RuntimeError("Unexpected number of Session 36 cells.")

print(f"Notebook updated: {NOTEBOOK_PATH}")
print(f"Session 36 cells: {tagged_count}")
print("Notebook JSON validation: PASSED")
print("Generated Python syntax validation: PASSED")
'@ | Set-Content -LiteralPath $TemporaryPythonScript -Encoding UTF8

try {
    if ($UsePyLauncher) {
        & $PythonExecutable -3 $TemporaryPythonScript
    }
    else {
        & $PythonExecutable $TemporaryPythonScript
    }
    Assert-LastCommand "The Session 36 notebook update failed."
}
catch {
    if ($NotebookPreviouslyExisted -and (Test-Path -LiteralPath $BackupPath)) {
        Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
        Write-Host "The original notebook was restored." -ForegroundColor Yellow
    }
    elseif (-not $NotebookPreviouslyExisted -and (Test-Path -LiteralPath $NotebookPath)) {
        Remove-Item -LiteralPath $NotebookPath -Force
    }
    throw
}
finally {
    Remove-Item -LiteralPath $TemporaryPythonScript -Force -ErrorAction SilentlyContinue
    Remove-Item Env:S36_NOTEBOOK_PATH -ErrorAction SilentlyContinue
}

Remove-Item -LiteralPath $BackupPath -Force -ErrorAction SilentlyContinue

$ResolvedNotebookPath = (Resolve-Path -LiteralPath $NotebookPath).Path
$RelativeNotebookPath = $ResolvedNotebookPath.Substring($ProjectRoot.Length).TrimStart([char[]]@(92, 47)).Replace("\", "/")

Write-Step "VALIDATING, COMMITTING, AND PUSHING"

& git diff --check -- $RelativeNotebookPath
Assert-LastCommand "Git found whitespace or patch errors."

Write-Host "Notebook change summary:"
& git diff --stat -- $RelativeNotebookPath

& git add -- $RelativeNotebookPath
Assert-LastCommand "Git could not stage the classification notebook."

& git diff --cached --quiet -- $RelativeNotebookPath
$HasNotebookChanges = $LASTEXITCODE -ne 0

if ($HasNotebookChanges) {
    & git commit -m "Add Session 36 boosting classifiers" -- $RelativeNotebookPath
    Assert-LastCommand "The Session 36 Git commit failed."
}
else {
    Write-Host "Session 36 is already current; no new commit is required." -ForegroundColor Yellow
}

$Upstream = (& git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
$HasUpstream = $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($Upstream)

if ($HasUpstream) {
    & git push
}
else {
    & git push -u origin $CurrentBranch
}
Assert-LastCommand "The GitHub push failed. Check authentication and internet access."

$LatestCommit = (& git log -1 --pretty=format:"%h | %s").Trim()
$NotebookStatus = (& git status --short -- $RelativeNotebookPath)

Write-Step "FINAL SESSION 36 VERIFICATION"
Write-Host "Notebook:      $RelativeNotebookPath"
Write-Host "Branch:        $CurrentBranch"
Write-Host "Latest commit: $LatestCommit"

if ([string]::IsNullOrWhiteSpace($NotebookStatus)) {
    Write-Host "Notebook status: clean" -ForegroundColor Green
}
else {
    Write-Host "Notebook status: $NotebookStatus" -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host "SESSION 36 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host "GradientBoostingClassifier was added."
Write-Host "AdaBoostClassifier was added."
Write-Host "Both models were connected to classification_leaderboard."
Write-Host "The notebook was validated, committed, and pushed to GitHub."
