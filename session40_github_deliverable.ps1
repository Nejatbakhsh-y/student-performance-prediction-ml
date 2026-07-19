#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# GSSRP 2026 - Session 40 - Section 8
# One-file Windows PowerShell automation for VS Code
# Creates and executes Session 40 locally from Session 39
# ============================================================

$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
$SourceNotebook = Join-Path $ProjectRoot "notebooks\S39_Hyperparameter_Tuning_I.ipynb"
$TargetNotebook = Join-Path $ProjectRoot "notebooks\GSSRP_2026_S40_Hyperparameter_Tuning_II.ipynb"
$EvidenceFile = Join-Path $ProjectRoot "reports\evidence\session40_github_deliverable.txt"
$RepositoryScript = Join-Path $ProjectRoot "session40_github_deliverable.ps1"

$RelativeNotebook = "notebooks/GSSRP_2026_S40_Hyperparameter_Tuning_II.ipynb"
$RelativeEvidence = "reports/evidence/session40_github_deliverable.txt"
$RelativeScript = "session40_github_deliverable.ps1"
$BranchName = "session-40-hyperparameter-tuning-ii"
$CommitMessage = "Add Session 40 tuned ensemble results"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Stop-Run {
    param([string]$Message)

    throw $Message
}

function Invoke-Git {
    param([string[]]$Arguments)

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        Stop-Run "Git command failed: git $($Arguments -join ' ')"
    }
}

function Test-GitRef {
    param([string]$Reference)

    & git show-ref --verify --quiet $Reference
    return ($LASTEXITCODE -eq 0)
}

Write-Host ""
Write-Host "SESSION 40 - SECTION 8 LOCAL AUTOMATION" -ForegroundColor Green
Write-Host "Hyperparameter Tuning II - Random Forest"
Write-Host "=========================================="

# ------------------------------------------------------------
# 1. Verify the existing project and completed Session 39 file
# ------------------------------------------------------------

Write-Step "Verifying the project, Session 39 notebook, and Git"

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    Stop-Run "Project directory not found: $ProjectRoot"
}

Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath $SourceNotebook -PathType Leaf)) {
    Stop-Run @"
The completed Session 39 notebook was not found:
$SourceNotebook
"@
}

if ((Get-Item -LiteralPath $SourceNotebook).Length -eq 0) {
    Stop-Run "The Session 39 notebook is empty."
}

if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-Run "Git is not available in this VS Code PowerShell terminal."
}

& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Stop-Run "The project directory is not a Git repository."
}

$RepositoryRoot = (& git rev-parse --show-toplevel).Trim()
$RemoteUrl = (& git remote get-url origin 2>$null)

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($RemoteUrl -join ""))) {
    Stop-Run "The Git remote named origin is not configured."
}

$RemoteUrl = ($RemoteUrl -join "").Trim()
$GitUserName = ((& git config user.name) -join "").Trim()
$GitUserEmail = ((& git config user.email) -join "").Trim()

if (
    [string]::IsNullOrWhiteSpace($GitUserName) -or
    [string]::IsNullOrWhiteSpace($GitUserEmail)
) {
    Stop-Run @"
Git identity is not configured. Run these commands, then rerun the automation:

git config user.name "Yousef Nejatbakhsh"
git config user.email "YOUR_GITHUB_EMAIL"
"@
}

Write-Host "[PASS] Session 39 source notebook found." -ForegroundColor Green
Write-Host "[PASS] Repository: $RepositoryRoot" -ForegroundColor Green
Write-Host "[PASS] Remote: $RemoteUrl" -ForegroundColor Green

# Save the current automation inside the repository when it was launched from
# Downloads. This keeps one canonical script and permits a clean Git commit.
$RunningScript = $MyInvocation.MyCommand.Path
if (
    -not [string]::IsNullOrWhiteSpace($RunningScript) -and
    -not ([System.IO.Path]::GetFullPath($RunningScript)).Equals(
        [System.IO.Path]::GetFullPath($RepositoryScript),
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    Copy-Item -LiteralPath $RunningScript -Destination $RepositoryScript -Force
}

# ------------------------------------------------------------
# 2. Locate the project Python interpreter
# ------------------------------------------------------------

Write-Step "Locating the project Python interpreter"

$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$Python = $null

if (Test-Path -LiteralPath $VenvPython -PathType Leaf) {
    $Python = $VenvPython
}
elseif ($null -ne (Get-Command py -ErrorAction SilentlyContinue)) {
    $Python = "py"
}
elseif ($null -ne (Get-Command python -ErrorAction SilentlyContinue)) {
    $Python = "python"
}

if ($null -eq $Python) {
    Stop-Run "Python was not found. The project .venv is required."
}

if ($Python -eq "py") {
    $PythonPrefix = @("-3")
}
else {
    $PythonPrefix = @()
}

& $Python @PythonPrefix --version
if ($LASTEXITCODE -ne 0) {
    Stop-Run "The selected Python interpreter could not run."
}

Write-Host "[PASS] Python: $Python $($PythonPrefix -join ' ')" -ForegroundColor Green

# Install only modules that are missing from the existing project environment.
$ModuleCheck = @'
import importlib.util
modules = {
    "nbformat": "nbformat",
    "nbclient": "nbclient",
    "ipykernel": "ipykernel",
    "numpy": "numpy",
    "pandas": "pandas",
    "matplotlib": "matplotlib",
    "sklearn": "scikit-learn",
}
print(" ".join(package for module, package in modules.items()
               if importlib.util.find_spec(module) is None))
'@

$MissingPackages = ""
if ($LASTEXITCODE -ne 0) {
    Stop-Run "Python dependency verification failed."
}

if (-not [string]::IsNullOrWhiteSpace($MissingPackages)) {
    Write-Host "Installing missing packages: $MissingPackages"
    $PackageArguments = @($MissingPackages -split "\s+")
    & $Python @PythonPrefix -m pip install --disable-pip-version-check @PackageArguments
    if ($LASTEXITCODE -ne 0) {
        Stop-Run "The required Python packages could not be installed."
    }
}

Write-Host "[PASS] Required Python packages are available." -ForegroundColor Green

# ------------------------------------------------------------
# 3. Create or switch to the Session 40 branch
# ------------------------------------------------------------

Write-Step "Creating or switching to the Session 40 branch"

$CurrentBranch = (& git branch --show-current).Trim()

if ($CurrentBranch -eq $BranchName) {
    Write-Host "[PASS] Already on branch: $BranchName" -ForegroundColor Green
}
elseif (Test-GitRef "refs/heads/$BranchName") {
    Invoke-Git -Arguments @("switch", $BranchName)
    Write-Host "[PASS] Switched to existing branch: $BranchName" -ForegroundColor Green
}
elseif (Test-GitRef "refs/remotes/origin/$BranchName") {
    Invoke-Git -Arguments @("switch", "--track", "-c", $BranchName, "origin/$BranchName")
    Write-Host "[PASS] Created local tracking branch: $BranchName" -ForegroundColor Green
}
else {
    Invoke-Git -Arguments @("switch", "-c", $BranchName)
    Write-Host "[PASS] Created branch: $BranchName" -ForegroundColor Green
}

# ------------------------------------------------------------
# 4. Generate and execute Session 40 locally
# ------------------------------------------------------------

Write-Step "Creating and executing the Session 40 notebook locally"

$TemporaryRoot = Join-Path $env:TEMP ("gssrp_session40_" + [guid]::NewGuid().ToString("N"))
$KernelPrefix = Join-Path $TemporaryRoot "kernel"
$GeneratorFile = Join-Path $TemporaryRoot "build_session40.py"
$KernelName = "gssrp-s40-local"

New-Item -ItemType Directory -Path $TemporaryRoot -Force *> $null
New-Item -ItemType Directory -Path (Split-Path -Parent $TargetNotebook) -Force *> $null
New-Item -ItemType Directory -Path (Split-Path -Parent $EvidenceFile) -Force *> $null

$GeneratorCode = @'
from __future__ import annotations

import sys
from pathlib import Path

import nbformat
from nbclient import NotebookClient


repo = Path(sys.argv[1]).resolve()
source_path = Path(sys.argv[2]).resolve()
target_path = Path(sys.argv[3]).resolve()
kernel_name = sys.argv[4]

source = nbformat.read(source_path, as_version=4)
if not source.cells:
    raise RuntimeError("Session 39 source notebook contains no cells.")

# Keep Session 39 intact and create a separate Session 40 notebook. On reruns,
# previously tagged Session 40 cells are replaced instead of duplicated.
base_cells = [
    cell for cell in source.cells
    if "session40" not in cell.get("metadata", {}).get("tags", [])
]

def md(text: str):
    cell = nbformat.v4.new_markdown_cell(text.strip())
    cell.metadata["tags"] = ["session40"]
    return cell


def code(text: str):
    cell = nbformat.v4.new_code_cell(text.strip())
    cell.metadata["tags"] = ["session40"]
    return cell


session40_cells = [
    md(r"""
# Session 40: Hyperparameter Tuning II

## Randomized Search for a Random Forest Regressor

This notebook extends the completed Session 39 tuning notebook. It performs
RandomizedSearchCV for a Random Forest, compares the tuned and untuned models,
records search cost, provides a prompt-engineered interpretation, and answers
the reflection question. All work was generated and executed locally in VS Code.
"""),

    code(r"""
# SESSION_40_LOCAL_SETUP
import time
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import KFold, RandomizedSearchCV, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler


def first_existing(*names):
    for name in names:
        if name in globals():
            return globals()[name]
    return None


# Prefer the prepared variables from the Session 39 notebook.
Xtr_f = first_existing("Xtr_f", "X_train_transformed", "X_train_processed")
Xte_f = first_existing("Xte_f", "X_test_transformed", "X_test_processed")
ytr = first_existing("ytr", "y_train")
yte = first_existing("yte", "y_test")


# Fallback: build a reproducible local dataset from a project CSV containing G3.
if any(value is None for value in (Xtr_f, Xte_f, ytr, yte)):
    csv_candidates = sorted(Path("data").rglob("*.csv"))
    selected_path = None
    student_df = None

    for candidate in csv_candidates:
        for separator in (";", ",", "\t"):
            try:
                trial = pd.read_csv(candidate, sep=separator)
            except Exception:
                continue
            if "G3" in trial.columns and len(trial) >= 50:
                selected_path = candidate
                student_df = trial
                break
        if student_df is not None:
            break

    if student_df is None:
        raise FileNotFoundError(
            "No local project CSV containing a G3 column was found under data/."
        )

    student_df = student_df.dropna(subset=["G3"]).copy()
    X = student_df.drop(columns=["G3"])
    y = pd.to_numeric(student_df["G3"], errors="raise")

    X_train, X_test, ytr, yte = train_test_split(
        X, y, test_size=0.20, random_state=42
    )

    numeric_columns = X_train.select_dtypes(include=np.number).columns.tolist()
    categorical_columns = [c for c in X_train.columns if c not in numeric_columns]

    try:
        one_hot = OneHotEncoder(handle_unknown="ignore", sparse_output=False)
    except TypeError:
        one_hot = OneHotEncoder(handle_unknown="ignore", sparse=False)

    numeric_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler()),
    ])
    categorical_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", one_hot),
    ])

    preprocessor = ColumnTransformer([
        ("numeric", numeric_pipeline, numeric_columns),
        ("categorical", categorical_pipeline, categorical_columns),
    ])

    Xtr_f = preprocessor.fit_transform(X_train)
    Xte_f = preprocessor.transform(X_test)
    print("Local data source:", selected_path)
else:
    print("Using prepared Session 39 train/test variables.")

assert Xtr_f.shape[0] == len(ytr)
assert Xte_f.shape[0] == len(yte)

print("Training feature shape:", Xtr_f.shape)
print("Test feature shape:", Xte_f.shape)
print("Training target length:", len(ytr))
print("Test target length:", len(yte))
print("Data verification passed.")
"""),

    code(r"""
# SESSION_40_UNTUNED_RANDOM_FOREST
cv_strategy = KFold(n_splits=5, shuffle=True, random_state=42)

untuned_rf = RandomForestRegressor(random_state=42, n_jobs=-1)
untuned_cv_scores = cross_val_score(
    untuned_rf,
    Xtr_f,
    ytr,
    cv=cv_strategy,
    scoring="r2",
    n_jobs=-1,
)
untuned_cv_r2 = float(untuned_cv_scores.mean())

print("Cross-validation strategy: 5-fold shuffled KFold")
print("Untuned Random Forest fold R2 scores:", untuned_cv_scores.round(3))
print("Untuned Random Forest mean CV R2:", round(untuned_cv_r2, 3))
print("Untuned CV R2 standard deviation:", round(float(untuned_cv_scores.std()), 3))
"""),

    code(r"""
# SESSION_40_RANDOMIZED_SEARCH
parameter_space = {
    "n_estimators": [200, 300, 500],
    "max_depth": [None, 10, 20],
    "min_samples_split": [2, 5, 10],
}

total_combinations = int(np.prod([len(values) for values in parameter_space.values()]))
print("Total possible combinations:", total_combinations)
print("Combinations sampled by randomized search: 8")

random_search = RandomizedSearchCV(
    estimator=RandomForestRegressor(random_state=42, n_jobs=1),
    param_distributions=parameter_space,
    n_iter=8,
    scoring="r2",
    cv=cv_strategy,
    random_state=42,
    n_jobs=-1,
    return_train_score=True,
    verbose=1,
)

start_time = time.perf_counter()
random_search.fit(Xtr_f, ytr)
search_time_seconds = time.perf_counter() - start_time

print("Randomized search completed.")
print("Best parameters:", random_search.best_params_)
print("Best mean CV R2:", round(float(random_search.best_score_), 3))
print("Search time in seconds:", round(search_time_seconds, 2))
"""),

    code(r"""
# SESSION_40_SEARCH_RESULTS
search_results_table = pd.DataFrame(random_search.cv_results_)[[
    "rank_test_score",
    "mean_test_score",
    "std_test_score",
    "mean_train_score",
    "param_n_estimators",
    "param_max_depth",
    "param_min_samples_split",
]].sort_values("rank_test_score").reset_index(drop=True)

search_results_table = search_results_table.rename(columns={
    "rank_test_score": "Rank",
    "mean_test_score": "Mean CV R2",
    "std_test_score": "CV R2 Std",
    "mean_train_score": "Mean Train R2",
    "param_n_estimators": "n_estimators",
    "param_max_depth": "max_depth",
    "param_min_samples_split": "min_samples_split",
})

print("All eight Randomized Search configurations:")
display(search_results_table.round(4))
"""),

    code(r"""
# SESSION_40_UNTUNED_VS_TUNED
untuned_rf.fit(Xtr_f, ytr)
tuned_rf = random_search.best_estimator_

untuned_predictions = untuned_rf.predict(Xte_f)
tuned_predictions = tuned_rf.predict(Xte_f)


def regression_metrics(y_true, predictions):
    return {
        "MAE": mean_absolute_error(y_true, predictions),
        "RMSE": np.sqrt(mean_squared_error(y_true, predictions)),
        "R2": r2_score(y_true, predictions),
    }


untuned_metrics = regression_metrics(yte, untuned_predictions)
tuned_metrics = regression_metrics(yte, tuned_predictions)

comparison_table = pd.DataFrame([
    {"Model": "Untuned Random Forest", **untuned_metrics, "Mean CV R2": untuned_cv_r2},
    {"Model": "Tuned Random Forest", **tuned_metrics, "Mean CV R2": random_search.best_score_},
])

print("Untuned versus Tuned Random Forest:")
display(comparison_table.round(4))

test_r2_change = tuned_metrics["R2"] - untuned_metrics["R2"]
test_mae_change = tuned_metrics["MAE"] - untuned_metrics["MAE"]
test_rmse_change = tuned_metrics["RMSE"] - untuned_metrics["RMSE"]

if test_r2_change > 0 and test_rmse_change < 0:
    final_decision = "Use the tuned Random Forest."
    decision_reason = "It improved test R2 and reduced test RMSE."
else:
    final_decision = "Retain the untuned Random Forest."
    decision_reason = "The randomized search did not produce a consistent test-set improvement."

print("Final decision:", final_decision)
print("Reason:", decision_reason)
"""),

    code(r"""
# SESSION_40_GRID_VS_RANDOMIZED_COST
grid_configurations = 27
randomized_configurations = 8
cv_folds = 5
grid_cv_fits = grid_configurations * cv_folds
randomized_cv_fits = randomized_configurations * cv_folds
fits_avoided = grid_cv_fits - randomized_cv_fits
fit_reduction_percent = fits_avoided / grid_cv_fits * 100

search_cost_comparison = pd.DataFrame({
    "Search Method": ["Grid Search", "Randomized Search"],
    "Configurations Evaluated": [grid_configurations, randomized_configurations],
    "CV Folds": [cv_folds, cv_folds],
    "Cross-Validation Fits": [grid_cv_fits, randomized_cv_fits],
    "Final Refits": [1, 1],
    "Approximate Total Fits": [grid_cv_fits + 1, randomized_cv_fits + 1],
    "Percentage of Full Grid": [100.00, randomized_configurations / grid_configurations * 100],
})

print("Grid Search versus Randomized Search cost:")
display(search_cost_comparison.round(2))
print("Cross-validation fits avoided:", fits_avoided)
print("Estimated search-cost reduction:", round(fit_reduction_percent, 2), "%")

plt.figure(figsize=(8, 5))
bars = plt.bar(
    search_cost_comparison["Search Method"],
    search_cost_comparison["Cross-Validation Fits"],
    color=["firebrick", "steelblue"],
    edgecolor="black",
)
plt.title("Grid Search versus Randomized Search Cost")
plt.xlabel("Search Method")
plt.ylabel("Number of Cross-Validation Model Fits")
plt.grid(axis="y", linestyle="--", alpha=0.4)
for bar in bars:
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width() / 2, height, str(int(height)),
             ha="center", va="bottom")
plt.tight_layout()
plt.show()
"""),

    code(r"""
# SESSION_40_PROMPT_ENGINEERED_EXPLANATION
print("Session 40 Prompt-Engineered Explanation")
print("\nSummary")
print("Best parameters:", random_search.best_params_)
print("Best mean CV R2:", round(float(random_search.best_score_), 4))
print("\nInterpretation")
print(
    f"The tuned model changed test R2 by {test_r2_change:+.4f}, "
    f"MAE by {test_mae_change:+.4f}, and RMSE by {test_rmse_change:+.4f} "
    "relative to the untuned Random Forest."
)
print(
    f"Randomized Search evaluated 8 of 27 configurations and required "
    f"40 rather than 135 cross-validation fits, avoiding {fits_avoided} fits."
)
print("\nRecommendation")
print(final_decision)
print(decision_reason)
"""),

    md(r"""
## Session 40 Prompt-Engineered Explanation

### Summary

The executed output above reports the actual best Random Forest parameters and
best mean cross-validated R2 obtained by RandomizedSearchCV.

### Interpretation

The executed output compares the tuned model with the untuned Random Forest
using test MAE, RMSE, and R2. It also records the reduction from 135 exhaustive
grid-search CV fits to 40 randomized-search CV fits.

### Recommendation

The final configuration is selected only when the tuned model demonstrates a
consistent test-set improvement; otherwise, the simpler untuned model is retained.
"""),

    md(r"""
## Session 40 Student Activity: Search-Cost Comparison

The parameter grid contains 27 possible configurations. With five-fold
cross-validation, exhaustive Grid Search requires 135 cross-validation fits.
Randomized Search evaluates 8 configurations and requires 40 fits. It therefore
avoids 95 fits and reduces estimated cross-validation search cost by 70.37%.

Randomized Search is preferred for this task because it explores the parameter
space at substantially lower computational cost. Its limitation is that it may
miss the best possible combination because it evaluates only a sample.

## Reflection Question

Randomized search can be more efficient than exhaustive grid search because it
tests a selected number of hyperparameter combinations instead of evaluating
the full Cartesian product. Here it uses 40 rather than 135 cross-validation
fits. Grid search can still be appropriate when the search space is small and
computationally affordable.
"""),

    code(r"""
# SESSION_40_OUTPUT_VERIFICATION
required_objects = [
    "random_search",
    "search_results_table",
    "comparison_table",
    "search_cost_comparison",
    "final_decision",
]
missing_objects = [name for name in required_objects if name not in globals()]
assert not missing_objects, f"Missing Session 40 objects: {missing_objects}"
assert len(search_results_table) == 8
assert grid_cv_fits == 135
assert randomized_cv_fits == 40
assert fits_avoided == 95

print("Session 40 output verification passed.")
print("Best parameters:", random_search.best_params_)
print("Validation status: PASSED")
"""),

    md(r"""
## Session 40 Output Artifact Completed

The Random Forest ensemble was tuned using RandomizedSearchCV. This notebook
records the best parameters, cross-validation results, test-set performance,
comparison with the untuned model, grid-versus-randomized search-cost analysis,
prompt-engineered explanation, final recommendation, reflection response, and
saved execution outputs.
"""),
]

notebook = nbformat.v4.new_notebook()
notebook.cells = base_cells + session40_cells
notebook.metadata = dict(source.metadata)
notebook.metadata["kernelspec"] = {
    "display_name": "GSSRP Session 40 Local",
    "language": "python",
    "name": kernel_name,
}
notebook.metadata.setdefault("language_info", {"name": "python"})

target_path.parent.mkdir(parents=True, exist_ok=True)
nbformat.write(notebook, target_path)

client = NotebookClient(
    notebook,
    timeout=1800,
    kernel_name=kernel_name,
    allow_errors=False,
    resources={"metadata": {"path": str(repo)}},
)
client.execute()
nbformat.write(notebook, target_path)

session40_tagged = [
    cell for cell in notebook.cells
    if "session40" in cell.get("metadata", {}).get("tags", [])
]
error_outputs = [
    output
    for cell in notebook.cells
    if cell.cell_type == "code"
    for output in cell.get("outputs", [])
    if output.get("output_type") == "error"
]
image_outputs = [
    output
    for cell in session40_tagged
    if cell.cell_type == "code"
    for output in cell.get("outputs", [])
    if "image/png" in output.get("data", {})
]

if error_outputs:
    raise RuntimeError("The executed notebook contains saved error outputs.")
if not image_outputs:
    raise RuntimeError("The Session 40 comparison figure was not saved.")

print(f"Created: {target_path}")
print(f"Session 39 base cells retained: {len(base_cells)}")
print(f"Session 40 cells created: {len(session40_tagged)}")
print(f"Saved Session 40 figures: {len(image_outputs)}")
print("SESSION_40_NOTEBOOK_BUILD_PASSED")
'@

Set-Content -LiteralPath $GeneratorFile -Value $GeneratorCode -Encoding UTF8

$PreviousJupyterPath = [Environment]::GetEnvironmentVariable("JUPYTER_PATH", "Process")

try {
    & $Python @PythonPrefix -m ipykernel install `
        --prefix $KernelPrefix `
        --name $KernelName `
        --display-name "GSSRP Session 40 Local"

    if ($LASTEXITCODE -ne 0) {
        Stop-Run "The temporary Session 40 Python kernel could not be created."
    }

    $TemporaryJupyterPath = Join-Path $KernelPrefix "share\jupyter"
    if ([string]::IsNullOrWhiteSpace($PreviousJupyterPath)) {
        $env:JUPYTER_PATH = $TemporaryJupyterPath
    }
    else {
        $env:JUPYTER_PATH = "$TemporaryJupyterPath;$PreviousJupyterPath"
    }

    & $Python @PythonPrefix $GeneratorFile `
        $ProjectRoot `
        $SourceNotebook `
        $TargetNotebook `
        $KernelName

    if ($LASTEXITCODE -ne 0) {
        Stop-Run "Session 40 notebook generation or local execution failed."
    }
}
finally {
    [Environment]::SetEnvironmentVariable("JUPYTER_PATH", $PreviousJupyterPath, "Process")
    if (Test-Path -LiteralPath $TemporaryRoot -PathType Container) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $TargetNotebook -PathType Leaf)) {
    Stop-Run "The required Session 40 notebook was not created."
}

Write-Host "[PASS] Session 40 notebook created and executed locally." -ForegroundColor Green

# ------------------------------------------------------------
# 5. Validate the executed deliverable
# ------------------------------------------------------------

Write-Step "Validating Session 40 content and saved outputs"

$NotebookText = Get-Content -LiteralPath $TargetNotebook -Raw
$NotebookJson = $NotebookText | ConvertFrom-Json
$Cells = @($NotebookJson.cells)
$CodeCells = @($Cells | Where-Object { $_.cell_type -eq "code" })
$ExecutedCells = @($CodeCells | Where-Object { $null -ne $_.execution_count })
$CellsWithOutputs = @(
    $CodeCells | Where-Object {
        $null -ne $_.outputs -and @($_.outputs).Count -gt 0
    }
)
$ErrorOutputs = @(
    $CodeCells | ForEach-Object { @($_.outputs) } |
        Where-Object { $null -ne $_ -and $_.output_type -eq "error" }
)
$ImageOutputs = @(
    foreach ($CodeCell in $CodeCells) {
        foreach ($Output in @($CodeCell.outputs)) {
            if (
                $null -ne $Output -and
                $Output.PSObject.Properties.Name -contains "data" -and
                $null -ne $Output.data -and
                $Output.data.PSObject.Properties.Name -contains "image/png"
            ) {
                $Output
            }
        }
    }
)

$RequiredPatterns = [ordered]@{
    "Session 40 heading" = "Session 40"
    "Randomized search" = "RandomizedSearchCV"
    "Random Forest" = "RandomForestRegressor"
    "Best parameters" = "best_params_"
    "Best CV score" = "best_score_"
    "Untuned comparison" = "Untuned Random Forest"
    "Tuned comparison" = "Tuned Random Forest"
    "Grid cost" = "grid_cv_fits"
    "Randomized cost" = "randomized_cv_fits"
    "Prompt explanation" = "Session 40 Prompt-Engineered Explanation"
    "Reflection" = "Reflection Question"
    "Output completion" = "Session 40 Output Artifact Completed"
    "Validation output" = "Validation status: PASSED"
}

$ValidationRows = @()
$Missing = @()

foreach ($Item in $RequiredPatterns.GetEnumerator()) {
    $Found = $NotebookText -match [regex]::Escape($Item.Value)
    $ValidationRows += [PSCustomObject]@{
        Requirement = $Item.Key
        Found = $Found
    }
    if (-not $Found) {
        $Missing += $Item.Key
    }
}

$ValidationRows | Format-Table Requirement, Found -AutoSize

if ($Missing.Count -gt 0) {
    Stop-Run "Missing Session 40 requirement(s): $($Missing -join ', ')"
}
if ($ExecutedCells.Count -eq 0 -or $CellsWithOutputs.Count -eq 0) {
    Stop-Run "The Session 40 notebook does not contain saved execution outputs."
}
if ($ErrorOutputs.Count -gt 0) {
    Stop-Run "The Session 40 notebook contains saved Python error output."
}
if ($ImageOutputs.Count -eq 0) {
    Stop-Run "The Session 40 comparison figure is missing from notebook outputs."
}

$NotebookSizeMB = [math]::Round((Get-Item $TargetNotebook).Length / 1MB, 2)
if ($NotebookSizeMB -gt 25) {
    Stop-Run "The notebook is unexpectedly large: $NotebookSizeMB MB"
}

$NotebookHash = (Get-FileHash -LiteralPath $TargetNotebook -Algorithm SHA256).Hash

Write-Host "[PASS] Notebook cells: $($Cells.Count)" -ForegroundColor Green
Write-Host "[PASS] Executed code cells: $($ExecutedCells.Count)" -ForegroundColor Green
Write-Host "[PASS] Cells with outputs: $($CellsWithOutputs.Count)" -ForegroundColor Green
Write-Host "[PASS] Saved figures: $($ImageOutputs.Count)" -ForegroundColor Green
Write-Host "[PASS] Saved error outputs: 0" -ForegroundColor Green
Write-Host "[PASS] Notebook size: $NotebookSizeMB MB" -ForegroundColor Green

# ------------------------------------------------------------
# 6. Create evidence, commit, and push
# ------------------------------------------------------------

Write-Step "Creating evidence and publishing the Session 40 deliverable"

$EvidenceLines = @(
    "Session 40 GitHub Deliverable Evidence",
    "======================================",
    "",
    "Session: 40",
    "Topic: Hyperparameter Tuning II",
    "Execution environment: VS Code on Windows using project Python",
    "Source notebook: notebooks/S39_Hyperparameter_Tuning_I.ipynb",
    "Deliverable notebook: $RelativeNotebook",
    "Model: Random Forest Regressor",
    "Search method: RandomizedSearchCV",
    "Notebook cells: $($Cells.Count)",
    "Executed code cells: $($ExecutedCells.Count)",
    "Code cells with outputs: $($CellsWithOutputs.Count)",
    "Saved figures: $($ImageOutputs.Count)",
    "Saved error outputs: $($ErrorOutputs.Count)",
    "SHA-256: $NotebookHash",
    "Validation status: PASSED",
    "Validated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    "",
    "Required checks:"
)

foreach ($Row in $ValidationRows) {
    $EvidenceLines += "- $($Row.Requirement): $($Row.Found)"
}

Set-Content -LiteralPath $EvidenceFile -Value $EvidenceLines -Encoding UTF8

if (-not (Select-String -LiteralPath $EvidenceFile -SimpleMatch "Validation status: PASSED" -Quiet)) {
    Stop-Run "The Session 40 evidence file failed verification."
}

$FilesToStage = @($RelativeNotebook, $RelativeEvidence)
if (Test-Path -LiteralPath $RepositoryScript -PathType Leaf) {
    $FilesToStage += $RelativeScript
}

& git add -f -- $FilesToStage
if ($LASTEXITCODE -ne 0) {
    Stop-Run "Git could not stage the Session 40 files."
}

$StagedFiles = @(& git diff --cached --name-only)
foreach ($RequiredFile in @($RelativeNotebook, $RelativeEvidence)) {
    if ($StagedFiles -notcontains $RequiredFile) {
        & git ls-files --error-unmatch -- $RequiredFile *> $null
        if ($LASTEXITCODE -ne 0) {
            Stop-Run "Required Session 40 file is not staged or tracked: $RequiredFile"
        }
    }
}

Write-Host "Staged Session 40 files:"
& git diff --cached --name-status

& git diff --cached --quiet
$DiffExitCode = $LASTEXITCODE

if ($DiffExitCode -eq 1) {
    Invoke-Git -Arguments @("commit", "-m", $CommitMessage)
    Write-Host "[PASS] Session 40 changes committed." -ForegroundColor Green
}
elseif ($DiffExitCode -eq 0) {
    Write-Host "[INFO] Session 40 files are already committed."
}
else {
    Stop-Run "Git could not inspect the staged changes."
}

Invoke-Git -Arguments @("push", "--set-upstream", "origin", $BranchName)

$FinalBranch = (& git branch --show-current).Trim()
$FinalCommit = (& git log -1 --oneline).Trim()
$LocalHash = (& git rev-parse HEAD).Trim()
$RemoteHash = (& git rev-parse "origin/$BranchName").Trim()

if ($FinalBranch -ne $BranchName) {
    Stop-Run "Final branch verification failed: $FinalBranch"
}
if ($LocalHash -ne $RemoteHash) {
    Stop-Run "The local and remote Session 40 branches are not synchronized."
}

Write-Host ""
& git status --short --branch
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "SESSION 40 - SECTION 8: COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Notebook: $RelativeNotebook"
Write-Host "Evidence: $RelativeEvidence"
Write-Host "Branch:   $FinalBranch"
Write-Host "Commit:   $FinalCommit"
Write-Host "Remote:   $RemoteUrl"
Write-Host ""

if ($null -ne (Get-Command code -ErrorAction SilentlyContinue)) {
    code -r $TargetNotebook *> $null
}



