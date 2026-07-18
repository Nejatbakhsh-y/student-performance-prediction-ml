$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
$CommitMessage = "Add Session 28 Random Forest regression results"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

Write-Step "SESSION 28 GITHUB DELIVERABLE"

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project folder was not found: $ProjectRoot"
}

Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    throw "This folder is not a Git repository: $ProjectRoot"
}

$OriginUrl = git remote get-url origin 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
    throw "The GitHub origin remote is not configured."
}

$Branch = git branch --show-current

if ([string]::IsNullOrWhiteSpace($Branch)) {
    throw "Git is currently in detached HEAD mode."
}

Write-Host "Project: $ProjectRoot"
Write-Host "Branch : $Branch"
Write-Host "Remote : $OriginUrl"

Write-Step "LOCATING PYTHON"

$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

if (Test-Path -LiteralPath $VenvPython) {
    $PythonExecutable = $VenvPython
    $PythonBaseArguments = @()
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonExecutable = "py"
    $PythonBaseArguments = @("-3")
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonExecutable = "python"
    $PythonBaseArguments = @()
}
else {
    throw "Python was not found. Select or create the project .venv first."
}

& $PythonExecutable @PythonBaseArguments --version

if ($LASTEXITCODE -ne 0) {
    throw "Python verification failed."
}

Write-Step "SYNCHRONIZING CURRENT BRANCH"

git ls-remote `
    --exit-code `
    --heads `
    origin `
    $Branch *> $null

$RemoteBranchExists = ($LASTEXITCODE -eq 0)

if ($RemoteBranchExists) {
    git pull `
        --rebase `
        --autostash `
        origin `
        $Branch

    if ($LASTEXITCODE -ne 0) {
        throw "Git pull --rebase failed."
    }
}
else {
    Write-Host "The remote branch does not exist yet. It will be created."
}

Write-Step "LOCATING REGRESSION NOTEBOOK"

$Candidates = Get-ChildItem `
    -LiteralPath $ProjectRoot `
    -Filter "*.ipynb" `
    -File `
    -Recurse |
    Where-Object {
        $_.FullName -notmatch "[\\/]\.venv[\\/]" -and
        $_.FullName -notmatch "[\\/]\.ipynb_checkpoints[\\/]"
    }

$ScoredCandidates = foreach ($Candidate in $Candidates) {
    $Score = 0
    $Name = $Candidate.Name.ToLowerInvariant()
    $FullName = $Candidate.FullName.ToLowerInvariant()

    if ($FullName -match "[\\/]notebooks[\\/]") {
        $Score += 20
    }

    if ($Name -match "regression") {
        $Score += 50
    }

    if ($Name -match "model.*comparison|comparison.*model") {
        $Score += 30
    }

    if ($Name -match "week.?3|student.*performance") {
        $Score += 10
    }

    try {
        $NotebookText = Get-Content `
            -LiteralPath $Candidate.FullName `
            -Raw `
            -Encoding UTF8

        if ($NotebookText -match "DecisionTreeRegressor") {
            $Score += 50
        }

        if ($NotebookText -match "Session 27") {
            $Score += 30
        }

        if ($NotebookText -match "RandomForestRegressor") {
            $Score += 10
        }
    }
    catch {
        $Score -= 100
    }

    [PSCustomObject]@{
        Path  = $Candidate.FullName
        Score = $Score
    }
}

$Selected = $ScoredCandidates |
    Sort-Object Score -Descending |
    Select-Object -First 1

if ($null -eq $Selected -or $Selected.Score -le 0) {
    $NotebookDirectory = Join-Path $ProjectRoot "notebooks"

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $NotebookDirectory |
        Out-Null

    $NotebookPath = Join-Path `
        $NotebookDirectory `
        "regression_model_comparison.ipynb"

    Write-Host "A regression notebook will be created:"
}
else {
    $NotebookPath = $Selected.Path
    Write-Host "Regression notebook selected:"
}

Write-Host $NotebookPath

Write-Step "ADDING SESSION 28 NOTEBOOK SECTION"

$TemporaryPythonFile = Join-Path `
    $env:TEMP `
    "gssrp_complete_session28.py"

$PythonCode = @"
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

notebook_path = Path(sys.argv[1])

if notebook_path.exists():
    with notebook_path.open("r", encoding="utf-8-sig") as handle:
        notebook = json.load(handle)
else:
    notebook = {
        "cells": [],
        "metadata": {},
        "nbformat": 4,
        "nbformat_minor": 5,
    }

cells = notebook.setdefault("cells", [])

cleaned_cells = [
    cell
    for cell in cells
    if cell.get("metadata", {}).get("gssrp_session") != 28
]

def source_lines(text):
    text = text.strip() + "\n"
    return text.splitlines(keepends=True)

def markdown_cell(text, section):
    return {
        "cell_type": "markdown",
        "metadata": {
            "gssrp_session": 28,
            "gssrp_section": section,
        },
        "source": source_lines(text),
    }

def code_cell(text, section):
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {
            "gssrp_session": 28,
            "gssrp_section": section,
        },
        "outputs": [],
        "source": source_lines(text),
    }

session28_cells = [
    markdown_cell(
        """
## Session 28 - Random Forest Regression

This section trains a Random Forest regressor with 300 trees using the
existing full-information train/test split. Its test performance is compared
with a single Decision Tree using MAE, RMSE, and R2.

GitHub deliverable: Add Random Forest results to the regression notebook.
""",
        "heading",
    ),

    code_cell(
        """
# GSSRP_SESSION_28_START

import time
from pathlib import Path

import numpy as np
import pandas as pd

from IPython.display import display
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)
from sklearn.tree import DecisionTreeRegressor

required_objects = ["Xtr_f", "Xte_f", "ytr", "yte"]

missing_objects = [
    name
    for name in required_objects
    if name not in globals()
]

if missing_objects:
    raise NameError(
        "Run the earlier preprocessing and train/test split cells first. "
        f"Missing objects: {missing_objects}"
    )

assert len(Xtr_f) == len(ytr)
assert len(Xte_f) == len(yte)
assert Xtr_f.shape[1] == Xte_f.shape[1]

if isinstance(Xtr_f, pd.DataFrame):
    non_numeric = Xtr_f.select_dtypes(
        exclude="number"
    ).columns.tolist()

    if non_numeric:
        raise TypeError(
            f"Training features are not numeric: {non_numeric}"
        )

if isinstance(Xte_f, pd.DataFrame):
    non_numeric = Xte_f.select_dtypes(
        exclude="number"
    ).columns.tolist()

    if non_numeric:
        raise TypeError(
            f"Test features are not numeric: {non_numeric}"
        )

if "eval_reg" not in globals():
    def eval_reg(y_true, y_pred):
        return {
            "MAE": mean_absolute_error(y_true, y_pred),
            "RMSE": np.sqrt(
                mean_squared_error(y_true, y_pred)
            ),
            "R2": r2_score(y_true, y_pred),
        }

rf = RandomForestRegressor(
    n_estimators=300,
    random_state=42,
    n_jobs=-1,
)

rf_start = time.perf_counter()
rf.fit(Xtr_f, ytr)
rf_training_time = time.perf_counter() - rf_start

rf_test_predictions = rf.predict(Xte_f)
rf_train_predictions = rf.predict(Xtr_f)

rf_mae = mean_absolute_error(
    yte,
    rf_test_predictions,
)
rf_rmse = np.sqrt(
    mean_squared_error(
        yte,
        rf_test_predictions,
    )
)
rf_r2 = r2_score(
    yte,
    rf_test_predictions,
)
rf_train_rmse = np.sqrt(
    mean_squared_error(
        ytr,
        rf_train_predictions,
    )
)
rf_rmse_gap = rf_rmse - rf_train_rmse

single_tree = DecisionTreeRegressor(
    random_state=42,
)

tree_start = time.perf_counter()
single_tree.fit(Xtr_f, ytr)
tree_training_time = time.perf_counter() - tree_start

tree_test_predictions = single_tree.predict(Xte_f)
tree_train_predictions = single_tree.predict(Xtr_f)

tree_mae = mean_absolute_error(
    yte,
    tree_test_predictions,
)
tree_rmse = np.sqrt(
    mean_squared_error(
        yte,
        tree_test_predictions,
    )
)
tree_r2 = r2_score(
    yte,
    tree_test_predictions,
)
tree_train_rmse = np.sqrt(
    mean_squared_error(
        ytr,
        tree_train_predictions,
    )
)
tree_rmse_gap = tree_rmse - tree_train_rmse

session28_tree_forest_comparison = pd.DataFrame(
    [
        {
            "Model": "Decision Tree",
            "MAE": tree_mae,
            "RMSE": tree_rmse,
            "R2": tree_r2,
            "Train RMSE": tree_train_rmse,
            "RMSE Gap": tree_rmse_gap,
            "Training Time (Seconds)": tree_training_time,
        },
        {
            "Model": "Random Forest",
            "MAE": rf_mae,
            "RMSE": rf_rmse,
            "R2": rf_r2,
            "Train RMSE": rf_train_rmse,
            "RMSE Gap": rf_rmse_gap,
            "Training Time (Seconds)": rf_training_time,
        },
    ]
).sort_values(
    by="RMSE",
    ascending=True,
).reset_index(drop=True)

print(
    "RandomForest:",
    eval_reg(yte, rf_test_predictions),
)
print("Number of fitted trees:", len(rf.estimators_))

display(
    session28_tree_forest_comparison.style.format(
        {
            "MAE": "{:.4f}",
            "RMSE": "{:.4f}",
            "R2": "{:.4f}",
            "Train RMSE": "{:.4f}",
            "RMSE Gap": "{:.4f}",
            "Training Time (Seconds)": "{:.4f}",
        }
    )
)

rmse_reduction = tree_rmse - rf_rmse
rmse_percent_reduction = (
    (rmse_reduction / tree_rmse) * 100
    if tree_rmse != 0
    else np.nan
)

print(f"Random Forest RMSE: {rf_rmse:.4f}")
print(f"Decision Tree RMSE: {tree_rmse:.4f}")
print(f"RMSE reduction: {rmse_reduction:.4f}")

if np.isfinite(rmse_percent_reduction):
    print(
        "RMSE percentage reduction: "
        f"{rmse_percent_reduction:.2f}%"
    )
""",
        "model-training",
    ),

    code_cell(
        """
# Add exactly one Random Forest row to the shared comparison table.

default_columns = [
    "Model",
    "Scenario",
    "MAE",
    "RMSE",
    "R2",
    "Parameters",
    "Notes",
]

def build_random_forest_row(columns):
    record = {}

    for column in columns:
        normalized = (
            str(column)
            .strip()
            .lower()
            .replace("²", "2")
            .replace("_", " ")
            .replace("-", " ")
        )
        normalized = " ".join(normalized.split())

        if normalized == "model":
            record[column] = "Random Forest"
        elif normalized == "scenario":
            record[column] = "Full Information"
        elif normalized in {"mae", "test mae"}:
            record[column] = rf_mae
        elif normalized in {"rmse", "test rmse"}:
            record[column] = rf_rmse
        elif normalized in {"r2", "test r2"}:
            record[column] = rf_r2
        elif normalized == "train rmse":
            record[column] = rf_train_rmse
        elif normalized in {
            "rmse gap",
            "train test rmse gap",
        }:
            record[column] = rf_rmse_gap
        elif normalized in {
            "training time",
            "training time seconds",
        }:
            record[column] = rf_training_time
        elif normalized in {
            "parameters",
            "hyperparameters",
        }:
            record[column] = (
                "n_estimators=300; random_state=42"
            )
        elif normalized == "notes":
            record[column] = (
                "Ensemble of 300 decision trees"
            )
        else:
            record[column] = pd.NA

    return pd.DataFrame(
        [record],
        columns=columns,
    )

if (
    "comparison_df" in globals()
    and isinstance(comparison_df, pd.DataFrame)
    and "Model" in comparison_df.columns
):
    comparison_df = comparison_df[
        comparison_df["Model"]
        .astype(str)
        .str.strip()
        .str.lower()
        .ne("random forest")
    ].copy()

    random_forest_row = build_random_forest_row(
        comparison_df.columns.tolist()
    )

    comparison_df = pd.concat(
        [comparison_df, random_forest_row],
        ignore_index=True,
    )
else:
    random_forest_row = build_random_forest_row(
        default_columns
    )
    comparison_df = random_forest_row.copy()

if "RMSE" in comparison_df.columns:
    comparison_df = comparison_df.sort_values(
        by="RMSE",
        ascending=True,
        na_position="last",
    ).reset_index(drop=True)

random_forest_artifact = comparison_df[
    comparison_df["Model"]
    .astype(str)
    .str.strip()
    .str.lower()
    .eq("random forest")
].copy()

display(comparison_df)
print("Session 28 Random Forest artifact row:")
display(random_forest_artifact)

current_directory = Path.cwd()
project_root = current_directory

for candidate in [
    current_directory,
    *current_directory.parents,
]:
    if (candidate / ".git").exists():
        project_root = candidate
        break

tables_directory = project_root / "reports" / "tables"
tables_directory.mkdir(parents=True, exist_ok=True)

comparison_output = (
    tables_directory
    / "regression_model_comparison.csv"
)
artifact_output = (
    tables_directory
    / "session28_random_forest_row.csv"
)

comparison_df.to_csv(
    comparison_output,
    index=False,
)
random_forest_artifact.to_csv(
    artifact_output,
    index=False,
)

print("Saved:", comparison_output)
print("Saved:", artifact_output)
""",
        "output-artifact",
    ),

    markdown_cell(
        """
### Session 28 Interpretation and Reflection

Random Forest averages predictions from many trees trained with bootstrap
samples and random feature subsets. This averaging can reduce the variance
and instability associated with one unrestricted Decision Tree.

Random Forest should not be assumed to be the best model in advance.
Performance depends on the dataset, feature relationships, noise, sample
size, hyperparameters, evaluation metric, computational cost, and required
interpretability. Final model selection must use empirical results from the
same train/test split.
""",
        "interpretation-reflection",
    ),

    code_cell(
        """
# Session 28 validation

assert len(rf.estimators_) == 300, (
    "The Random Forest must contain 300 fitted trees."
)
assert rf.random_state == 42, (
    "The Random Forest random_state must be 42."
)
assert len(rf_test_predictions) == len(yte), (
    "Prediction count does not match the test target count."
)
assert np.isfinite(rf_test_predictions).all(), (
    "Random Forest predictions contain invalid values."
)
assert len(random_forest_artifact) == 1, (
    "The table must contain exactly one Random Forest row."
)
assert np.isfinite(rf_mae)
assert np.isfinite(rf_rmse)
assert np.isfinite(rf_r2)

print("SESSION 28 NOTEBOOK SECTION COMPLETED SUCCESSFULLY")
print("Random Forest trees:", len(rf.estimators_))
print(f"Random Forest MAE:  {rf_mae:.4f}")
print(f"Random Forest RMSE: {rf_rmse:.4f}")
print(f"Random Forest R2:   {rf_r2:.4f}")
# GSSRP_SESSION_28_END
""",
        "validation",
    ),
]

notebook["cells"] = cleaned_cells + session28_cells
notebook["nbformat"] = 4
notebook["nbformat_minor"] = max(
    int(notebook.get("nbformat_minor", 0)),
    5,
)

metadata = notebook.setdefault("metadata", {})
metadata["gssrp_last_updated_session"] = 28
metadata["gssrp_session28_updated_utc"] = (
    datetime.now(timezone.utc).isoformat()
)

notebook_path.parent.mkdir(
    parents=True,
    exist_ok=True,
)

with notebook_path.open("w", encoding="utf-8") as handle:
    json.dump(
        notebook,
        handle,
        ensure_ascii=False,
        indent=1,
    )
    handle.write("\n")

session28_count = sum(
    1
    for cell in notebook["cells"]
    if cell.get("metadata", {}).get("gssrp_session") == 28
)

if session28_count != 5:
    raise RuntimeError(
        f"Expected 5 Session 28 cells; found {session28_count}."
    )

print(f"SESSION28_NOTEBOOK_UPDATED={notebook_path}")
print(f"SESSION28_ADDED_CELLS={session28_count}")
"@

Set-Content `
    -LiteralPath $TemporaryPythonFile `
    -Value $PythonCode `
    -Encoding UTF8

try {
    & $PythonExecutable `
        @PythonBaseArguments `
        $TemporaryPythonFile `
        $NotebookPath

    if ($LASTEXITCODE -ne 0) {
        throw "The notebook update process failed."
    }
}
finally {
    Remove-Item `
        -LiteralPath $TemporaryPythonFile `
        -Force `
        -ErrorAction SilentlyContinue
}

Write-Step "VALIDATING NOTEBOOK"

$ValidationPythonFile = Join-Path `
    $env:TEMP `
    "gssrp_validate_session28.py"

$ValidationCode = @"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

with path.open("r", encoding="utf-8-sig") as handle:
    notebook = json.load(handle)

session_cells = [
    cell
    for cell in notebook.get("cells", [])
    if cell.get("metadata", {}).get("gssrp_session") == 28
]

if len(session_cells) != 5:
    raise ValueError(
        f"Expected 5 Session 28 cells; found {len(session_cells)}."
    )

combined_source = "\n".join(
    "".join(cell.get("source", []))
    for cell in session_cells
)

required_markers = [
    "RandomForestRegressor",
    "n_estimators=300",
    "random_state=42",
    "comparison_df",
    "random_forest_artifact",
    "SESSION 28 NOTEBOOK SECTION COMPLETED SUCCESSFULLY",
]

missing = [
    marker
    for marker in required_markers
    if marker not in combined_source
]

if missing:
    raise ValueError(
        f"Missing required Session 28 content: {missing}"
    )

print("NOTEBOOK_JSON_VALID=TRUE")
print("SESSION28_CELL_COUNT=5")
"@

Set-Content `
    -LiteralPath $ValidationPythonFile `
    -Value $ValidationCode `
    -Encoding UTF8

try {
    & $PythonExecutable `
        @PythonBaseArguments `
        $ValidationPythonFile `
        $NotebookPath

    if ($LASTEXITCODE -ne 0) {
        throw "Notebook validation failed."
    }
}
finally {
    Remove-Item `
        -LiteralPath $ValidationPythonFile `
        -Force `
        -ErrorAction SilentlyContinue
}

Write-Step "CREATING SESSION 28 EVIDENCE"

$EvidenceDirectory = Join-Path `
    $ProjectRoot `
    "reports\evidence"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $EvidenceDirectory |
    Out-Null

$EvidencePath = Join-Path `
    $EvidenceDirectory `
    "session28_github_deliverable.txt"

$RelativeNotebook = (
    Resolve-Path -LiteralPath $NotebookPath -Relative
).ToString() -replace "^[.][\\/]", ""

$RelativeAutomation = (
    Resolve-Path -LiteralPath $PSCommandPath -Relative
).ToString() -replace "^[.][\\/]", ""

$EvidenceContent = @"
GSSRP 2026 - Session 28 GitHub Deliverable
==========================================

Completed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Project: $ProjectRoot
Branch: $Branch
Remote: $OriginUrl

Notebook:
$RelativeNotebook

Automation:
$RelativeAutomation

Completed content:
- RandomForestRegressor with 300 trees
- random_state=42
- Existing full-information train/test split
- Decision Tree comparison
- MAE, RMSE, and R2 evaluation
- Train-test RMSE comparison
- One Random Forest comparison-table row
- Duplicate Session 28 cell protection
- CSV artifact-generation code
- Interpretation and reflection
- Notebook validation checks

Notebook JSON validation: PASS

GitHub deliverable:
Add Random Forest results to the regression notebook.
"@

Set-Content `
    -LiteralPath $EvidencePath `
    -Value $EvidenceContent `
    -Encoding UTF8

$RelativeEvidence = (
    Resolve-Path -LiteralPath $EvidencePath -Relative
).ToString() -replace "^[.][\\/]", ""

Write-Step "STAGING SESSION 28 FILES"

git add -- `
    $RelativeNotebook `
    $RelativeAutomation `
    $RelativeEvidence

if ($LASTEXITCODE -ne 0) {
    throw "Git staging failed."
}

git diff --cached --stat
git diff --cached --check

if ($LASTEXITCODE -ne 0) {
    throw "Git detected whitespace or patch-format errors."
}

Write-Step "COMMITTING SESSION 28"

git diff --cached --quiet
$NoStagedChanges = ($LASTEXITCODE -eq 0)

if ($NoStagedChanges) {
    Write-Host "No new Session 28 changes were found."
    Write-Host "The deliverable may already be committed."
}
else {
    git commit -m $CommitMessage

    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed."
    }
}

Write-Step "PUSHING SESSION 28 TO GITHUB"

git push `
    -u `
    origin `
    $Branch

if ($LASTEXITCODE -ne 0) {
    throw "Git push failed."
}

Write-Step "FINAL VERIFICATION"

Write-Host "Latest commit:"
git log -1 --oneline

Write-Host ""
Write-Host "Branch status:"
git status -sb

Write-Host ""
Write-Host "Notebook:"
Write-Host $RelativeNotebook

Write-Host ""
Write-Host "Evidence:"
Write-Host $RelativeEvidence

Write-Host ""
Write-Host "============================================================"
Write-Host "SESSION 28 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
Write-Host "============================================================"
