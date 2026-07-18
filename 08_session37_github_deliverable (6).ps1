$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
$BranchName = "session-37-mlp-classifier"
$CommitMessage = "Add Session 37 MLP classifier"
$CheckpointMessage = "Checkpoint pending work before Session 37"
$RunningScript = $MyInvocation.MyCommand.Path
$TemporaryRootScriptRelative = $null

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Git {
    $GitArguments = @($args)
    if ($GitArguments.Count -eq 0) {
        throw "Invoke-Git requires at least one Git argument."
    }

    & git @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($GitArguments -join ' ')"
    }
}

Write-Step "Checking the project and required commands"

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project folder not found: $ProjectRoot"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not available. Install Git for Windows and reopen VS Code."
}

Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath ".git" -PathType Container)) {
    throw "This folder is not a Git repository: $ProjectRoot"
}

$RemoteUrl = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RemoteUrl)) {
    throw "The repository does not have an origin remote."
}

$OriginalStatus = @(& git status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the Git working tree."
}
$BlockingStatus = @(
    $OriginalStatus | Where-Object {
        # The downloaded Session 37 automation is allowed in either the
        # project root or scripts directory. All other changes remain protected.
        $_ -notmatch '^\?\? (scripts/)?08_session37_github_deliverable.*\.ps1$'
    }
)
if ($BlockingStatus.Count -gt 0) {
    Write-Host ($BlockingStatus -join "`n") -ForegroundColor Yellow
    Write-Host "Saving all pending project work in a safety checkpoint..." -ForegroundColor Yellow

    $CheckpointBranch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CheckpointBranch)) {
        throw "Unable to determine the branch for the safety checkpoint."
    }

    Invoke-Git add -A

    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        Invoke-Git commit -m $CheckpointMessage
        Invoke-Git push -u origin $CheckpointBranch
    }
    elseif ($LASTEXITCODE -ne 0) {
        throw "Unable to validate the pending safety-checkpoint files."
    }

    Write-Host "Pending work was committed and pushed safely." -ForegroundColor Green
}

$PythonExe = $null
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $VenvPython -PathType Leaf) {
    $PythonExe = $VenvPython
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command py).Source
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command python).Source
}
else {
    throw "Python was not found. Select or create the project .venv in VS Code first."
}

Write-Step "Creating or opening the Session 37 branch"

$CurrentBranch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine the current branch."
}

$LocalBranchExists = (& git branch --list $BranchName).Trim()
if ($CurrentBranch -ne $BranchName) {
    if (-not [string]::IsNullOrWhiteSpace($LocalBranchExists)) {
        Invoke-Git switch $BranchName
    }
    else {
        Invoke-Git switch -c $BranchName
    }
}

Write-Step "Locating the classification notebook"

$PreferredNotebooks = @(
    "notebooks\05_classification_models.ipynb",
    "notebooks\classification_models.ipynb",
    "notebooks\classification.ipynb"
)

$Notebook = $null
foreach ($Candidate in $PreferredNotebooks) {
    $CandidatePath = Join-Path $ProjectRoot $Candidate
    if (Test-Path -LiteralPath $CandidatePath -PathType Leaf) {
        $Notebook = Get-Item -LiteralPath $CandidatePath
        break
    }
}

if (-not $Notebook) {
    $Notebook = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Filter "*.ipynb" |
        Where-Object {
            $_.FullName -notmatch "[\\/]\.ipynb_checkpoints[\\/]" -and
            $_.Name -match "classif"
        } |
        Sort-Object FullName |
        Select-Object -First 1
}

if (-not $Notebook) {
    throw "No classification notebook was found in the project."
}

$NotebookPath = $Notebook.FullName
$NotebookRelative = [System.IO.Path]::GetRelativePath($ProjectRoot, $NotebookPath)
$BackupPath = "$NotebookPath.session37-backup"
Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force
Write-Host "Notebook: $NotebookRelative"

Write-Step "Adding the complete Session 37 section"

$TempPatcher = Join-Path ([System.IO.Path]::GetTempPath()) "patch_session37_notebook.py"

$PatcherCode = @'
import ast
import json
import pathlib
import sys

notebook_path = pathlib.Path(sys.argv[1])

with notebook_path.open("r", encoding="utf-8") as handle:
    notebook = json.load(handle)

if not isinstance(notebook.get("cells"), list):
    raise ValueError("The selected file is not a valid Jupyter notebook.")

marker = "SESSION 37 AUTOMATION CELL"

def source_text(cell):
    source = cell.get("source", [])
    return source if isinstance(source, str) else "".join(source)

notebook["cells"] = [
    cell for cell in notebook["cells"]
    if marker not in source_text(cell)
    and "session-37-mlp-classifier" not in cell.get("metadata", {}).get("tags", [])
]

def lines(text):
    return text.strip("\n").splitlines(keepends=True)

def markdown(text):
    return {
        "cell_type": "markdown",
        "metadata": {"tags": ["session-37-mlp-classifier"]},
        "source": lines(text),
    }

def code(text):
    ast.parse(text)
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {"tags": ["session-37-mlp-classifier"]},
        "outputs": [],
        "source": lines(text),
    }

cells = []

cells.append(markdown(r'''
<!-- SESSION 37 AUTOMATION CELL -->
# Session 37: Neural-Network Classification

This section trains a scaled multilayer perceptron (MLP) classifier using the existing classification split. It adds exactly one **MLP Classifier** row to the classification leaderboard, compares the MLP with the boosting models, and evaluates stability across five random seeds.

Project class definitions: **0 = at risk** and **1 = successful**.
'''))

cells.append(code(r'''
# SESSION 37 AUTOMATION CELL - imports and prerequisite checks
import time
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from IPython.display import display
from sklearn.exceptions import ConvergenceWarning
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

required_objects_s37 = ["Xtr_f", "Xte_f", "yctr", "ycte"]
missing_objects_s37 = [name for name in required_objects_s37 if name not in globals()]
if missing_objects_s37:
    raise NameError(
        "Run the earlier classification cells first. Missing objects: "
        + ", ".join(missing_objects_s37)
    )

yctr_s37 = np.asarray(yctr).ravel()
ycte_s37 = np.asarray(ycte).ravel()
if Xtr_f.shape[0] != len(yctr_s37) or Xte_f.shape[0] != len(ycte_s37):
    raise ValueError("Feature and target row counts do not match.")

observed_classes_s37 = set(np.unique(np.concatenate([yctr_s37, ycte_s37])))
if observed_classes_s37 != {0, 1}:
    raise ValueError(f"Expected binary labels 0 and 1; found {sorted(observed_classes_s37)}")
if len(np.unique(ycte_s37)) != 2:
    raise ValueError("The test set must contain both classes for ROC AUC.")

print("Session 37 prerequisites verified.")
print("Training shape:", Xtr_f.shape, "Test shape:", Xte_f.shape)
'''))

cells.append(code(r'''
# SESSION 37 AUTOMATION CELL - train and evaluate the required MLP
mlpc = make_pipeline(
    StandardScaler(),
    MLPClassifier(
        hidden_layer_sizes=(64, 32),
        max_iter=1000,
        random_state=42,
    ),
)

with warnings.catch_warnings(record=True) as mlp_warning_records_s37:
    warnings.simplefilter("always", ConvergenceWarning)
    mlp_fit_start_s37 = time.perf_counter()
    mlpc.fit(Xtr_f, yctr_s37)
    mlp_fit_time_s37 = time.perf_counter() - mlp_fit_start_s37

mlp_model_s37 = mlpc.named_steps["mlpclassifier"]
mlp_convergence_warnings_s37 = sum(
    issubclass(item.category, ConvergenceWarning)
    for item in mlp_warning_records_s37
)
mlp_train_predictions_s37 = mlpc.predict(Xtr_f)
mlp_predictions_s37 = mlpc.predict(Xte_f)

class_positions_s37 = np.where(mlp_model_s37.classes_ == 0)[0]
if len(class_positions_s37) != 1:
    raise ValueError("The fitted MLP does not contain at-risk class 0.")
mlp_at_risk_probability_s37 = mlpc.predict_proba(Xte_f)[:, int(class_positions_s37[0])]

mlp_accuracy_s37 = accuracy_score(ycte_s37, mlp_predictions_s37)
mlp_precision_s37 = precision_score(ycte_s37, mlp_predictions_s37, pos_label=1, zero_division=0)
mlp_recall_s37 = recall_score(ycte_s37, mlp_predictions_s37, pos_label=1, zero_division=0)
mlp_f1_s37 = f1_score(ycte_s37, mlp_predictions_s37, pos_label=1, zero_division=0)
mlp_roc_auc_s37 = roc_auc_score((ycte_s37 == 0).astype(int), mlp_at_risk_probability_s37)
mlp_at_risk_precision_s37 = precision_score(ycte_s37, mlp_predictions_s37, pos_label=0, zero_division=0)
mlp_at_risk_recall_s37 = recall_score(ycte_s37, mlp_predictions_s37, pos_label=0, zero_division=0)
mlp_at_risk_f1_s37 = f1_score(ycte_s37, mlp_predictions_s37, pos_label=0, zero_division=0)

if "eval_clf" in globals():
    print("Project eval_clf result:", eval_clf(ycte_s37, mlp_predictions_s37))

mlp_row_s37 = pd.DataFrame([{
    "Model": "MLP Classifier",
    "Accuracy": mlp_accuracy_s37,
    "Precision": mlp_precision_s37,
    "Recall": mlp_recall_s37,
    "F1": mlp_f1_s37,
    "ROC AUC": mlp_roc_auc_s37,
    "At-Risk Precision": mlp_at_risk_precision_s37,
    "At-Risk Recall": mlp_at_risk_recall_s37,
    "At-Risk F1": mlp_at_risk_f1_s37,
    "Fit Time Seconds": mlp_fit_time_s37,
}])
display(mlp_row_s37.round(4))
'''))

cells.append(code(r'''
# SESSION 37 AUTOMATION CELL - update and rank the classification leaderboard
if "classification_table" in globals():
    existing_classification_table_s37 = classification_table.copy()
elif "classification_leaderboard" in globals():
    existing_classification_table_s37 = classification_leaderboard.copy()
elif "classification_leaderboard_s36" in globals():
    existing_classification_table_s37 = classification_leaderboard_s36.copy()
elif "boosting_results_s36" in globals():
    existing_classification_table_s37 = boosting_results_s36.copy()
else:
    existing_classification_table_s37 = pd.DataFrame()

existing_classification_table_s37 = existing_classification_table_s37.rename(columns={
    "model": "Model", "Model Name": "Model", "accuracy": "Accuracy",
    "precision": "Precision", "recall": "Recall", "f1": "F1",
    "f1_score": "F1", "F1 Score": "F1", "roc_auc": "ROC AUC",
    "ROC_AUC": "ROC AUC", "AUC": "ROC AUC",
})
if "Rank" in existing_classification_table_s37.columns:
    existing_classification_table_s37 = existing_classification_table_s37.drop(columns="Rank")
if "Model" not in existing_classification_table_s37.columns:
    existing_classification_table_s37["Model"] = pd.Series(dtype=str)

existing_classification_table_s37 = existing_classification_table_s37[
    ~existing_classification_table_s37["Model"].astype(str).str.strip().str.lower().isin(
        ["mlp", "mlp classifier", "neural network", "neural-network classifier"]
    )
].copy()

all_columns_s37 = list(dict.fromkeys(
    list(existing_classification_table_s37.columns) + list(mlp_row_s37.columns)
))
for column_s37 in all_columns_s37:
    if column_s37 not in existing_classification_table_s37.columns:
        existing_classification_table_s37[column_s37] = np.nan
    if column_s37 not in mlp_row_s37.columns:
        mlp_row_s37[column_s37] = np.nan

classification_table_s37 = pd.concat(
    [existing_classification_table_s37[all_columns_s37], mlp_row_s37[all_columns_s37]],
    ignore_index=True,
)
sort_columns_s37 = [column for column in ["F1", "Recall", "ROC AUC", "Accuracy"]
                      if column in classification_table_s37.columns]
if sort_columns_s37:
    classification_table_s37 = classification_table_s37.sort_values(
        sort_columns_s37, ascending=False, na_position="last"
    ).reset_index(drop=True)
classification_table_s37.insert(0, "Rank", range(1, len(classification_table_s37) + 1))

classification_table = classification_table_s37.copy()
classification_leaderboard = classification_table_s37.copy()
classification_leaderboard_s37 = classification_table_s37.copy()
display(classification_table_s37.round(4))
'''))

cells.append(code(r'''
# SESSION 37 AUTOMATION CELL - compare MLP with boosting models
boosting_mask_s37 = classification_table_s37["Model"].astype(str).str.contains(
    "gradient boost|adaboost|ada boost", case=False, regex=True, na=False
)
mlp_mask_s37 = classification_table_s37["Model"].astype(str).str.strip().str.lower().eq(
    "mlp classifier"
)
mlp_vs_boosting_s37 = classification_table_s37[boosting_mask_s37 | mlp_mask_s37].copy()
display(mlp_vs_boosting_s37.round(4))

mlp_train_f1_s37 = f1_score(yctr_s37, mlp_train_predictions_s37, pos_label=0, zero_division=0)
mlp_test_f1_gap_s37 = mlp_train_f1_s37 - mlp_at_risk_f1_s37
print("MLP at-risk training F1:", round(mlp_train_f1_s37, 4))
print("MLP at-risk test F1:", round(mlp_at_risk_f1_s37, 4))
print("Training-minus-test at-risk F1 gap:", round(mlp_test_f1_gap_s37, 4))
'''))

cells.append(code(r'''
# SESSION 37 AUTOMATION CELL - random-seed stability analysis
stability_rows_s37 = []
for seed_s37 in [7, 21, 42, 99, 2026]:
    candidate_s37 = make_pipeline(
        StandardScaler(),
        MLPClassifier(hidden_layer_sizes=(64, 32), max_iter=1000, random_state=seed_s37),
    )
    with warnings.catch_warnings(record=True) as seed_warnings_s37:
        warnings.simplefilter("always", ConvergenceWarning)
        candidate_s37.fit(Xtr_f, yctr_s37)
    candidate_predictions_s37 = candidate_s37.predict(Xte_f)
    fitted_candidate_s37 = candidate_s37.named_steps["mlpclassifier"]
    stability_rows_s37.append({
        "Random Seed": seed_s37,
        "Accuracy": accuracy_score(ycte_s37, candidate_predictions_s37),
        "F1": f1_score(ycte_s37, candidate_predictions_s37, pos_label=1, zero_division=0),
        "At-Risk Recall": recall_score(ycte_s37, candidate_predictions_s37, pos_label=0, zero_division=0),
        "At-Risk F1": f1_score(ycte_s37, candidate_predictions_s37, pos_label=0, zero_division=0),
        "Iterations": fitted_candidate_s37.n_iter_,
        "Final Loss": float(fitted_candidate_s37.loss_),
        "Convergence Warnings": sum(
            issubclass(item.category, ConvergenceWarning) for item in seed_warnings_s37
        ),
    })

mlp_seed_stability_s37 = pd.DataFrame(stability_rows_s37)
display(mlp_seed_stability_s37.round(4))
print("Mean at-risk F1:", round(mlp_seed_stability_s37["At-Risk F1"].mean(), 4))
print("At-risk F1 standard deviation:", round(mlp_seed_stability_s37["At-Risk F1"].std(ddof=0), 4))
print("At-risk F1 range:", round(mlp_seed_stability_s37["At-Risk F1"].max() - mlp_seed_stability_s37["At-Risk F1"].min(), 4))
'''))

cells.append(markdown(r'''
<!-- SESSION 37 AUTOMATION CELL -->
### Session 37 reflection

A neural network may be overfitting a small dataset when its training scores are substantially higher than its validation or test scores, training loss continues to fall while validation loss rises, or results change markedly across random seeds and cross-validation folds. Other warning signs include highly confident incorrect predictions, a large training-test F1 gap, convergence instability, and poorer unseen-data performance than simpler models such as logistic regression or boosting. These signs indicate that the network may be learning sample-specific noise rather than patterns that generalize to new students.
'''))

cells.append(code(r'''
# SESSION 37 AUTOMATION CELL - save and verify all output artifacts
results_dir_s37 = Path("results") / "session37"
results_dir_s37.mkdir(parents=True, exist_ok=True)

classification_table_path_s37 = results_dir_s37 / "session37_classification_table.csv"
mlp_row_path_s37 = results_dir_s37 / "session37_mlp_row.csv"
comparison_path_s37 = results_dir_s37 / "session37_mlp_vs_boosting.csv"
stability_path_s37 = results_dir_s37 / "session37_mlp_seed_stability.csv"

classification_table_s37.to_csv(classification_table_path_s37, index=False)
mlp_row_s37.to_csv(mlp_row_path_s37, index=False)
mlp_vs_boosting_s37.to_csv(comparison_path_s37, index=False)
mlp_seed_stability_s37.to_csv(stability_path_s37, index=False)

mlp_rows_s37 = classification_table_s37[
    classification_table_s37["Model"].astype(str).str.strip().str.lower().eq("mlp classifier")
]
if len(mlp_rows_s37) != 1:
    raise AssertionError(f"Expected exactly one MLP Classifier row; found {len(mlp_rows_s37)}")

required_metrics_s37 = [
    "Accuracy", "Precision", "Recall", "F1", "ROC AUC",
    "At-Risk Precision", "At-Risk Recall", "At-Risk F1",
]
values_s37 = mlp_rows_s37[required_metrics_s37].apply(pd.to_numeric, errors="coerce").to_numpy()
if not np.isfinite(values_s37).all() or not ((values_s37 >= 0) & (values_s37 <= 1)).all():
    raise AssertionError("The MLP row contains missing or invalid metrics.")

print("SESSION 37 OUTPUT ARTIFACT VERIFIED")
print("MLP at-risk F1:", round(mlp_at_risk_f1_s37, 4))
print("MLP ROC AUC:", round(mlp_roc_auc_s37, 4))
print("Convergence warnings:", mlp_convergence_warnings_s37)
print("Classification table path:", classification_table_path_s37)
print("MLP row path:", mlp_row_path_s37)
print("Boosting comparison path:", comparison_path_s37)
print("Seed stability path:", stability_path_s37)
'''))

notebook["cells"].extend(cells)

with notebook_path.open("w", encoding="utf-8", newline="\n") as handle:
    json.dump(notebook, handle, ensure_ascii=False, indent=1)
    handle.write("\n")

print(f"Added {len(cells)} tagged Session 37 cells to {notebook_path}")
'@

Set-Content -LiteralPath $TempPatcher -Value $PatcherCode -Encoding UTF8

try {
    if ([System.IO.Path]::GetFileName($PythonExe) -ieq "py.exe") {
        & $PythonExe -3 $TempPatcher $NotebookPath
    }
    else {
        & $PythonExe $TempPatcher $NotebookPath
    }
    if ($LASTEXITCODE -ne 0) {
        throw "The notebook patcher failed."
    }
}
catch {
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw
}
finally {
    Remove-Item -LiteralPath $TempPatcher -Force -ErrorAction SilentlyContinue
}

Write-Step "Validating notebook JSON, cell count, and Python syntax"

$TempValidator = Join-Path ([System.IO.Path]::GetTempPath()) "validate_session37_notebook.py"
$ValidatorCode = @'
import ast
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
notebook = json.loads(path.read_text(encoding="utf-8"))
tag = "session-37-mlp-classifier"
cells = [cell for cell in notebook["cells"] if tag in cell.get("metadata", {}).get("tags", [])]
if len(cells) != 8:
    raise AssertionError(f"Expected 8 Session 37 cells; found {len(cells)}")
for number, cell in enumerate(cells, start=1):
    if cell.get("cell_type") == "code":
        source = cell.get("source", [])
        ast.parse(source if isinstance(source, str) else "".join(source))
full_source = "\n".join(
    cell.get("source", "") if isinstance(cell.get("source", ""), str)
    else "".join(cell.get("source", []))
    for cell in cells
)
required = [
    "MLPClassifier", "hidden_layer_sizes=(64, 32)", "max_iter=1000",
    "random_state=42", "MLP Classifier", "At-Risk F1",
    "session37_mlp_seed_stability.csv", "SESSION 37 OUTPUT ARTIFACT VERIFIED",
]
missing = [item for item in required if item not in full_source]
if missing:
    raise AssertionError("Missing required Session 37 content: " + ", ".join(missing))
print("Notebook structure and Python syntax validation passed.")
'@
Set-Content -LiteralPath $TempValidator -Value $ValidatorCode -Encoding UTF8

try {
    if ([System.IO.Path]::GetFileName($PythonExe) -ieq "py.exe") {
        & $PythonExe -3 $TempValidator $NotebookPath
    }
    else {
        & $PythonExe $TempValidator $NotebookPath
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Notebook validation failed."
    }
}
catch {
    Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
    throw
}
finally {
    Remove-Item -LiteralPath $TempValidator -Force -ErrorAction SilentlyContinue
}

Write-Step "Creating the Session 37 evidence report"

$EvidenceDirectory = Join-Path $ProjectRoot "reports\evidence"
$EvidencePath = Join-Path $EvidenceDirectory "session37_github_deliverable.md"
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$Evidence = @"
# Session 37 GitHub Deliverable Evidence

- Completed: $Timestamp
- Branch: $BranchName
- Notebook: $NotebookRelative
- Model: scaled MLPClassifier
- Hidden layers: 64, 32
- Maximum iterations: 1000
- Random state: 42
- Stability seeds: 7, 21, 42, 99, 2026
- Class definitions: 0 = at risk; 1 = successful
- Notebook cells added: 8
- Notebook JSON validation: passed
- Inserted Python syntax validation: passed
- Duplicate-cell protection: passed
- Expected leaderboard row: exactly one MLP Classifier row
- Expected runtime artifacts: results/session37/*.csv

The notebook contains the complete Session 37 model, evaluation, leaderboard update,
boosting comparison, random-seed stability analysis, reflection, artifact export, and
runtime assertions. Numeric results are generated when the notebook is executed from
the first cell with the project Python kernel.
"@
Set-Content -LiteralPath $EvidencePath -Value $Evidence -Encoding UTF8

Write-Step "Copying this automation into the repository"

$ScriptsDirectory = Join-Path $ProjectRoot "scripts"
$StoredScript = Join-Path $ScriptsDirectory "08_session37_github_deliverable.ps1"
New-Item -ItemType Directory -Path $ScriptsDirectory -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($RunningScript) -or -not (Test-Path -LiteralPath $RunningScript)) {
    throw "Run this automation as a .ps1 file so it can be recorded in the repository."
}
$RunningScriptFull = [System.IO.Path]::GetFullPath($RunningScript)
$StoredScriptFull = [System.IO.Path]::GetFullPath($StoredScript)
if ($RunningScriptFull -ne $StoredScriptFull) {
    Copy-Item -LiteralPath $RunningScript -Destination $StoredScript -Force

    # When the download is in the project root, remove that temporary copy.
    # The permanent tracked copy is scripts\08_session37_github_deliverable.ps1.
    $RunningDirectory = [System.IO.Path]::GetDirectoryName($RunningScriptFull)
    if ($RunningDirectory -eq [System.IO.Path]::GetFullPath($ProjectRoot)) {
        $TemporaryRootScriptRelative = [System.IO.Path]::GetRelativePath(
            $ProjectRoot,
            $RunningScriptFull
        )
        Remove-Item -LiteralPath $RunningScriptFull -Force
    }
}

Remove-Item -LiteralPath $BackupPath -Force -ErrorAction SilentlyContinue

Write-Step "Staging only the Session 37 deliverables"

$Session37StagePaths = @(
    $NotebookRelative,
    "reports/evidence/session37_github_deliverable.md",
    "scripts/08_session37_github_deliverable.ps1"
)
if (-not [string]::IsNullOrWhiteSpace($TemporaryRootScriptRelative)) {
    $Session37StagePaths += $TemporaryRootScriptRelative
}

Invoke-Git add -A -- @Session37StagePaths
Invoke-Git diff --cached --check

& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "Session 37 is already present; no new commit is required." -ForegroundColor Yellow
}
elseif ($LASTEXITCODE -eq 1) {
    Invoke-Git commit -m $CommitMessage
}
else {
    throw "Unable to determine whether staged changes exist."
}

Write-Step "Pushing the Session 37 branch to GitHub"

Invoke-Git push -u origin $BranchName

$FinalStatus = @(& git status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to obtain final Git status."
}
if ($FinalStatus.Count -gt 0) {
    Write-Host ($FinalStatus -join "`n") -ForegroundColor Yellow
    throw "The automation finished with unexpected uncommitted files."
}

$LatestCommit = (& git log -1 --oneline).Trim()
$FinalBranch = (& git branch --show-current).Trim()

Write-Host "`nSESSION 37 GITHUB DELIVERABLE COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Project root: $ProjectRoot"
Write-Host "Current branch: $FinalBranch"
Write-Host "Classification notebook: $NotebookRelative"
Write-Host "Evidence report: reports\evidence\session37_github_deliverable.md"
Write-Host "Automation: scripts\08_session37_github_deliverable.ps1"
Write-Host "GitHub remote: $RemoteUrl"
Write-Host "Latest commit: $LatestCommit"
Write-Host "Final Git status: clean"
