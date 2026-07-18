[CmdletBinding()]
param(
    [string]$RepoPath = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml",
    [string]$NotebookRelativePath = "notebooks\05_classification_models.ipynb",
    [string]$CommitMessage = "Add Session 32 logistic regression classification baseline"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage Exit code: $LASTEXITCODE"
    }
}

Write-Step "SESSION 32 SECTION 8 AUTOMATION STARTED"

if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    throw "Repository folder not found: $RepoPath"
}

Push-Location $RepoPath

try {
    Write-Step "VALIDATING THE REPOSITORY"

    if (-not (Test-Path -LiteralPath ".git" -PathType Container)) {
        throw "This folder is not a Git repository: $RepoPath"
    }

    $GitExecutable = (Get-Command git -ErrorAction Stop).Source

    if (Test-Path -LiteralPath ".venv\Scripts\python.exe") {
        $PythonExecutable = (Resolve-Path ".venv\Scripts\python.exe").Path
    }
    else {
        $PythonExecutable = (Get-Command python -ErrorAction Stop).Source
    }

    Invoke-Checked $GitExecutable @("--version") "Git validation failed."
    Invoke-Checked $PythonExecutable @("--version") "Python validation failed."

    $CurrentBranch = (& $GitExecutable branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CurrentBranch)) {
        throw "Unable to identify the current Git branch."
    }

    $OriginUrl = (& $GitExecutable remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($OriginUrl)) {
        throw "The Git remote named origin is not configured."
    }

    Write-Host "Repository: $RepoPath"
    Write-Host "Python:     $PythonExecutable"
    Write-Host "Branch:     $CurrentBranch"
    Write-Host "Remote:     $OriginUrl"

    Write-Step "PROTECTING EXISTING STAGED WORK"

    $InitiallyStaged = @(& $GitExecutable diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Git staging area."
    }
    if ($InitiallyStaged.Count -gt 0) {
        Write-Host "Files already staged:"
        $InitiallyStaged | ForEach-Object { Write-Host "  $_" }
        throw "Commit or unstage the files above, and then rerun this automation."
    }
    Write-Host "No unrelated files are staged."

    Write-Step "INSTALLING REQUIRED PYTHON PACKAGES"

    Invoke-Checked `
        $PythonExecutable `
        @(
            "-m", "pip", "install",
            "numpy", "pandas", "scikit-learn", "matplotlib",
            "ipython", "jupyter", "nbformat", "nbclient",
            "ipykernel", "pyarrow"
        ) `
        "Required package installation failed."

    $NotebookPath = Join-Path $RepoPath $NotebookRelativePath
    $NotebookDirectory = Split-Path -Parent $NotebookPath
    New-Item -ItemType Directory -Path $NotebookDirectory -Force | Out-Null

    if (Test-Path -LiteralPath $NotebookPath) {
        $BackupDirectory = Join-Path $env:TEMP "GSSRP_S32_Backups"
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath = Join-Path $BackupDirectory "05_classification_models_$Timestamp.ipynb"
        Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
        Write-Host "Existing notebook backup: $BackupPath"
    }

    Write-Step "CREATING AND EXECUTING THE NOTEBOOK"

    $RunnerPath = Join-Path $env:TEMP ("run_s32_" + [guid]::NewGuid().ToString("N") + ".py")

    $RunnerCode = @'
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import nbformat
from nbclient import NotebookClient


repo_root = Path(sys.argv[1]).resolve()
notebook_path = Path(sys.argv[2]).resolve()
os.chdir(repo_root)

title = r"""
# Session 32: Logistic Regression Classification

## Section 8 GitHub Deliverable

This notebook implements the interpretable Logistic Regression baseline for
student at-risk classification.

Target definition:

- `1` = at-risk student (`G3 < 10`)
- `0` = successful student (`G3 >= 10`)

The positive class is at risk, so recall measures the percentage of actual
at-risk students identified by the model.
"""

imports = r"""
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from IPython.display import display
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

REPO_ROOT = Path.cwd().resolve()
PROCESSED_DIR = REPO_ROOT / "data" / "processed"
RAW_DIR = REPO_ROOT / "data" / "raw"

print("Repository root:")
print(REPO_ROOT)
"""

load_data = r"""
def read_table(path):
    path = Path(path)
    suffix = path.suffix.lower()
    if suffix == ".csv":
        return pd.read_csv(path, sep=None, engine="python")
    if suffix == ".parquet":
        return pd.read_parquet(path)
    if suffix in {".pkl", ".pickle"}:
        return pd.read_pickle(path)
    raise ValueError(f"Unsupported data file: {path}")


def first_existing(paths):
    return next((Path(path) for path in paths if Path(path).exists()), None)


x_path = first_existing([
    PROCESSED_DIR / "X_full.parquet",
    PROCESSED_DIR / "X_full.csv",
    PROCESSED_DIR / "X_full.pkl",
    PROCESSED_DIR / "X_full.pickle",
])

y_path = first_existing([
    PROCESSED_DIR / "y_full.parquet",
    PROCESSED_DIR / "y_full.csv",
    PROCESSED_DIR / "y_full.pkl",
    PROCESSED_DIR / "y_full.pickle",
])

if x_path is not None and y_path is not None:
    X_full = read_table(x_path)
    y_loaded = read_table(y_path)
    if isinstance(y_loaded, pd.DataFrame):
        if "G3" in y_loaded.columns:
            y = y_loaded["G3"].copy()
        elif y_loaded.shape[1] == 1:
            y = y_loaded.iloc[:, 0].copy()
        else:
            raise ValueError("The target file must contain one column or G3.")
    else:
        y = pd.Series(y_loaded)
    data_source = f"{x_path.relative_to(REPO_ROOT)} and {y_path.relative_to(REPO_ROOT)}"
else:
    candidate_files = []
    for directory in [PROCESSED_DIR, RAW_DIR, REPO_ROOT / "data"]:
        if directory.exists():
            for pattern in ["*.csv", "*.parquet", "*.pkl", "*.pickle"]:
                candidate_files.extend(directory.rglob(pattern))

    excluded = {"classification", "leaderboard", "metric", "result", "coefficient", "prediction"}
    selected = None
    selected_path = None
    for candidate in sorted(set(candidate_files)):
        if any(term in candidate.name.lower() for term in excluded):
            continue
        try:
            frame = read_table(candidate)
        except Exception:
            continue
        if isinstance(frame, pd.DataFrame) and "G3" in frame.columns and frame.shape[0] >= 20:
            selected = frame
            selected_path = candidate
            break

    if selected is None:
        raise FileNotFoundError(
            "No usable dataset was found. Expected X_full/y_full files or a dataset containing G3."
        )

    y = selected["G3"].copy()
    X_full = selected.drop(columns=["G3"]).copy()
    data_source = str(selected_path.relative_to(REPO_ROOT))

X_full = pd.DataFrame(X_full).copy()
X_full = X_full.drop(
    columns=[column for column in X_full.columns if str(column).startswith("Unnamed:")],
    errors="ignore",
)
X_full = X_full.drop(columns=["G3"], errors="ignore")
X_full.columns = X_full.columns.map(str)
X_full = X_full.reset_index(drop=True)
y = pd.Series(np.asarray(y).reshape(-1), name="G3").reset_index(drop=True)
y = pd.to_numeric(y, errors="raise")

if len(X_full) != len(y):
    raise ValueError("Feature and target row counts do not match.")

print("Loaded data source:", data_source)
print("Original feature shape:", X_full.shape)
print("Target rows:", len(y))
"""

prepare = r"""
X_full = X_full.replace([np.inf, -np.inf], np.nan)
numeric_columns = X_full.select_dtypes(include="number").columns.tolist()
categorical_columns = [column for column in X_full.columns if column not in numeric_columns]

for column in numeric_columns:
    median = X_full[column].median()
    X_full[column] = X_full[column].fillna(0.0 if pd.isna(median) else median)

for column in categorical_columns:
    X_full[column] = X_full[column].astype("string").fillna("Missing")

X_full = pd.get_dummies(
    X_full,
    columns=categorical_columns,
    drop_first=True,
    dtype=float,
).astype(float)

if X_full.isna().any().any() or not np.isfinite(X_full.to_numpy()).all():
    raise ValueError("Prepared features contain missing or non-finite values.")
if "G3" in X_full.columns:
    raise ValueError("Target leakage detected: G3 is present among the features.")

Xtr_f, Xte_f, ytr, yte = train_test_split(
    X_full,
    y,
    test_size=0.20,
    random_state=42,
)

yc = (y < 10).astype(int)
yc.name = "at_risk"
yctr = yc.loc[ytr.index].copy()
ycte = yc.loc[yte.index].copy()

if set(yctr.unique()) != {0, 1} or set(ycte.unique()) != {0, 1}:
    raise ValueError("Both classes must be represented in the training and test sets.")

print("Prepared feature shape:", X_full.shape)
print("Training shape:", Xtr_f.shape)
print("Test shape:", Xte_f.shape)
print("Target definition: 1 = at-risk student with G3 < 10")
display(yctr.value_counts().sort_index().to_frame("Training count"))
display(ycte.value_counts().sort_index().to_frame("Test count"))
"""

model = r"""
def eval_clf(y_true, y_pred, y_proba=None):
    results = {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, zero_division=0),
        "recall": recall_score(y_true, y_pred, zero_division=0),
        "f1": f1_score(y_true, y_pred, zero_division=0),
    }
    if y_proba is not None:
        results["roc_auc"] = roc_auc_score(y_true, y_proba)
    return results


clf = make_pipeline(
    StandardScaler(),
    LogisticRegression(max_iter=1000, random_state=42),
)
clf.fit(Xtr_f, yctr)

y_pred_logistic = clf.predict(Xte_f)
y_proba_logistic = clf.predict_proba(Xte_f)[:, 1]
logistic_metrics = eval_clf(ycte, y_pred_logistic, y_proba_logistic)

logistic_metrics_df = pd.DataFrame([{
    "Model": "Logistic Regression",
    "Accuracy": logistic_metrics["accuracy"],
    "Precision": logistic_metrics["precision"],
    "Recall": logistic_metrics["recall"],
    "F1": logistic_metrics["f1"],
    "ROC_AUC": logistic_metrics["roc_auc"],
}])

print("Logistic Regression test metrics:")
display(logistic_metrics_df.round(4))

print(classification_report(
    ycte,
    y_pred_logistic,
    labels=[0, 1],
    target_names=["Successful", "At-risk"],
    digits=4,
    zero_division=0,
))
"""

interpretation = r"""
logistic_confusion_matrix = confusion_matrix(ycte, y_pred_logistic, labels=[0, 1])
display(pd.DataFrame(
    logistic_confusion_matrix,
    index=["Actual successful", "Actual at-risk"],
    columns=["Predicted successful", "Predicted at-risk"],
))

ConfusionMatrixDisplay(
    confusion_matrix=logistic_confusion_matrix,
    display_labels=["Successful", "At-risk"],
).plot(values_format="d")
plt.title("Session 32 Logistic Regression Confusion Matrix")
plt.tight_layout()
plt.show()

fitted_logistic = clf.named_steps["logisticregression"]
logistic_coefficients = pd.DataFrame({
    "Feature": Xtr_f.columns,
    "Coefficient": fitted_logistic.coef_[0],
})
logistic_coefficients["Absolute_Coefficient"] = logistic_coefficients["Coefficient"].abs()
logistic_coefficients["Odds_Ratio"] = np.exp(logistic_coefficients["Coefficient"])
logistic_coefficients["Direction"] = np.select(
    [logistic_coefficients["Coefficient"] > 0, logistic_coefficients["Coefficient"] < 0],
    ["Toward at-risk", "Toward successful"],
    default="No directional effect",
)
logistic_coefficients = logistic_coefficients.sort_values(
    "Absolute_Coefficient",
    ascending=False,
).reset_index(drop=True)

print("Largest coefficient magnitudes:")
display(logistic_coefficients.head(20).round(4))
"""

artifact = r"""
tn, fp, fn, tp = logistic_confusion_matrix.ravel()
classification_row = pd.DataFrame([{
    "Session": 32,
    "Model": "Logistic Regression",
    "Task": "Binary Classification",
    "Scenario": "Full-information",
    "Positive_Class": "At-risk: G3 < 10",
    "Decision_Threshold": 0.50,
    "Accuracy": logistic_metrics["accuracy"],
    "Precision": logistic_metrics["precision"],
    "Recall": logistic_metrics["recall"],
    "F1": logistic_metrics["f1"],
    "ROC_AUC": logistic_metrics["roc_auc"],
    "True_Negative": int(tn),
    "False_Positive": int(fp),
    "False_Negative": int(fn),
    "True_Positive": int(tp),
    "Test_Rows": int(len(ycte)),
}])

print("Session 32 classification-table row:")
display(classification_row.round(4))

assert isinstance(clf.named_steps["standardscaler"], StandardScaler)
assert isinstance(clf.named_steps["logisticregression"], LogisticRegression)
assert clf.named_steps["logisticregression"].max_iter == 1000
assert set(clf.classes_) == {0, 1}
assert len(y_pred_logistic) == len(ycte)
assert len(y_proba_logistic) == len(ycte)
assert np.isfinite(y_proba_logistic).all()
assert ((y_proba_logistic >= 0) & (y_proba_logistic <= 1)).all()
assert len(logistic_coefficients) == Xtr_f.shape[1]
assert classification_row.shape[0] == 1
assert classification_row.loc[0, "Positive_Class"] == "At-risk: G3 < 10"

print("SESSION 32 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY")
print(f"Accuracy: {logistic_metrics['accuracy']:.4f}")
print(f"At-risk recall: {logistic_metrics['recall']:.4f}")
print("Notebook: notebooks/05_classification_models.ipynb")
"""

nb = nbformat.v4.new_notebook(
    cells=[
        nbformat.v4.new_markdown_cell(title),
        nbformat.v4.new_markdown_cell("## 1. Imports and repository configuration"),
        nbformat.v4.new_code_cell(imports),
        nbformat.v4.new_markdown_cell("## 2. Load the full-information dataset"),
        nbformat.v4.new_code_cell(load_data),
        nbformat.v4.new_markdown_cell("## 3. Prepare features and reproduce the fixed split"),
        nbformat.v4.new_code_cell(prepare),
        nbformat.v4.new_markdown_cell("## 4. Train and evaluate Logistic Regression"),
        nbformat.v4.new_code_cell(model),
        nbformat.v4.new_markdown_cell("## 5. Confusion matrix and coefficient interpretation"),
        nbformat.v4.new_code_cell(interpretation),
        nbformat.v4.new_markdown_cell("## 6. Classification-table row and final validation"),
        nbformat.v4.new_code_cell(artifact),
    ],
    metadata={},
)

kernel_root = Path(tempfile.mkdtemp(prefix="gssrp_s32_kernel_"))
kernel_name = "gssrp-s32"
kernel_dir = kernel_root / "kernels" / kernel_name
kernel_dir.mkdir(parents=True)
(kernel_dir / "kernel.json").write_text(
    json.dumps({
        "argv": [sys.executable, "-m", "ipykernel_launcher", "-f", "{connection_file}"],
        "display_name": "GSSRP Session 32",
        "language": "python",
    }),
    encoding="utf-8",
)

previous_jupyter_path = os.environ.get("JUPYTER_PATH")
os.environ["JUPYTER_PATH"] = str(kernel_root) + (
    os.pathsep + previous_jupyter_path if previous_jupyter_path else ""
)

try:
    nb.metadata["kernelspec"] = {
        "display_name": "GSSRP Session 32",
        "language": "python",
        "name": kernel_name,
    }
    client = NotebookClient(
        nb,
        timeout=600,
        kernel_name=kernel_name,
        resources={"metadata": {"path": str(repo_root)}},
    )
    client.execute()
finally:
    if previous_jupyter_path is None:
        os.environ.pop("JUPYTER_PATH", None)
    else:
        os.environ["JUPYTER_PATH"] = previous_jupyter_path
    shutil.rmtree(kernel_root, ignore_errors=True)

notebook_path.parent.mkdir(parents=True, exist_ok=True)
nbformat.write(nb, notebook_path)

errors = []
output_text = []
for cell in nb.cells:
    for output in cell.get("outputs", []):
        if output.get("output_type") == "error":
            errors.append(output)
        text = output.get("text", "")
        if isinstance(text, list):
            output_text.extend(text)
        elif text:
            output_text.append(str(text))

if errors:
    raise RuntimeError(f"Executed notebook contains {len(errors)} errors.")

completion = "SESSION 32 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY"
if completion not in "\n".join(output_text):
    raise RuntimeError("The notebook completion message was not found.")

print(f"Notebook created and executed: {notebook_path}")
print(completion)
'@

    Set-Content -LiteralPath $RunnerPath -Value $RunnerCode -Encoding UTF8

    try {
        Invoke-Checked `
            $PythonExecutable `
            @($RunnerPath, $RepoPath, $NotebookPath) `
            "Notebook creation or execution failed."
    }
    finally {
        if (Test-Path -LiteralPath $RunnerPath) {
            Remove-Item -LiteralPath $RunnerPath -Force
        }
    }

    if (-not (Test-Path -LiteralPath $NotebookPath -PathType Leaf)) {
        throw "The required notebook was not created: $NotebookPath"
    }

    Write-Step "STAGING ONLY THE SESSION 32 NOTEBOOK"

    Invoke-Checked `
        $GitExecutable `
        @("add", "--", $NotebookRelativePath) `
        "Unable to stage the Session 32 notebook."

    $StagedFiles = @(& $GitExecutable diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list staged files."
    }

    $ExpectedGitPath = $NotebookRelativePath -replace "\\", "/"
    $UnexpectedFiles = @($StagedFiles | Where-Object { $_ -ne $ExpectedGitPath })
    if ($UnexpectedFiles.Count -gt 0) {
        throw "Unexpected staged files detected: $($UnexpectedFiles -join ', ')"
    }

    Write-Step "COMMITTING THE SESSION 32 DELIVERABLE"

    & $GitExecutable diff --cached --quiet -- $NotebookRelativePath
    $DiffExitCode = $LASTEXITCODE

    if ($DiffExitCode -eq 1) {
        Invoke-Checked `
            $GitExecutable `
            @("commit", "-m", $CommitMessage) `
            "Git commit failed."
    }
    elseif ($DiffExitCode -eq 0) {
        Write-Host "The notebook already matches the committed version."
    }
    else {
        throw "Unable to inspect the staged notebook change."
    }

    Write-Step "PUSHING TO GITHUB"

    & $GitExecutable push -u origin $CurrentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Initial push failed. Attempting pull --rebase --autostash."
        Invoke-Checked `
            $GitExecutable `
            @("pull", "--rebase", "--autostash", "origin", $CurrentBranch) `
            "Unable to rebase onto the remote branch."
        Invoke-Checked `
            $GitExecutable `
            @("push", "-u", "origin", $CurrentBranch) `
            "GitHub push failed after the rebase."
    }

    Write-Step "VERIFYING THE GITHUB PUSH"

    $LocalCommit = (& $GitExecutable rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read the local commit hash."
    }

    $RemoteReference = @(& $GitExecutable ls-remote origin "refs/heads/$CurrentBranch")
    if ($LASTEXITCODE -ne 0 -or $RemoteReference.Count -eq 0) {
        throw "Unable to read the GitHub branch commit."
    }

    $RemoteCommit = ($RemoteReference[0] -split "\s+")[0]
    if ($LocalCommit -ne $RemoteCommit) {
        throw "Local and GitHub commit hashes do not match. Local: $LocalCommit Remote: $RemoteCommit"
    }

    Write-Step "FINAL REPOSITORY STATUS"
    & $GitExecutable status --short
    & $GitExecutable log -1 --oneline

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "SESSION 32 SECTION 8 COMPLETED SUCCESSFULLY"
    Write-Host "============================================================"
    Write-Host "Notebook: $NotebookPath"
    Write-Host "Branch: $CurrentBranch"
    Write-Host "Verified GitHub commit: $RemoteCommit"
}
finally {
    Pop-Location
}
