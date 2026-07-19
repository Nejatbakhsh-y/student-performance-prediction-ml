[CmdletBinding()]
param(
    [string]$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml",
    [switch]$SkipExecution,
    [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step([string]$Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments)][string[]]$ArgumentList
    )
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($ArgumentList -join ' ')"
    }
}

$NotebookRelative = "notebooks/04_regression_models.ipynb"
$CommitMessage = "Add MLP regression result"
$BackupPath = $null
$NotebookChanged = $false
$CommitCreated = $false

try {
    Write-Step "Checking project and Git repository"
    if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw "Project folder not found: $ProjectRoot"
    }
    Set-Location -LiteralPath $ProjectRoot

    Invoke-Checked git rev-parse --is-inside-work-tree
    $RepoRoot = (git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) {
        throw "Could not determine the Git repository root."
    }
    Set-Location -LiteralPath $RepoRoot

    $NotebookPath = Join-Path $RepoRoot ($NotebookRelative -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $NotebookPath -PathType Leaf)) {
        throw "Required notebook not found: $NotebookPath"
    }

    $Branch = (git branch --show-current).Trim()
    if (-not $Branch) {
        throw "Git is in detached-HEAD state. Check out your working branch and rerun the script."
    }
    if (git diff --name-only --diff-filter=U) {
        throw "Unresolved Git conflicts exist. Resolve them before running Session 30."
    }

    Write-Step "Preparing the local Python environment"
    $PythonPath = Join-Path $RepoRoot ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
        $Launcher = Get-Command py -ErrorAction SilentlyContinue
        if ($Launcher) {
            Invoke-Checked $Launcher.Source -3 -m venv .venv
        }
        else {
            $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
            if (-not $PythonCommand) {
                throw "Python was not found. Install Python 3, then rerun this script."
            }
            Invoke-Checked $PythonCommand.Source -m venv .venv
        }
    }

    Invoke-Checked $PythonPath -m pip install --disable-pip-version-check --quiet --upgrade pip
    if (Test-Path -LiteralPath (Join-Path $RepoRoot "requirements.txt")) {
        Invoke-Checked $PythonPath -m pip install --disable-pip-version-check --quiet -r requirements.txt
    }
    Invoke-Checked $PythonPath -m pip install --disable-pip-version-check --quiet nbformat nbconvert ipykernel jupyter pandas numpy scikit-learn matplotlib seaborn

    Write-Step "Adding the Session 30 MLP section"
    $BackupPath = Join-Path ([IO.Path]::GetTempPath()) ("session30_" + [guid]::NewGuid().ToString("N") + ".ipynb")
    Copy-Item -LiteralPath $NotebookPath -Destination $BackupPath -Force

    $UpdaterPath = Join-Path ([IO.Path]::GetTempPath()) ("session30_update_" + [guid]::NewGuid().ToString("N") + ".py")
    $UpdaterCode = @'
import sys
from pathlib import Path
import nbformat

path = Path(sys.argv[1])
nb = nbformat.read(path, as_version=4)

marker = "SESSION30_AUTOMATION"
heading = "Session 30 â€” Neural-Network Regression"
nb.cells = [
    cell for cell in nb.cells
    if marker not in cell.get("source", "")
    and heading not in cell.get("source", "")
    and "session30" not in cell.get("metadata", {}).get("tags", [])
]

markdown = nbformat.v4.new_markdown_cell(
    """## Session 30 â€” Neural-Network Regression

The MLP Regressor is trained on the same full-information split used by the other regression models. A `StandardScaler` is included inside the pipeline because neural networks are sensitive to feature scale. Test MAE, RMSE, and RÂ² are added as exactly one row in the regression comparison table, which is ranked by RMSE.
"""
)
markdown.metadata["tags"] = ["session30"]

code = nbformat.v4.new_code_cell(r'''# SESSION30_AUTOMATION
import warnings
import numpy as np
import pandas as pd
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.neural_network import MLPRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

required_session30_objects = ["Xtr_f", "Xte_f", "ytr", "yte"]
missing_session30_objects = [
    name for name in required_session30_objects if name not in globals()
]
assert not missing_session30_objects, (
    "Session 30 prerequisites are missing: "
    + ", ".join(missing_session30_objects)
    + ". Run the earlier regression-notebook cells first."
)

ytr_array = np.asarray(ytr).reshape(-1)
yte_array = np.asarray(yte).reshape(-1)

if "eval_reg" not in globals():
    def eval_reg(y_true, y_pred):
        return {
            "MAE": float(mean_absolute_error(y_true, y_pred)),
            "RMSE": float(np.sqrt(mean_squared_error(y_true, y_pred))),
            "R2": float(r2_score(y_true, y_pred)),
        }

mlp = make_pipeline(
    StandardScaler(),
    MLPRegressor(
        hidden_layer_sizes=(64, 32),
        max_iter=1000,
        random_state=42,
    ),
)

with warnings.catch_warnings(record=True) as session30_warnings:
    warnings.simplefilter("always")
    mlp.fit(Xtr_f, ytr_array)

mlp_test_predictions = mlp.predict(Xte_f)
mlp_test_metrics = eval_reg(yte_array, mlp_test_predictions)

# Normalize common metric-key variants if an earlier helper used different capitalization.
metric_lookup = {str(k).strip().upper(): v for k, v in mlp_test_metrics.items()}
mlp_test_metrics = {
    "MAE": float(metric_lookup["MAE"]),
    "RMSE": float(metric_lookup["RMSE"]),
    "R2": float(metric_lookup.get("R2", metric_lookup.get("RÂ²"))),
}

mlp_result_row = pd.DataFrame([{
    "Model": "MLP Regressor",
    "Scenario": "Full Information",
    "Scaling": "StandardScaler",
    "MAE": mlp_test_metrics["MAE"],
    "RMSE": mlp_test_metrics["RMSE"],
    "R2": mlp_test_metrics["R2"],
}])

if "comparison_table" in globals() and isinstance(comparison_table, pd.DataFrame):
    comparison_table = comparison_table.copy()
else:
    comparison_candidates = [
        "comparison_df", "model_comparison_df", "regression_comparison_df",
        "regression_leaderboard", "results_df",
    ]
    existing_table_name = next(
        (name for name in comparison_candidates
         if name in globals() and isinstance(globals()[name], pd.DataFrame)),
        None,
    )
    comparison_table = (
        globals()[existing_table_name].copy()
        if existing_table_name is not None
        else pd.DataFrame()
    )

required_columns = ["Model", "Scenario", "Scaling", "MAE", "RMSE", "R2"]
for column in required_columns:
    if column not in comparison_table.columns:
        comparison_table[column] = pd.NA
comparison_table = comparison_table[required_columns]

comparison_table = comparison_table[
    comparison_table["Model"].astype(str).str.strip().str.lower()
    != "mlp regressor"
].copy()
comparison_table = pd.concat([comparison_table, mlp_result_row], ignore_index=True)

for column in ["MAE", "RMSE", "R2"]:
    comparison_table[column] = pd.to_numeric(comparison_table[column], errors="coerce")

comparison_table = (
    comparison_table.sort_values("RMSE", ascending=True, na_position="last")
    .reset_index(drop=True)
)
comparison_table.index = comparison_table.index + 1
comparison_table.index.name = "Rank"

mlp_mask = comparison_table["Model"].eq("MLP Regressor")
assert int(mlp_mask.sum()) == 1, "Expected exactly one MLP Regressor row."
assert comparison_table.loc[mlp_mask, ["MAE", "RMSE", "R2"]].notna().all().all(), (
    "One or more MLP metrics are missing."
)

mlp_regressor = mlp.named_steps["mlpregressor"]
print("MLP test metrics:", {k: round(v, 4) for k, v in mlp_test_metrics.items()})
print("MLP iterations:", mlp_regressor.n_iter_)
print("Convergence warning count:", len(session30_warnings))
display(comparison_table.round(4))
print("SESSION 30 NOTEBOOK VERIFICATION PASSED")
''')
code.metadata["tags"] = ["session30"]

nb.cells.extend([markdown, code])
nbformat.write(nb, path)
print(f"Updated {path}")
'@
    Set-Content -LiteralPath $UpdaterPath -Value $UpdaterCode -Encoding UTF8
    try {
        Invoke-Checked $PythonPath $UpdaterPath $NotebookPath
    }
    finally {
        Remove-Item -LiteralPath $UpdaterPath -Force -ErrorAction SilentlyContinue
    }
    $NotebookChanged = $true

    if (-not $SkipExecution) {
        Write-Step "Executing and verifying the notebook"
        Invoke-Checked $PythonPath -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=1800 --ExecutePreprocessor.kernel_name=python3 $NotebookPath

        $VerificationCode = "import nbformat,sys; n=nbformat.read(sys.argv[1],as_version=4); s=''.join(str(o.get('text','')) for c in n.cells for o in c.get('outputs',[])); assert 'SESSION 30 NOTEBOOK VERIFICATION PASSED' in s; print('Notebook output verification passed.')"
        Invoke-Checked $PythonPath -c $VerificationCode $NotebookPath
    }
    else {
        Write-Host "Notebook execution skipped by request." -ForegroundColor Yellow
    }

    Write-Step "Committing only the regression notebook"
    git diff --quiet HEAD -- $NotebookRelative
    $HasNotebookChanges = ($LASTEXITCODE -ne 0)

    if ($HasNotebookChanges) {
        Invoke-Checked git commit --only -m $CommitMessage -- $NotebookRelative
        $CommitCreated = $true
    }
    else {
        Write-Host "The Session 30 notebook is already current; no new commit was required."
    }

    if (-not $SkipPush) {
        Write-Step "Pushing the current branch to GitHub"
        git rev-parse --abbrev-ref --symbolic-full-name "@{u}" *> $null
        if ($LASTEXITCODE -eq 0) {
            Invoke-Checked git push
        }
        else {
            Invoke-Checked git push --set-upstream origin $Branch
        }

        $LocalCommit = (git rev-parse HEAD).Trim()
        $RemoteCommit = (git rev-parse "@{u}").Trim()
        if ($LocalCommit -ne $RemoteCommit) {
            throw "Push verification failed: local and upstream commits do not match."
        }
    }
    else {
        Write-Host "GitHub push skipped by request." -ForegroundColor Yellow
    }

    Write-Step "SESSION 30 GITHUB DELIVERABLE COMPLETED"
    Write-Host "Notebook updated: notebooks\04_regression_models.ipynb"
    Write-Host "Model added: MLP Regressor"
    Write-Host "Pipeline: StandardScaler -> MLPRegressor(64, 32)"
    Write-Host "Artifact: one MLP row in the regression comparison table"
    Write-Host "Commit message: $CommitMessage"
    Write-Host "Latest commit: $(git log -1 --oneline)"
    Write-Host "Git status:"
    git status -sb
}
catch {
    if ($NotebookChanged -and -not $CommitCreated -and $BackupPath -and (Test-Path -LiteralPath $BackupPath)) {
        Copy-Item -LiteralPath $BackupPath -Destination $NotebookPath -Force
        Write-Host "The original notebook was restored because the automation did not complete." -ForegroundColor Yellow
    }
    Write-Host "`nSESSION 30 AUTOMATION STOPPED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
finally {
    if ($BackupPath -and (Test-Path -LiteralPath $BackupPath)) {
        Remove-Item -LiteralPath $BackupPath -Force -ErrorAction SilentlyContinue
    }
}

