# Session 33, Section 8: one-file VS Code PowerShell automation
# Adds KNN, SVM, and Gaussian Naive Bayes to the classification notebook,
# validates the change, commits only the notebook, and pushes it to GitHub.

[CmdletBinding()]
param(
    [string]$RepoPath = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor Cyan
}

function Assert-LastCommand([string]$Message) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Message Exit code: $LASTEXITCODE"
    }
}

Write-Step "1. Checking the repository and required programs"

if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    throw "Repository folder not found: $RepoPath"
}

Set-Location -LiteralPath $RepoPath

if (-not (Test-Path -LiteralPath ".git" -PathType Container)) {
    throw "This folder is not a Git repository: $RepoPath"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found. Install Git for Windows and reopen VS Code."
}

$VenvPython = Join-Path $RepoPath ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $VenvPython -PathType Leaf) {
    $PythonCommand = $VenvPython
    $PythonPrefix = @()
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonCommand = "py"
    $PythonPrefix = @("-3")
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCommand = "python"
    $PythonPrefix = @()
}
else {
    throw "Python was not found. Install Python and reopen VS Code."
}

$NotebookCandidates = @(
    "notebooks\05_classification_models.ipynb",
    "05_classification_models.ipynb"
)

$NotebookRelativePath = $NotebookCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $NotebookRelativePath) {
    throw "Could not find 05_classification_models.ipynb in the repository root or notebooks folder."
}

$NotebookPath = Join-Path $RepoPath $NotebookRelativePath
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $env:TEMP "session33_notebook_backup_$Timestamp.ipynb"
$UpdaterPath = Join-Path $env:TEMP "session33_notebook_updater_$Timestamp.py"
Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force

Write-Host "Repository: $RepoPath"
Write-Host "Notebook:   $NotebookRelativePath"

Write-Step "2. Adding the Session 33 deliverable to the notebook"

$PythonUpdater = @'
import json
import os
import sys
import tempfile
from pathlib import Path

notebook_path = Path(sys.argv[1])

with notebook_path.open("r", encoding="utf-8-sig") as handle:
    notebook = json.load(handle)

tag = "session33-github-deliverable"

def source_text(cell):
    source = cell.get("source", "")
    return "".join(source) if isinstance(source, list) else str(source)

def lines(text):
    return text.strip("\n").splitlines(keepends=True)

def markdown(text):
    return {
        "cell_type": "markdown",
        "metadata": {"tags": [tag]},
        "source": lines(text),
    }

def code(text):
    compile(text, "<session33-cell>", "exec")
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {"tags": [tag]},
        "outputs": [],
        "source": lines(text),
    }

# Remove an earlier copy so rerunning this automation is safe.
preserved_cells = [
    cell for cell in notebook.get("cells", [])
    if tag not in cell.get("metadata", {}).get("tags", [])
    and "<!-- SESSION 33 GITHUB DELIVERABLE START -->" not in source_text(cell)
    and "<!-- SESSION 33 GITHUB DELIVERABLE END -->" not in source_text(cell)
]

new_cells = [
    markdown(r'''
<!-- SESSION 33 GITHUB DELIVERABLE START -->
# Session 33: KNN, SVM, and Naive Bayes Classification

This section trains three additional classifiers using the same fixed training
and test sets used by the earlier classification models. Scaling is performed
inside each pipeline to prevent data leakage.
'''),
    code(r'''
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

required_session33_objects = ["Xtr_f", "Xte_f", "yctr", "ycte"]
missing_session33_objects = [
    name for name in required_session33_objects if name not in globals()
]
if missing_session33_objects:
    raise NameError(
        "Run the earlier data-preparation and fixed-split cells first. "
        f"Missing: {missing_session33_objects}"
    )

if len(Xtr_f) != len(yctr) or len(Xte_f) != len(ycte):
    raise AssertionError("Feature and target row counts do not match.")

if len(set(np.asarray(yctr).ravel())) != 2:
    raise AssertionError("Session 33 requires a binary classification target.")

print("Fixed classification split verified.")
print(f"Training rows: {len(Xtr_f):,}")
print(f"Test rows:     {len(Xte_f):,}")
'''),
    code(r'''
session33_models = {
    "KNN": (
        "K-Nearest Neighbors",
        Pipeline([
            ("scaler", StandardScaler()),
            ("model", KNeighborsClassifier(n_neighbors=5)),
        ]),
    ),
    "SVM": (
        "Support Vector Machine",
        Pipeline([
            ("scaler", StandardScaler()),
            ("model", SVC(kernel="rbf", probability=True, random_state=2026)),
        ]),
    ),
    "NB": (
        "Gaussian Naive Bayes",
        Pipeline([
            ("scaler", StandardScaler()),
            ("model", GaussianNB()),
        ]),
    ),
}

session33_rows = []
session33_fitted_models = {}

for short_name, (full_name, pipeline) in session33_models.items():
    pipeline.fit(Xtr_f, np.asarray(yctr).ravel())
    predictions = pipeline.predict(Xte_f)
    probabilities = pipeline.predict_proba(Xte_f)
    classes = list(pipeline.named_steps["model"].classes_)

    # The project defines class 0 as the at-risk class and class 1 as success.
    success_probability = probabilities[:, classes.index(1)]

    row = {
        "Model": short_name,
        "Full_Model_Name": full_name,
        "Scaling_Used": True,
        "accuracy": accuracy_score(ycte, predictions),
        "precision": precision_score(ycte, predictions, pos_label=1, zero_division=0),
        "recall": recall_score(ycte, predictions, pos_label=1, zero_division=0),
        "f1": f1_score(ycte, predictions, pos_label=1, zero_division=0),
        "roc_auc": roc_auc_score(ycte, success_probability),
        "at_risk_precision": precision_score(ycte, predictions, pos_label=0, zero_division=0),
        "at_risk_recall": recall_score(ycte, predictions, pos_label=0, zero_division=0),
        "at_risk_f1": f1_score(ycte, predictions, pos_label=0, zero_division=0),
    }
    session33_rows.append(row)
    session33_fitted_models[short_name] = pipeline

session33_results_df = (
    pd.DataFrame(session33_rows)
    .sort_values("f1", ascending=False)
    .reset_index(drop=True)
)

display(session33_results_df.style.format({
    "accuracy": "{:.4f}",
    "precision": "{:.4f}",
    "recall": "{:.4f}",
    "f1": "{:.4f}",
    "roc_auc": "{:.4f}",
    "at_risk_precision": "{:.4f}",
    "at_risk_recall": "{:.4f}",
    "at_risk_f1": "{:.4f}",
}))
'''),
    code(r'''
classification_metric_columns = [
    "Model",
    "Full_Model_Name",
    "Scaling_Used",
    "accuracy",
    "precision",
    "recall",
    "f1",
    "roc_auc",
    "at_risk_precision",
    "at_risk_recall",
    "at_risk_f1",
]

possible_existing_tables = [
    "classification_table",
    "classification_comparison_df",
    "classification_results_df",
]
existing_classification_table = None

for table_name in possible_existing_tables:
    candidate = globals().get(table_name)
    if isinstance(candidate, pd.DataFrame):
        existing_classification_table = candidate.copy()
        print(f"Existing classification table found: {table_name}")
        break

new_session33_rows = session33_results_df[classification_metric_columns].copy()

if (
    existing_classification_table is None
    or existing_classification_table.empty
    or "Model" not in existing_classification_table.columns
):
    classification_table = new_session33_rows.copy()
else:
    for column_name in classification_metric_columns:
        if column_name not in existing_classification_table.columns:
            existing_classification_table[column_name] = np.nan

    existing_classification_table = existing_classification_table.loc[
        ~existing_classification_table["Model"].isin(["KNN", "SVM", "NB"]),
        classification_metric_columns,
    ].copy()
    classification_table = pd.concat(
        [existing_classification_table, new_session33_rows],
        ignore_index=True,
    )

classification_table = (
    classification_table
    .sort_values("f1", ascending=False, na_position="last")
    .reset_index(drop=True)
)
classification_table.insert(
    0, "Overall_F1_Rank", range(1, len(classification_table) + 1)
)

display(classification_table.style.format({
    column: "{:.4f}"
    for column in [
        "accuracy", "precision", "recall", "f1", "roc_auc",
        "at_risk_precision", "at_risk_recall", "at_risk_f1",
    ]
}))
'''),
    code(r'''
current_directory = Path.cwd()
repository_root = next(
    (
        directory
        for directory in [current_directory, *current_directory.parents]
        if (directory / ".git").exists()
    ),
    current_directory,
)
output_directory = repository_root / "reports" / "tables"
output_directory.mkdir(parents=True, exist_ok=True)

session33_rows_path = output_directory / "session33_classification_rows.csv"
classification_table_path = output_directory / "classification_table.csv"

session33_results_df.to_csv(session33_rows_path, index=False)
classification_table.to_csv(classification_table_path, index=False)

print("Session 33 artifact files created:")
print(session33_rows_path)
print(classification_table_path)
'''),
    code(r'''
expected_models = {"KNN", "SVM", "NB"}
actual_models = set(session33_results_df["Model"])
required_metrics = [
    "accuracy", "precision", "recall", "f1", "roc_auc",
    "at_risk_precision", "at_risk_recall", "at_risk_f1",
]

if actual_models != expected_models or len(session33_results_df) != 3:
    raise AssertionError("Results must contain exactly one KNN, SVM, and NB row.")
if session33_results_df[required_metrics].isna().any().any():
    raise AssertionError("One or more Session 33 metrics are missing.")

metric_values = session33_results_df[required_metrics].to_numpy(dtype=float)
if not np.isfinite(metric_values).all():
    raise AssertionError("One or more Session 33 metrics are not finite.")
if not ((metric_values >= 0) & (metric_values <= 1)).all():
    raise AssertionError("Classification metrics must be between zero and one.")

rows_in_main_table = classification_table[
    classification_table["Model"].isin(expected_models)
]
if len(rows_in_main_table) != 3:
    raise AssertionError("The classification table is missing a Session 33 row.")

best_row = session33_results_df.iloc[0]
print("=" * 72)
print("SESSION 33 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY")
print("=" * 72)
print(f"Highest-F1 Session 33 classifier: {best_row['Full_Model_Name']}")
print(f"Highest Session 33 F1: {best_row['f1']:.4f}")
'''),
    markdown(r'''
### Session 33 interpretation

- **KNN** assumes that nearby observations in the scaled feature space tend to
  share the same class.
- **SVM** searches for a maximum-margin boundary between the classes.
- **Gaussian Naive Bayes** assumes that predictors are conditionally
  independent given the class label and approximately Gaussian within each
  class.

The Naive Bayes independence assumption is unlikely to be fully realistic for
student-performance data. Prior grades, failures, study time, absences, and
support can remain related even within the same outcome class. Naive Bayes is
nevertheless useful as a fast, interpretable baseline.

<!-- SESSION 33 GITHUB DELIVERABLE END -->
'''),
]

notebook["cells"] = preserved_cells + new_cells

fd, temporary_name = tempfile.mkstemp(
    prefix=notebook_path.stem + "_",
    suffix=".ipynb",
    dir=str(notebook_path.parent),
)
os.close(fd)
temporary_path = Path(temporary_name)

try:
    with temporary_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(notebook, handle, indent=1, ensure_ascii=False)
        handle.write("\n")
    temporary_path.replace(notebook_path)
finally:
    if temporary_path.exists():
        temporary_path.unlink()

print(f"Updated notebook: {notebook_path}")
print(f"Preserved existing cells: {len(preserved_cells)}")
print(f"Added Session 33 cells: {len(new_cells)}")
'@

Set-Content -LiteralPath $UpdaterPath -Value $PythonUpdater -Encoding UTF8

try {
    & $PythonCommand @PythonPrefix $UpdaterPath $NotebookPath
    Assert-LastCommand "The notebook updater failed."
}
catch {
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw "The notebook update failed, so the original notebook was restored. $($_.Exception.Message)"
}

Write-Step "3. Validating notebook JSON and required Session 33 content"

$ValidationCode = @'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open("r", encoding="utf-8") as handle:
    notebook = json.load(handle)

tag = "session33-github-deliverable"
tagged = [
    cell for cell in notebook.get("cells", [])
    if tag in cell.get("metadata", {}).get("tags", [])
]
if len(tagged) != 7:
    raise AssertionError(f"Expected 7 Session 33 cells; found {len(tagged)}.")

combined = "\n".join(
    "".join(cell.get("source", []))
    if isinstance(cell.get("source", []), list)
    else str(cell.get("source", ""))
    for cell in tagged
)

required = [
    "KNeighborsClassifier",
    "SVC",
    "GaussianNB",
    "StandardScaler",
    "session33_results_df",
    "classification_table",
    "session33_classification_rows.csv",
    "classification_table.csv",
    "SESSION 33 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY",
]
missing = [item for item in required if item not in combined]
if missing:
    raise AssertionError(f"Missing required content: {missing}")

for cell in tagged:
    if cell.get("cell_type") == "code":
        source = cell.get("source", [])
        text = "".join(source) if isinstance(source, list) else str(source)
        compile(text, "<session33-validation>", "exec")

print("Notebook JSON validation passed.")
print(f"Session 33 tagged cells: {len(tagged)}")
'@

$ValidationPath = Join-Path $env:TEMP "session33_validate_$Timestamp.py"
Set-Content -LiteralPath $ValidationPath -Value $ValidationCode -Encoding UTF8

try {
    & $PythonCommand @PythonPrefix $ValidationPath $NotebookPath
    Assert-LastCommand "Notebook validation failed."
    git diff --check -- $NotebookRelativePath
    Assert-LastCommand "Git found whitespace errors in the notebook change."
}
catch {
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw "Validation failed, so the original notebook was restored. $($_.Exception.Message)"
}

Write-Step "4. Staging and committing only the classification notebook"

git add -- $NotebookRelativePath
Assert-LastCommand "Git could not stage the notebook."

git diff --cached --quiet -- $NotebookRelativePath
$DiffExitCode = $LASTEXITCODE

if ($DiffExitCode -eq 1) {
    git commit -m "Extend classification notebook with KNN SVM and Naive Bayes" -- $NotebookRelativePath
    Assert-LastCommand "Git commit failed."
    Write-Host "Notebook committed."
}
elseif ($DiffExitCode -eq 0) {
    Write-Host "No new commit was necessary; the Session 33 block is already current."
}
else {
    throw "Git could not determine whether the notebook changed."
}

Write-Step "5. Pushing the current branch to GitHub"

$Branch = (git branch --show-current).Trim()
Assert-LastCommand "Git could not determine the current branch."
if ([string]::IsNullOrWhiteSpace($Branch)) {
    throw "The repository is in detached-HEAD mode."
}

$Origin = (git remote get-url origin).Trim()
Assert-LastCommand "No GitHub origin remote was found."

git push -u origin $Branch
Assert-LastCommand "GitHub push failed. Review the error immediately above."

Write-Step "6. Final verification"

$NotebookStatus = git status --short -- $NotebookRelativePath
if (-not [string]::IsNullOrWhiteSpace(($NotebookStatus | Out-String).Trim())) {
    throw "The classification notebook still has uncommitted changes."
}

$LatestCommit = git log -1 --oneline
Assert-LastCommand "Could not read the latest commit."
$BranchStatus = git status -sb
Assert-LastCommand "Could not read branch status."

Remove-Item -LiteralPath $UpdaterPath, $ValidationPath, $BackupPath -Force -ErrorAction SilentlyContinue

Write-Host "Latest commit: $LatestCommit"
Write-Host ($BranchStatus | Out-String).Trim()
Write-Host "Remote: $Origin"
Write-Host ""
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host "SESSION 33 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host "KNN code: added"
Write-Host "SVM code: added"
Write-Host "Gaussian Naive Bayes code: added"
Write-Host "Scaling pipelines: added"
Write-Host "Classification table code: added"
Write-Host "CSV artifact code: added"
Write-Host "Notebook validation: passed"
Write-Host "Git commit: completed or already current"
Write-Host "GitHub push: completed"
