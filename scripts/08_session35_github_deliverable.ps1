#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step([string]$Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
}

function Get-RelativePath([string]$BasePath, [string]$TargetPath) {
    $baseFull = [IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"
    $targetFull = [IO.Path]::GetFullPath($TargetPath)
    $baseUri = [Uri]$baseFull
    $targetUri = [Uri]$targetFull
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace("/", "\")
}

Write-Step "Session 35 preflight"
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project folder not found: $ProjectRoot"
}
Set-Location -LiteralPath $ProjectRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or is not available in PATH."
}
if (-not (Test-Path -LiteralPath ".git" -PathType Container)) {
    throw "This folder is not a Git repository: $ProjectRoot"
}

$originUrl = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($originUrl -join ""))) {
    throw "The Git remote named 'origin' is missing."
}

$stagedBefore = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect staged files." }
if ($stagedBefore.Count -gt 0) {
    throw "Already-staged files were found. Run 'git restore --staged .' and rerun this automation. No working files were deleted."
}

$python = $null
$pythonPrefix = @()
$pythonCandidates = @(
    (Join-Path $ProjectRoot ".venv\Scripts\python.exe"),
    (Join-Path $ProjectRoot "venv\Scripts\python.exe"),
    (Join-Path $ProjectRoot "env\Scripts\python.exe")
)
foreach ($candidate in $pythonCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $python = $candidate
        break
    }
}
if (-not $python) {
    $pyCommand = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCommand) {
        $python = $pyCommand.Source
        $pythonPrefix = @("-3")
    } else {
        $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCommand) { $python = $pythonCommand.Source }
    }
}
if (-not $python) {
    throw "Python was not found. Create .venv or install Python 3, then rerun."
}
& $python @pythonPrefix -c "import sys; print('Python:', sys.executable); assert sys.version_info >= (3, 9)"
if ($LASTEXITCODE -ne 0) { throw "Python 3.9 or newer is required." }

Write-Step "Switching to the Session 35 feature branch"
$branch = "session-35-random-forest-classifier"
$branchExists = (& git branch --list $branch)
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect local branches." }
if ([string]::IsNullOrWhiteSpace(($branchExists -join ""))) {
    Invoke-Git switch -c $branch
} else {
    Invoke-Git switch $branch
}

Write-Step "Locating the classification notebook"
$preferredNotebooks = @(
    "notebooks\05_classification_models.ipynb",
    "notebooks\classification_models.ipynb",
    "05_classification_models.ipynb",
    "classification_models.ipynb"
)
$notebook = $null
foreach ($relativePath in $preferredNotebooks) {
    $candidate = Join-Path $ProjectRoot $relativePath
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $notebook = (Resolve-Path -LiteralPath $candidate).Path
        break
    }
}
if (-not $notebook) {
    $notebook = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Filter "*.ipynb" |
        Where-Object { $_.FullName -notmatch '[\\/](\.venv|venv|env|\.git|backups?)[\\/]' } |
        Where-Object { $_.Name -match '(?i)classif' } |
        Sort-Object FullName |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $notebook) {
    throw "No classification notebook was found. Expected notebooks\05_classification_models.ipynb or a similarly named file."
}
$notebookRelative = (Get-RelativePath $ProjectRoot $notebook).Replace("\", "/")
Write-Host "Notebook: $notebookRelative"

$backupRoot = Join-Path $env:TEMP "student-performance-prediction-ml-session35-backups"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $backupRoot ("{0}_{1}.ipynb" -f ([IO.Path]::GetFileNameWithoutExtension($notebook)), $timestamp)
Copy-Item -LiteralPath $notebook -Destination $backupPath -Force
Write-Host "Backup: $backupPath"

Write-Step "Ensuring notebook support is installed"
& $python @pythonPrefix -c "import nbformat; print('nbformat:', nbformat.__version__)" 2>$null
if ($LASTEXITCODE -ne 0) {
    & $python @pythonPrefix -m pip install nbformat
    if ($LASTEXITCODE -ne 0) { throw "Unable to install the required nbformat package." }
}

Write-Step "Updating and validating the notebook"
$env:S35_NOTEBOOK = $notebook

$notebookEditor = @'
import ast
import os
from pathlib import Path

import nbformat
from nbformat.v4 import new_code_cell, new_markdown_cell

path = Path(os.environ["S35_NOTEBOOK"])
nb = nbformat.read(path, as_version=4)
tag = "session35-generated"

# Idempotency: remove only cells previously generated by this automation.
nb.cells = [
    cell for cell in nb.cells
    if tag not in cell.get("metadata", {}).get("tags", [])
]

def md(source, name):
    return new_markdown_cell(
        source=source.strip(),
        metadata={"tags": [tag, name]},
    )

def code(source, name):
    source = source.strip() + "\n"
    ast.parse(source)
    return new_code_cell(
        source=source,
        metadata={"tags": [tag, name]},
    )

cells = [
    md(
        r'''## Session 35: Random Forest Classification

This section trains a 300-tree Random Forest classifier and compares it with the single Decision Tree on the same held-out test set.

- Class `0` = at-risk student
- Class `1` = successful student
- Primary safety-oriented metric = at-risk recall (`pos_label=0`)
- Complementary discrimination metric = ROC AUC

The test set is used only for final evaluation, not for model selection or tuning.''',
        "session35-introduction",
    ),
    code(
        r'''# Session 35 - imports, prerequisite validation, and Random Forest training
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    roc_auc_score,
    ConfusionMatrixDisplay,
    RocCurveDisplay,
)

required_objects = ["Xtr_f", "Xte_f", "yctr", "ycte"]
missing_objects = [name for name in required_objects if name not in globals()]
if missing_objects:
    raise NameError(
        "Run the earlier classification data-preparation cells first. "
        f"Missing objects: {missing_objects}"
    )

# Preserve a Session 35-specific reference to the held-out labels.
ycte_s35 = ycte

rfc = RandomForestClassifier(
    n_estimators=300,
    random_state=42,
    n_jobs=-1,
)
rfc.fit(Xtr_f, yctr)

forest_predictions = rfc.predict(Xte_f)
forest_success_probability = rfc.predict_proba(Xte_f)[:, 1]
forest_at_risk_probability = rfc.predict_proba(Xte_f)[:, 0]

print("SESSION 35 RANDOM FOREST TRAINING PASSED")''',
        "session35-training",
    ),
    code(
        r'''# Session 35 - model evaluation, Decision Tree comparison, confusion matrix, and ROC curve
if "eval_clf" in globals() and callable(eval_clf):
    print("Existing eval_clf output:")
    print(eval_clf(ycte_s35, forest_predictions, forest_success_probability))

rf_accuracy = accuracy_score(ycte_s35, forest_predictions)
rf_success_precision = precision_score(ycte_s35, forest_predictions, pos_label=1, zero_division=0)
rf_success_recall = recall_score(ycte_s35, forest_predictions, pos_label=1, zero_division=0)
rf_success_f1 = f1_score(ycte_s35, forest_predictions, pos_label=1, zero_division=0)
rf_roc_auc = roc_auc_score(ycte_s35, forest_success_probability)
rf_at_risk_precision = precision_score(ycte_s35, forest_predictions, pos_label=0, zero_division=0)
rf_at_risk_recall = recall_score(ycte_s35, forest_predictions, pos_label=0, zero_division=0)
rf_at_risk_f1 = f1_score(ycte_s35, forest_predictions, pos_label=0, zero_division=0)
rf_at_risk_auc = roc_auc_score(
    (np.asarray(ycte_s35) == 0).astype(int),
    forest_at_risk_probability,
)

tree_at_risk_recall = None
if "tree_classifier_row" in globals():
    for key in ("Recall_At_Risk", "At-Risk Recall", "At_Risk_Recall"):
        if key in tree_classifier_row:
            tree_at_risk_recall = float(tree_classifier_row[key])
            break
if tree_at_risk_recall is None:
    for prediction_name in ("tree_predictions", "dt_predictions", "dtc_predictions", "y_pred_tree"):
        if prediction_name in globals():
            tree_at_risk_recall = recall_score(
                ycte_s35,
                globals()[prediction_name],
                pos_label=0,
                zero_division=0,
            )
            break
if tree_at_risk_recall is None:
    raise NameError(
        "A Decision Tree result is required for the recall comparison. "
        "Run the Session 34 Decision Tree cells first."
    )

recall_change = rf_at_risk_recall - tree_at_risk_recall
recall_comparison = pd.DataFrame(
    {
        "Model": ["Decision Tree", "Random Forest"],
        "Recall_At_Risk": [tree_at_risk_recall, rf_at_risk_recall],
    }
)
recall_comparison["Difference_From_Tree"] = [0.0, recall_change]

print("Random Forest Classification Metrics")
print("------------------------------------")
print(f"Accuracy:          {rf_accuracy:.4f}")
print(f"At-risk precision: {rf_at_risk_precision:.4f}")
print(f"At-risk recall:    {rf_at_risk_recall:.4f}")
print(f"At-risk F1:        {rf_at_risk_f1:.4f}")
print(f"ROC AUC:           {rf_roc_auc:.4f}")
print(f"Tree recall:       {tree_at_risk_recall:.4f}")
print(f"Recall change:     {recall_change:+.4f}")
display(recall_comparison)

session35_figure_dir = Path("results/session35")
session35_figure_dir.mkdir(parents=True, exist_ok=True)

fig, ax = plt.subplots(figsize=(5.5, 4.5))
ConfusionMatrixDisplay.from_predictions(
    ycte_s35,
    forest_predictions,
    display_labels=["At risk", "Successful"],
    cmap="Blues",
    colorbar=False,
    ax=ax,
)
ax.set_title("Session 35 Random Forest Confusion Matrix")
fig.tight_layout()
fig.savefig(session35_figure_dir / "session35_random_forest_confusion_matrix.png", dpi=200, bbox_inches="tight")
plt.show()

fig, ax = plt.subplots(figsize=(5.5, 4.5))
RocCurveDisplay.from_predictions(
    (np.asarray(ycte_s35) == 0).astype(int),
    forest_at_risk_probability,
    name="Random Forest (at risk)",
    ax=ax,
)
ax.plot([0, 1], [0, 1], "--", color="gray", label="Chance")
ax.set_title("Session 35 At-Risk ROC Curve")
ax.legend(loc="lower right")
fig.tight_layout()
fig.savefig(session35_figure_dir / "session35_random_forest_at_risk_roc.png", dpi=200, bbox_inches="tight")
plt.show()''',
        "session35-evaluation",
    ),
    code(
        r'''# Session 35 - add exactly one Random Forest row to the classification table
random_forest_row = {
    "Model": "Random Forest",
    "Accuracy": rf_accuracy,
    "Precision_Success": rf_success_precision,
    "Recall_Success": rf_success_recall,
    "F1_Success": rf_success_f1,
    "ROC_AUC": rf_roc_auc,
    "Precision_At_Risk": rf_at_risk_precision,
    "Recall_At_Risk": rf_at_risk_recall,
    "F1_At_Risk": rf_at_risk_f1,
    "ROC_AUC_At_Risk": rf_at_risk_auc,
}
random_forest_row_df = pd.DataFrame([random_forest_row])

if "classification_table" not in globals() or not isinstance(classification_table, pd.DataFrame):
    classification_table = pd.DataFrame(columns=random_forest_row_df.columns)

classification_table = classification_table.copy()
for column in random_forest_row_df.columns:
    if column not in classification_table.columns:
        classification_table[column] = np.nan
for column in classification_table.columns:
    if column not in random_forest_row_df.columns:
        random_forest_row_df[column] = np.nan

random_forest_row_df = random_forest_row_df[classification_table.columns]
classification_table = classification_table[
    classification_table["Model"].astype(str).str.strip().str.lower().ne("random forest")
].copy()
classification_table = pd.concat(
    [classification_table, random_forest_row_df],
    ignore_index=True,
)

random_forest_rows = classification_table[
    classification_table["Model"].astype(str).str.strip().str.lower().eq("random forest")
]
assert len(random_forest_rows) == 1, "The table must contain exactly one Random Forest row."

display(classification_table)
print("RANDOM FOREST CLASSIFICATION ROW PASSED")''',
        "session35-classification-row",
    ),
    code(
        r'''# Session 35 - save and verify reproducible output artifacts
SESSION35_OUTPUT_DIR = Path("results/session35")
SESSION35_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

classification_table_path = SESSION35_OUTPUT_DIR / "session35_classification_table.csv"
random_forest_row_path = SESSION35_OUTPUT_DIR / "session35_random_forest_row.csv"
recall_comparison_path = SESSION35_OUTPUT_DIR / "session35_recall_comparison.csv"

classification_table.to_csv(classification_table_path, index=False)
random_forest_row_df.to_csv(random_forest_row_path, index=False)
recall_comparison.to_csv(recall_comparison_path, index=False)

required_columns = [
    "Model", "Accuracy", "Precision_Success", "Recall_Success", "F1_Success",
    "ROC_AUC", "Precision_At_Risk", "Recall_At_Risk", "F1_At_Risk",
    "ROC_AUC_At_Risk",
]
missing_columns = [column for column in required_columns if column not in random_forest_row_df.columns]
assert not missing_columns, f"Missing Random Forest columns: {missing_columns}"
assert len(random_forest_row_df) == 1
assert random_forest_row_df.iloc[0]["Model"] == "Random Forest"

metric_values = random_forest_row_df[required_columns[1:]].to_numpy(dtype=float)
assert np.isfinite(metric_values).all()
assert ((metric_values >= 0) & (metric_values <= 1)).all()
assert classification_table_path.exists()
assert random_forest_row_path.exists()
assert recall_comparison_path.exists()

print("SESSION 35 OUTPUT ARTIFACT PASSED")
print("Saved:", classification_table_path)
print("Saved:", random_forest_row_path)
print("Saved:", recall_comparison_path)''',
        "session35-artifacts",
    ),
    md(
        r'''### Session 35 Reflection: Why use ROC AUC with accuracy?

ROC AUC complements accuracy because accuracy reports correctness at one selected classification cutoff and can appear high when successful students greatly outnumber at-risk students. A model could predict the majority class for nearly everyone and still attain high accuracy while missing students who may need support. ROC AUC instead measures how well the model ranks or separates the two classes across all possible thresholds. It should therefore be interpreted together with at-risk recall and precision: recall shows how many truly at-risk students are detected, while precision indicates how many alerts correspond to genuinely at-risk students. These measures support intervention planning; they do not justify surveillance, labeling, or causal claims.''',
        "session35-reflection",
    ),
]

nb.cells.extend(cells)
nbformat.validate(nb)

generated = [cell for cell in nb.cells if tag in cell.get("metadata", {}).get("tags", [])]
assert len(generated) == 6, f"Expected 6 Session 35 cells, found {len(generated)}"
all_source = "\n".join(cell.get("source", "") for cell in generated)
required_text = [
    "RandomForestClassifier",
    "n_estimators=300",
    "random_state=42",
    "predict_proba",
    "roc_auc_score",
    "pos_label=0",
    "tree_at_risk_recall",
    "classification_table",
    "session35_random_forest_row.csv",
]
missing_text = [item for item in required_text if item not in all_source]
assert not missing_text, f"Generated notebook content is missing: {missing_text}"

# Parse every generated code cell once more before writing.
for cell in generated:
    if cell.cell_type == "code":
        ast.parse(cell.source)

nbformat.write(nb, path)
print("NOTEBOOK_VALIDATION=PASS")
print("SESSION35_CELLS=6")
'@

$editorOutput = $notebookEditor | & $python @pythonPrefix -
if ($LASTEXITCODE -ne 0) {
    Copy-Item -LiteralPath $backupPath -Destination $notebook -Force
    throw "Notebook update or validation failed. The original notebook was restored from backup."
}
$editorOutput | ForEach-Object { Write-Host $_ }
if (($editorOutput -notcontains "NOTEBOOK_VALIDATION=PASS") -or ($editorOutput -notcontains "SESSION35_CELLS=6")) {
    Copy-Item -LiteralPath $backupPath -Destination $notebook -Force
    throw "Notebook validation markers were not produced. The original notebook was restored."
}

Write-Step "Creating the evidence report"
$evidenceDir = Join-Path $ProjectRoot "reports\evidence"
$scriptsDir = Join-Path $ProjectRoot "scripts"
New-Item -ItemType Directory -Path $evidenceDir, $scriptsDir -Force | Out-Null
$evidencePath = Join-Path $evidenceDir "session35_github_deliverable.md"
$scriptDestination = Join-Path $scriptsDir "08_session35_github_deliverable.ps1"

if ((Resolve-Path -LiteralPath $PSCommandPath).Path -ne $scriptDestination) {
    Copy-Item -LiteralPath $PSCommandPath -Destination $scriptDestination -Force
}

$validatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$evidence = @"
# Session 35 GitHub Deliverable Evidence

- Session: 35
- Topic: Random Forest classification
- Notebook: ``$notebookRelative``
- Feature branch: ``$branch``
- Validation timestamp: $validatedAt
- Model: ``RandomForestClassifier``
- Configuration: ``n_estimators=300`` and ``random_state=42``
- Probability predictions: included
- ROC AUC: included
- At-risk recall: calculated with ``pos_label=0``
- Decision Tree recall comparison: included
- Classification-table row: exactly one Random Forest row
- Output artifacts: defined under ``results/session35``
- Generated Session 35 cells: 6
- Notebook structural and Python syntax validation: PASS

The automation adds reproducible notebook code and does not fabricate model metrics. The notebook must be executed after its prerequisite data-preparation and Decision Tree cells to calculate actual results.
"@
Set-Content -LiteralPath $evidencePath -Value $evidence -Encoding UTF8

Write-Step "Committing only the Session 35 deliverable files"
$notebookGitPath = $notebookRelative
$evidenceGitPath = (Get-RelativePath $ProjectRoot $evidencePath).Replace("\", "/")
$scriptGitPath = (Get-RelativePath $ProjectRoot $scriptDestination).Replace("\", "/")

Invoke-Git add -- $notebookGitPath $evidenceGitPath $scriptGitPath

$stagedNow = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect staged Session 35 files." }
$allowed = @($notebookGitPath, $evidenceGitPath, $scriptGitPath)
$unexpected = @($stagedNow | Where-Object { $_ -notin $allowed })
if ($unexpected.Count -gt 0) {
    & git restore --staged -- $notebookGitPath $evidenceGitPath $scriptGitPath | Out-Null
    throw "Unexpected staged files detected: $($unexpected -join ', '). Session 35 files were unstaged."
}

if ($stagedNow.Count -gt 0) {
    Invoke-Git commit -m "Add Session 35 random forest classifier"
} else {
    Write-Host "No new Session 35 changes required; the generated content is already committed."
}

Write-Step "Pushing the feature branch to GitHub"
Invoke-Git push -u origin $branch

$currentBranch = (& git branch --show-current).Trim()
$latestCommit = (& git log -1 --oneline).Trim()
$status = @(& git status --porcelain)
if ($currentBranch -ne $branch) { throw "Unexpected current branch: $currentBranch" }
if ($status.Count -gt 0) {
    Write-Warning "The repository contains pre-existing or untracked working-tree changes. Session 35 files were committed and pushed successfully."
}

Write-Step "Final result"
Write-Host "NOTEBOOK_VALIDATION=PASS" -ForegroundColor Green
Write-Host "SESSION35_CELLS=6" -ForegroundColor Green
Write-Host "Branch: $currentBranch"
Write-Host "Latest commit: $latestCommit"
Write-Host "SESSION 35 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY" -ForegroundColor Green

$codeCommand = Get-Command code -ErrorAction SilentlyContinue
if ($codeCommand) {
    & code -r $notebook | Out-Null
}
