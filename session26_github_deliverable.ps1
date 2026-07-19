param(
    [switch]$SkipExecution,
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"

function Step([string]$Text) {
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Run([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $Program $($Arguments -join ' ')"
    }
}

Write-Host "SESSION 26 GITHUB DELIVERABLE" -ForegroundColor Green

Step "Validate repository"
if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}
Set-Location -LiteralPath $ProjectRoot
Run "git" @("rev-parse", "--is-inside-work-tree")

$Staged = @(git diff --cached --name-only | Where-Object { $_ })
if ($Staged.Count -gt 0) {
    Write-Host "Already-staged files:" -ForegroundColor Yellow
    $Staged | ForEach-Object { Write-Host "  $_" }
    throw "Run 'git restore --staged .' and then rerun this automation. No files were deleted."
}

Step "Locate notebook"
$Matches = @(
    Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Filter "04_regression_models.ipynb" |
        Where-Object { $_.FullName -notmatch '[\\/]\.venv[\\/]' }
)
if ($Matches.Count -ne 1) {
    throw "Expected one 04_regression_models.ipynb; found $($Matches.Count)."
}
$Notebook = $Matches[0]
$NotebookRelative = $Notebook.FullName.Substring($ProjectRoot.TrimEnd("\").Length).TrimStart("\").Replace("\", "/")
Write-Host "Notebook: $NotebookRelative"

Step "Prepare Python environment"
$Venv = Join-Path $ProjectRoot ".venv"
$Python = Join-Path $Venv "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $Python)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        Run "py" @("-3", "-m", "venv", $Venv)
    } else {
        Run "python" @("-m", "venv", $Venv)
    }
}

$CheckPackages = @'
import importlib.util
names = ["nbformat", "nbconvert", "ipykernel", "pandas", "sklearn"]
raise SystemExit(0 if all(importlib.util.find_spec(x) for x in names) else 1)
'@
$CheckPackages | & $Python -
if ($LASTEXITCODE -ne 0) {
    Run $Python @("-m", "pip", "install", "--upgrade", "pip")
    Run $Python @(
        "-m", "pip", "install", "pandas", "numpy", "scikit-learn",
        "matplotlib", "seaborn", "jupyter", "nbformat", "nbconvert", "ipykernel"
    )
}

$Kernel = "student-performance-ml"
Run $Python @(
    "-m", "ipykernel", "install", "--user", "--name", $Kernel,
    "--display-name", "Student Performance ML"
)

Step "Back up and update notebook"
$Backup = Join-Path $env:TEMP ("04_regression_models_S26_{0}.ipynb" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Copy-Item -LiteralPath $Notebook.FullName -Destination $Backup -Force
Write-Host "Backup: $Backup"

$UpdateNotebook = @'
import sys
from pathlib import Path
import nbformat
from nbformat.v4 import new_code_cell, new_markdown_cell

path = Path(sys.argv[1])
nb = nbformat.read(path, as_version=4)
tag = "session26-automation"
nb.cells = [c for c in nb.cells if tag not in c.get("metadata", {}).get("tags", [])]
meta = {"tags": [tag]}

cells = [
    new_markdown_cell(
        "## Session 26 - KNN and SVR Regression\n\n"
        "KNN and SVR are fitted with StandardScaler inside their pipelines.",
        metadata=meta,
    ),
    new_code_cell('''# Session 26 imports
import pandas as pd
from sklearn.neighbors import KNeighborsRegressor
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVR''', metadata=meta),
    new_code_cell('''# Validate prerequisites
session26_required = ["Xtr_f", "Xte_f", "ytr", "yte", "eval_reg"]
session26_missing = [name for name in session26_required if name not in globals()]
if session26_missing:
    raise RuntimeError("Missing Session 26 prerequisites: " + ", ".join(session26_missing))
print("Session 26 prerequisites passed.")''', metadata=meta),
    new_code_cell('''# Fit and evaluate scaled models
session26_estimators = {
    "KNN": KNeighborsRegressor(),
    "SVR": SVR(),
}
session26_models = {}
session26_records = []

for model_name, estimator in session26_estimators.items():
    pipeline = make_pipeline(StandardScaler(), estimator)
    pipeline.fit(Xtr_f, ytr)
    predictions = pipeline.predict(Xte_f)
    metrics = eval_reg(yte, predictions)
    if not isinstance(metrics, dict):
        raise TypeError("eval_reg must return a dictionary.")
    normalized = {
        str(key).strip().upper().replace("R^2", "R2").replace("RÂ²", "R2"): value
        for key, value in metrics.items()
    }
    missing = [key for key in ["MAE", "RMSE", "R2"] if key not in normalized]
    if missing:
        raise KeyError("eval_reg is missing metrics: " + ", ".join(missing))
    session26_models[model_name] = pipeline
    session26_records.append({
        "Model": model_name,
        "MAE": float(normalized["MAE"]),
        "RMSE": float(normalized["RMSE"]),
        "R2": float(normalized["R2"]),
    })

session26_results_df = pd.DataFrame(session26_records)
display(session26_results_df.style.format({
    "MAE": "{:.4f}", "RMSE": "{:.4f}", "R2": "{:.4f}"
}))''', metadata=meta),
    new_code_cell('''# Update comparison table without duplicates
if "comparison_df" not in globals():
    comparison_df = pd.DataFrame(columns=["Model", "MAE", "RMSE", "R2"])
if "Model" not in comparison_df.columns:
    raise KeyError("comparison_df has no Model column.")
comparison_df = comparison_df[
    ~comparison_df["Model"].astype(str).isin(["KNN", "SVR"])
].copy()
comparison_df = pd.concat([comparison_df, session26_results_df], ignore_index=True)
comparison_df = comparison_df.sort_values("RMSE", na_position="last").reset_index(drop=True)
display(comparison_df.style.format({
    "MAE": "{:.4f}", "RMSE": "{:.4f}", "R2": "{:.4f}"
}))''', metadata=meta),
    new_code_cell('''# Final verification
assert isinstance(session26_models["KNN"].steps[0][1], StandardScaler)
assert isinstance(session26_models["SVR"].steps[0][1], StandardScaler)
assert comparison_df["Model"].astype(str).eq("KNN").sum() == 1
assert comparison_df["Model"].astype(str).eq("SVR").sum() == 1
assert {"Model", "MAE", "RMSE", "R2"}.issubset(comparison_df.columns)
print("SESSION 26 NOTEBOOK VERIFICATION PASSED")
print("Added models: KNN and SVR")
print("Scaling: StandardScaler is inside both pipelines")
print("KNN and SVR rows are present exactly once in comparison_df")''', metadata=meta),
]

nb.cells.extend(cells)
nb.setdefault("metadata", {})
nb["metadata"]["kernelspec"] = {
    "display_name": "Student Performance ML",
    "language": "python",
    "name": "student-performance-ml",
}
nbformat.write(nb, path)

check = nbformat.read(path, as_version=4)
tagged = [c for c in check.cells if tag in c.get("metadata", {}).get("tags", [])]
if len(tagged) != 6:
    raise RuntimeError(f"Expected 6 Session 26 cells; found {len(tagged)}")
source = "\n".join(c.get("source", "") for c in tagged)
required = ["KNeighborsRegressor", "SVR", "StandardScaler", "make_pipeline",
            "Xtr_f", "Xte_f", "eval_reg", "comparison_df"]
missing = [item for item in required if item not in source]
if missing:
    raise RuntimeError("Structural verification missing: " + ", ".join(missing))
print("Notebook structure verification passed.")
'@

$UpdateNotebook | & $Python - $Notebook.FullName
if ($LASTEXITCODE -ne 0) {
    throw "Notebook update failed. Backup: $Backup"
}

if (-not $SkipExecution) {
    Step "Execute notebook locally"
    Push-Location -LiteralPath $Notebook.DirectoryName
    try {
        Run $Python @(
            "-m", "jupyter", "nbconvert", "--to", "notebook", "--execute", "--inplace",
            "--ExecutePreprocessor.timeout=1200",
            "--ExecutePreprocessor.kernel_name=$Kernel",
            $Notebook.Name
        )
    } catch {
        Write-Host "Execution failed. Original backup: $Backup" -ForegroundColor Red
        throw
    } finally {
        Pop-Location
    }
}

Step "Verify notebook outputs"
$VerifyNotebook = @'
import sys
import nbformat
nb = nbformat.read(sys.argv[1], as_version=4)
tag = "session26-automation"
cells = [c for c in nb.cells if tag in c.get("metadata", {}).get("tags", [])]
if len(cells) != 6:
    raise SystemExit(f"Expected 6 Session 26 cells; found {len(cells)}")
if sys.argv[2] == "execute":
    code = [c for c in cells if c.cell_type == "code"]
    if any(c.get("execution_count") is None for c in code):
        raise SystemExit("At least one Session 26 cell was not executed.")
    streams = "\n".join(
        o.get("text", "") for c in code for o in c.get("outputs", [])
        if o.get("output_type") == "stream"
    )
    if "SESSION 26 NOTEBOOK VERIFICATION PASSED" not in streams:
        raise SystemExit("Final verification output was not found.")
print("Final notebook verification passed.")
'@
$Mode = if ($SkipExecution) { "skip" } else { "execute" }
$VerifyNotebook | & $Python - $Notebook.FullName $Mode
if ($LASTEXITCODE -ne 0) {
    throw "Final verification failed. Backup: $Backup"
}

Step "Commit Session 26"
Set-Location -LiteralPath $ProjectRoot
git add -- $NotebookRelative
$Changed = @(git diff --cached --name-only -- $NotebookRelative | Where-Object { $_ })
if ($Changed.Count -gt 0) {
    Run "git" @("commit", "-m", "Add KNN and SVR regression models", "--", $NotebookRelative)
} else {
    Write-Host "Notebook is already current."
}

if (-not $SkipPush) {
    Step "Push to GitHub"
    & git push
    if ($LASTEXITCODE -ne 0) {
        $Branch = (git branch --show-current).Trim()
        Run "git" @("push", "-u", "origin", $Branch)
    }
}

Step "Final status"
git status -sb
git log -1 --oneline
Write-Host ""
Write-Host "SESSION 26 GITHUB DELIVERABLE COMPLETED" -ForegroundColor Green
Write-Host "Notebook updated: $NotebookRelative"
Write-Host "Added models: KNN and SVR"
Write-Host "Scaling: StandardScaler is inside both pipelines"
Write-Host "Evaluation: eval_reg"
Write-Host "GitHub push: $(-not $SkipPush)"

