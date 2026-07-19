[CmdletBinding()]
param(
    [string]$ProjectPath = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$BranchName = "session-34-decision-tree-classifier"
$CommitMessage = "Add Session 34 decision tree classifier"
$ScriptName = "08_session34_github_deliverable.ps1"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
}

Write-Step "Validating tools and project"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or is not available in PATH."
}
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    throw "Project folder not found: $ProjectPath"
}

Set-Location -LiteralPath $ProjectPath
& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    throw "This folder is not a Git repository: $ProjectPath"
}
& git remote get-url origin *> $null
if ($LASTEXITCODE -ne 0) {
    throw "The Git remote named 'origin' is missing."
}

$PythonExe = $null
$PythonPrefix = @()
$VenvPython = Join-Path $ProjectPath ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $VenvPython -PathType Leaf) {
    $PythonExe = $VenvPython
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command py).Source
    $PythonPrefix = @("-3")
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command python).Source
}
else {
    throw "Python 3 was not found. Create the project .venv or install Python."
}

Write-Step "Creating or switching to $BranchName"
& git show-ref --verify --quiet "refs/heads/$BranchName"
if ($LASTEXITCODE -eq 0) {
    Invoke-Git switch $BranchName
}
else {
    & git ls-remote --exit-code --heads origin $BranchName *> $null
    if ($LASTEXITCODE -eq 0) {
        Invoke-Git switch --track -c $BranchName "origin/$BranchName"
    }
    else {
        Invoke-Git switch -c $BranchName
    }
}

Write-Step "Finding the classification notebook"
$Notebook = Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Filter "*.ipynb" |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -notmatch '[\\/]\.venv[\\/]' -and
        $_.FullName -notmatch '[\\/]\.ipynb_checkpoints[\\/]' -and
        $_.Name -match 'classification|classifier'
    } |
    Sort-Object `
        @{ Expression = { if ($_.DirectoryName -match '[\\/]notebooks?([\\/]|$)') { 0 } else { 1 } } }, `
        @{ Expression = { if ($_.Name -eq 'classification_models.ipynb') { 0 } else { 1 } } }, `
        FullName |
    Select-Object -First 1

if (-not $Notebook) {
    $NotebookDirectory = Join-Path $ProjectPath "notebooks"
    New-Item -ItemType Directory -Path $NotebookDirectory -Force | Out-Null
    $NotebookPath = Join-Path $NotebookDirectory "classification_models.ipynb"
    $Notebook = [PSCustomObject]@{ FullName = $NotebookPath }
    Write-Host "No classification notebook existed; creating $NotebookPath"
}
else {
    $NotebookPath = $Notebook.FullName
    Write-Host "Selected notebook: $NotebookPath"
}

if (Test-Path -LiteralPath $NotebookPath -PathType Leaf) {
    $BackupDirectory = Join-Path $env:TEMP "Session34NotebookBackups"
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $BackupName = "session34_before_{0}.ipynb" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    Copy-Item -LiteralPath $NotebookPath -Destination (Join-Path $BackupDirectory $BackupName)
    Write-Host "Safety backup created in: $BackupDirectory"
}

Write-Step "Adding the complete Session 34 section"
$UpdaterPath = Join-Path $env:TEMP "session34_update_notebook.py"
$UpdaterCode = @'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])

def markdown(source):
    return {
        "cell_type": "markdown",
        "metadata": {"tags": ["session34"]},
        "source": [line + "\n" for line in source.strip().splitlines()],
    }

def code(source):
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {"tags": ["session34"]},
        "outputs": [],
        "source": [line + "\n" for line in source.strip().splitlines()],
    }

if path.exists():
    with path.open("r", encoding="utf-8-sig") as handle:
        notebook = json.load(handle)
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
    raise ValueError("Notebook has no valid cells list")

notebook["cells"] = [
    cell for cell in notebook["cells"]
    if "session34" not in cell.get("metadata", {}).get("tags", [])
]

cells = [
    markdown(r'''
# Session 34: Decision Tree Classification

This section trains an interpretable, depth-limited Decision Tree classifier on the same held-out split used by the earlier classification models. Class `0` means **at risk** and class `1` means **successful**.
'''),
    code(r'''
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from sklearn.tree import DecisionTreeClassifier, export_text, plot_tree
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    classification_report,
    precision_score,
    recall_score,
    f1_score,
)

required_s34 = ["Xtr_f", "Xte_f", "yctr", "ycte", "eval_clf"]
missing_s34 = [name for name in required_s34 if name not in globals()]
if missing_s34:
    raise NameError(
        "Run the earlier classification cells first. Missing objects: "
        + ", ".join(missing_s34)
    )

yctr_s34 = np.asarray(yctr).ravel()
ycte_s34 = np.asarray(ycte).ravel()
assert Xtr_f.shape[0] == len(yctr_s34)
assert Xte_f.shape[0] == len(ycte_s34)

dtc = DecisionTreeClassifier(max_depth=5, random_state=42)
dtc.fit(Xtr_f, yctr_s34)
dtc_predictions = dtc.predict(Xte_f)
dtc_metrics = eval_clf(ycte_s34, dtc_predictions)

at_risk_metrics = {
    "at_risk_precision": precision_score(ycte_s34, dtc_predictions, pos_label=0, zero_division=0),
    "at_risk_recall": recall_score(ycte_s34, dtc_predictions, pos_label=0, zero_division=0),
    "at_risk_f1": f1_score(ycte_s34, dtc_predictions, pos_label=0, zero_division=0),
}

print("Decision Tree metrics:", dtc_metrics)
print("At-risk metrics:", at_risk_metrics)
print("Actual depth:", dtc.get_depth())
print("Leaves:", dtc.get_n_leaves())
print(classification_report(
    ycte_s34, dtc_predictions,
    labels=[0, 1], target_names=["At risk", "Successful"],
    digits=4, zero_division=0,
))

ConfusionMatrixDisplay.from_predictions(
    ycte_s34, dtc_predictions,
    labels=[0, 1], display_labels=["At risk", "Successful"],
    values_format="d",
)
plt.title("Session 34: Decision Tree Confusion Matrix")
plt.tight_layout()
plt.show()
'''),
    code(r'''
feature_count_s34 = Xtr_f.shape[1]
if hasattr(Xtr_f, "columns"):
    feature_names_s34 = [str(name) for name in Xtr_f.columns]
elif "X_full" in globals() and hasattr(X_full, "columns") and X_full.shape[1] == feature_count_s34:
    feature_names_s34 = [str(name) for name in X_full.columns]
else:
    feature_names_s34 = [f"feature_{index}" for index in range(feature_count_s34)]

tree_class_names = ["At risk" if int(value) == 0 else "Successful" for value in dtc.classes_]
plt.figure(figsize=(26, 14))
plot_tree(
    dtc,
    feature_names=feature_names_s34,
    class_names=tree_class_names,
    max_depth=3,
    filled=True,
    rounded=True,
    proportion=True,
    precision=2,
    fontsize=8,
)
plt.title("Session 34 Decision Tree Classifier - Top Three Levels")
plt.tight_layout()
plt.show()

tree_rules_s34 = export_text(
    dtc, feature_names=feature_names_s34, max_depth=3, decimals=2
)
print("Top Decision Tree rules:\n")
print(tree_rules_s34)

feature_importance_s34 = (
    pd.DataFrame({"Feature": feature_names_s34, "Importance": dtc.feature_importances_})
    .sort_values("Importance", ascending=False)
    .reset_index(drop=True)
)
display(feature_importance_s34.head(15))
'''),
    code(r'''
def metric_s34(metrics, name):
    for key in (name, name.lower(), name.upper(), name.capitalize()):
        if key in metrics:
            return float(metrics[key])
    raise KeyError(f"eval_clf output does not contain {name!r}: {list(metrics)}")

tree_classifier_row = pd.DataFrame([{
    "Model": "Decision Tree",
    "Accuracy": metric_s34(dtc_metrics, "accuracy"),
    "Precision": metric_s34(dtc_metrics, "precision"),
    "Recall": metric_s34(dtc_metrics, "recall"),
    "F1": metric_s34(dtc_metrics, "f1"),
}])

existing_table_s34 = None
for table_name_s34 in (
    "classification_table",
    "classification_results",
    "classification_leaderboard",
    "clf_table",
):
    candidate_s34 = globals().get(table_name_s34)
    if isinstance(candidate_s34, pd.DataFrame):
        existing_table_s34 = candidate_s34.copy()
        break

if existing_table_s34 is None:
    classification_table = tree_classifier_row.copy()
else:
    rename_s34 = {
        column: str(column).strip().capitalize()
        for column in existing_table_s34.columns
        if str(column).strip().lower() in {"model", "accuracy", "precision", "recall", "f1"}
    }
    classification_table = existing_table_s34.rename(columns=rename_s34)
    for column_s34 in ["Model", "Accuracy", "Precision", "Recall", "F1"]:
        if column_s34 not in classification_table.columns:
            classification_table[column_s34] = np.nan
    classification_table = classification_table[
        classification_table["Model"].astype(str).str.strip().str.lower() != "decision tree"
    ].copy()
    classification_table = pd.concat(
        [classification_table, tree_classifier_row], ignore_index=True
    )

output_directory_s34 = os.path.join("results", "session34")
os.makedirs(output_directory_s34, exist_ok=True)
classification_output_s34 = os.path.join(
    output_directory_s34, "session34_classification_table.csv"
)
tree_output_s34 = os.path.join(
    output_directory_s34, "session34_decision_tree_row.csv"
)
classification_table.to_csv(classification_output_s34, index=False)
tree_classifier_row.to_csv(tree_output_s34, index=False)

decision_tree_rows_s34 = classification_table[
    classification_table["Model"].astype(str).str.strip().str.lower() == "decision tree"
]
assert dtc.max_depth == 5
assert dtc.random_state == 42
assert dtc.get_depth() <= 5
assert len(dtc_predictions) == len(ycte_s34)
assert set(np.unique(dtc_predictions)).issubset({0, 1})
assert len(decision_tree_rows_s34) == 1
assert list(tree_classifier_row.columns) == ["Model", "Accuracy", "Precision", "Recall", "F1"]
assert tree_classifier_row[["Accuracy", "Precision", "Recall", "F1"]].notna().all().all()

display(classification_table)
print("Saved:", classification_output_s34)
print("Saved:", tree_output_s34)
print("SESSION 34 NOTEBOOK SECTION COMPLETED SUCCESSFULLY")
'''),
    markdown(r'''
## Responsible-use reflection

A teacher should use a readable rule only as an early-warning screening aid, not as an automatic judgment. The teacher should verify the underlying information, speak with the student, consider circumstances absent from the data, protect confidentiality, check for errors and bias, and use the result to offer support rather than punishment or labeling. The rule shows an association, not proof of cause or certainty about an individual student.
'''),
]

notebook["cells"].extend(cells)
notebook["nbformat"] = 4
notebook.setdefault("nbformat_minor", 5)
notebook.setdefault("metadata", {})

path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", encoding="utf-8", newline="\n") as handle:
    json.dump(notebook, handle, indent=1, ensure_ascii=False)
    handle.write("\n")

with path.open("r", encoding="utf-8") as handle:
    checked = json.load(handle)
text = "\n".join(
    "".join(cell.get("source", [])) for cell in checked.get("cells", [])
)
required = [
    "DecisionTreeClassifier", "max_depth=5", "random_state=42", "dtc.fit",
    "eval_clf", "tree_classifier_row", "classification_table",
    "session34_classification_table.csv", "session34_decision_tree_row.csv",
]
missing = [item for item in required if item not in text]
tagged = [
    cell for cell in checked["cells"]
    if "session34" in cell.get("metadata", {}).get("tags", [])
]
if missing:
    raise AssertionError("Notebook validation missing: " + ", ".join(missing))
if len(tagged) != len(cells):
    raise AssertionError("Session 34 cell tagging validation failed")
print("NOTEBOOK_VALIDATION=PASS")
print(f"SESSION34_CELLS={len(tagged)}")
'@

Set-Content -LiteralPath $UpdaterPath -Value $UpdaterCode -Encoding UTF8
try {
    & $PythonExe @PythonPrefix $UpdaterPath $NotebookPath
    if ($LASTEXITCODE -ne 0) {
        throw "Notebook update or validation failed."
    }
}
finally {
    Remove-Item -LiteralPath $UpdaterPath -Force -ErrorAction SilentlyContinue
}

Write-Step "Creating evidence and retaining this automation"
$EvidenceDirectory = Join-Path $ProjectPath "reports\evidence"
$ScriptsDirectory = Join-Path $ProjectPath "scripts"
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $ScriptsDirectory -Force | Out-Null

$StoredScriptPath = Join-Path $ScriptsDirectory $ScriptName
if ([System.IO.Path]::GetFullPath($PSCommandPath) -ne [System.IO.Path]::GetFullPath($StoredScriptPath)) {
    Copy-Item -LiteralPath $PSCommandPath -Destination $StoredScriptPath -Force
}

$ProjectRootNormalized = $ProjectPath.TrimEnd("\", "/")
$NotebookFullNormalized = [System.IO.Path]::GetFullPath($NotebookPath)
if (-not $NotebookFullNormalized.StartsWith($ProjectRootNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "The selected notebook is outside the project folder."
}
$NotebookRelative = $NotebookFullNormalized.Substring($ProjectRootNormalized.Length).TrimStart("\", "/").Replace("\", "/")
$EvidenceRelative = "reports/evidence/session34_github_deliverable.md"
$ScriptRelative = "scripts/$ScriptName"
$EvidencePath = Join-Path $ProjectPath $EvidenceRelative
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
$Evidence = @"
# Session 34 GitHub Deliverable Evidence

- Session: 34
- Topic: Decision Tree classification
- Project: $ProjectPath
- Notebook: $NotebookRelative
- Branch: $BranchName
- Validated: $Timestamp
- Notebook validation: PASS

## Implemented requirements

- Added a DecisionTreeClassifier with max_depth=5 and random_state=42.
- Trains on Xtr_f and yctr and predicts from Xte_f.
- Evaluates predictions against ycte with eval_clf.
- Reports both standard and at-risk-specific metrics.
- Adds exactly one Decision Tree row to the classification table.
- Includes a confusion matrix, tree visualization, text rules, and feature importance.
- Writes the Session 34 classification table and Decision Tree row as CSV files when executed.
- Includes artifact assertions and a responsible-use reflection.
- Generated cells are tagged session34, allowing safe replacement on reruns.
"@
Set-Content -LiteralPath $EvidencePath -Value $Evidence -Encoding UTF8

Write-Step "Staging only the Session 34 deliverable files"
Invoke-Git add -- $NotebookRelative $EvidenceRelative $ScriptRelative

& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No new staged changes were found; the deliverable may already be committed."
}
elseif ($LASTEXITCODE -eq 1) {
    Invoke-Git commit -m $CommitMessage
}
else {
    throw "Unable to inspect the staged Git changes."
}

Write-Step "Pushing $BranchName to GitHub"
Invoke-Git push -u origin $BranchName

Write-Step "Final verification"
$CurrentBranch = (& git branch --show-current).Trim()
if ($CurrentBranch -ne $BranchName) {
    throw "Unexpected current branch: $CurrentBranch"
}
Invoke-Git status --short

if (Get-Command code -ErrorAction SilentlyContinue) {
    & code $NotebookPath
}

Write-Host "`nSESSION 34 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Branch: $BranchName"
Write-Host "Notebook: $NotebookRelative"
Write-Host "Latest commit: $((& git log -1 --pretty='%h %s').Trim())"
