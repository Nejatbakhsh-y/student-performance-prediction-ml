$ErrorActionPreference = "Stop"

# ============================================================
# Session 44 - Section 8 GitHub Deliverable
# Full-Information vs Early-Warning Comparison
# One-file Windows PowerShell automation for VS Code
# ============================================================

$ProjectRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
$AutomationName = "08_session44_github_deliverable.ps1"
$ReportRelativePath = "reports/session44"
$ReportDirectory = Join-Path $ProjectRoot "reports\session44"
$BranchName = "feature/session44-full-vs-early"
$CommitMessage = "Add Session 44 full-vs-early comparison"
$TemporaryPythonPath = Join-Path $env:TEMP "session44_generate_artifacts.py"

$ExpectedArtifacts = @(
    "README.md",
    "session44_leakage_aware_comparison_note.txt",
    "session44_full_vs_early_metrics.csv",
    "session44_full_vs_early_comparison.png",
    "session44_actual_vs_predicted_comparison.png"
)

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)

    Write-Host ""
    Write-Host $Title
    Write-Host ("=" * $Title.Length)
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

try {
    Write-Section "SESSION 44 SECTION 8 AUTOMATION"

    # --------------------------------------------------------
    # 1. Validate the fixed Windows project and script location
    # --------------------------------------------------------

    if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw "Project directory not found: $ProjectRoot"
    }

    Set-Location -LiteralPath $ProjectRoot

    $ExpectedAutomationPath = Join-Path $ProjectRoot $AutomationName
    if (-not (Test-Path -LiteralPath $ExpectedAutomationPath -PathType Leaf)) {
        throw "Save this automation as $ExpectedAutomationPath and run it again."
    }

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        throw "Run the saved $AutomationName file; do not paste its contents directly into the terminal."
    }

    $RunningAutomationPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
    $ResolvedExpectedAutomationPath = (
        Resolve-Path -LiteralPath $ExpectedAutomationPath
    ).Path

    if ($RunningAutomationPath -ne $ResolvedExpectedAutomationPath) {
        throw "Run the automation from the project root: $ExpectedAutomationPath"
    }

    Write-Host "Project: $ProjectRoot"

    # --------------------------------------------------------
    # 2. Validate Git and protect unrelated staged work
    # --------------------------------------------------------

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or is not available in PATH."
    }

    $RepositoryRoot = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        throw "The project directory is not a Git repository."
    }

    $ResolvedRepositoryRoot = (
        Resolve-Path -LiteralPath $RepositoryRoot
    ).Path.TrimEnd("\")
    $ResolvedProjectRoot = (
        Resolve-Path -LiteralPath $ProjectRoot
    ).Path.TrimEnd("\")

    if ($ResolvedRepositoryRoot -ne $ResolvedProjectRoot) {
        throw "The configured project directory is not the repository root. Git root: $ResolvedRepositoryRoot"
    }

    $RemoteUrl = (& git remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RemoteUrl)) {
        throw "The Git remote named origin is missing."
    }

    $InitiallyStaged = @(& git diff --cached --name-only)
    $UnrelatedStaged = @(
        $InitiallyStaged | Where-Object {
            $_ -and
            $_ -ne $AutomationName -and
            $_ -notlike "$ReportRelativePath/*"
        }
    )

    if ($UnrelatedStaged.Count -gt 0) {
        throw (
            "Unrelated files are already staged. Commit or unstage them before running Session 44: " +
            ($UnrelatedStaged -join ", ")
        )
    }

    Write-Host "Git repository and origin remote validated."

    # --------------------------------------------------------
    # 3. Fetch and create or reuse the Session 44 branch
    # --------------------------------------------------------

    Write-Section "PREPARING FEATURE BRANCH"

    Invoke-Git -Arguments @("fetch", "origin", "--prune") `
        -FailureMessage "Unable to fetch from the GitHub remote. Confirm your internet connection and GitHub authentication."

    $CurrentBranch = [string](& git branch --show-current)
    $CurrentBranch = $CurrentBranch.Trim()
    if ([string]::IsNullOrWhiteSpace($CurrentBranch)) {
        throw "The repository is in detached HEAD state. Switch to a normal branch and rerun the automation."
    }

    & git show-ref --verify --quiet "refs/heads/$BranchName"
    $LocalBranchExists = ($LASTEXITCODE -eq 0)

    & git show-ref --verify --quiet "refs/remotes/origin/$BranchName"
    $RemoteBranchExists = ($LASTEXITCODE -eq 0)

    if ($CurrentBranch -ne $BranchName) {
        if ($LocalBranchExists) {
            Invoke-Git -Arguments @("switch", $BranchName) `
                -FailureMessage "Unable to switch to $BranchName. Resolve conflicting local changes and rerun."
        }
        elseif ($RemoteBranchExists) {
            Invoke-Git -Arguments @(
                "switch", "--track", "-c", $BranchName, "origin/$BranchName"
            ) -FailureMessage "Unable to create a local branch from origin/$BranchName."
        }
        else {
            Invoke-Git -Arguments @("switch", "-c", $BranchName) `
                -FailureMessage "Unable to create $BranchName."
        }
    }

    Write-Host "Branch: $BranchName"

    # --------------------------------------------------------
    # 4. Locate the UCI student performance dataset locally
    # --------------------------------------------------------

    Write-Section "LOCATING DATASET"

    $DatasetPath = $null
    $PreferredDatasetPaths = @(
        (Join-Path $ProjectRoot "data\raw\student-mat.csv"),
        (Join-Path $ProjectRoot "data\student-mat.csv"),
        (Join-Path $ProjectRoot "student-mat.csv"),
        (Join-Path $env:USERPROFILE "Downloads\student-mat.csv")
    )

    foreach ($Candidate in $PreferredDatasetPaths) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            $DatasetPath = (Resolve-Path -LiteralPath $Candidate).Path
            break
        }
    }

    if (-not $DatasetPath) {
        $ProjectCandidates = @(
            Get-ChildItem `
                -LiteralPath $ProjectRoot `
                -Recurse `
                -File `
                -Filter "student-mat*.csv" `
                -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch "[\\/](\.git|\.venv|venv|reports)[\\/]"
            } |
            Sort-Object `
                @{ Expression = { if ($_.Name -eq "student-mat.csv") { 0 } else { 1 } } }, `
                FullName
        )

        if ($ProjectCandidates.Count -gt 0) {
            $DatasetPath = $ProjectCandidates[0].FullName
        }
    }

    if (-not $DatasetPath) {
        $DownloadCandidates = @(
            Get-ChildItem `
                -LiteralPath (Join-Path $env:USERPROFILE "Downloads") `
                -File `
                -Filter "student-mat*.csv" `
                -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
        )

        if ($DownloadCandidates.Count -gt 0) {
            $DatasetPath = $DownloadCandidates[0].FullName
        }
    }

    if (-not $DatasetPath) {
        throw (
            "student-mat.csv was not found. Place the UCI student-mat.csv file in " +
            "$ProjectRoot\data\raw and rerun the automation."
        )
    }

    if ((Get-Item -LiteralPath $DatasetPath).Length -eq 0) {
        throw "The dataset is empty: $DatasetPath"
    }

    Write-Host "Dataset: $DatasetPath"

    # --------------------------------------------------------
    # 5. Select Python and install only missing dependencies
    # --------------------------------------------------------

    Write-Section "PREPARING PYTHON"

    $PythonExecutable = $null
    $PythonPrefixArguments = @()
    $VirtualEnvironmentPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

    if (Test-Path -LiteralPath $VirtualEnvironmentPython -PathType Leaf) {
        $PythonExecutable = $VirtualEnvironmentPython
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $PythonExecutable = (Get-Command py).Source
        $PythonPrefixArguments = @("-3")
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $PythonExecutable = (Get-Command python).Source
    }
    else {
        throw "Python 3 was not found. Install Python 3 or create the project's .venv environment."
    }

    & $PythonExecutable @PythonPrefixArguments -c `
        "import numpy, pandas, matplotlib, sklearn" 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing required Python packages..."
        & $PythonExecutable @PythonPrefixArguments -m pip install `
            numpy pandas matplotlib scikit-learn

        if ($LASTEXITCODE -ne 0) {
            throw "Python dependency installation failed."
        }
    }

    & $PythonExecutable @PythonPrefixArguments --version
    if ($LASTEXITCODE -ne 0) {
        throw "The selected Python interpreter could not run."
    }

    # --------------------------------------------------------
    # 6. Generate all Session 44 results locally
    # --------------------------------------------------------

    Write-Section "GENERATING SESSION 44 ARTIFACTS"

    New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null

    $PythonCode = @'
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder


def load_student_data(path: Path) -> pd.DataFrame:
    attempts = []
    for separator in (";", ","):
        try:
            candidate = pd.read_csv(path, sep=separator)
            candidate.columns = [str(column).strip().lstrip("\ufeff") for column in candidate.columns]
            attempts.append(candidate)
            if {"G1", "G2", "G3"}.issubset(candidate.columns):
                return candidate
        except Exception:
            continue

    column_sets = [list(frame.columns) for frame in attempts]
    raise ValueError(
        "The selected CSV does not contain the required G1, G2, and G3 columns. "
        f"Observed columns: {column_sets}"
    )


def make_preprocessor(frame: pd.DataFrame) -> ColumnTransformer:
    numeric_columns = frame.select_dtypes(include=["number"]).columns.tolist()
    categorical_columns = frame.select_dtypes(exclude=["number"]).columns.tolist()

    transformers = []
    if numeric_columns:
        transformers.append(("numeric", "passthrough", numeric_columns))

    if categorical_columns:
        try:
            encoder = OneHotEncoder(handle_unknown="ignore", sparse_output=False)
        except TypeError:
            encoder = OneHotEncoder(handle_unknown="ignore", sparse=False)
        transformers.append(("categorical", encoder, categorical_columns))

    if not transformers:
        raise ValueError("No usable predictor columns were found.")

    return ColumnTransformer(transformers=transformers)


def regression_metrics(y_true: pd.Series, y_pred: np.ndarray) -> dict[str, float]:
    return {
        "MAE": float(mean_absolute_error(y_true, y_pred)),
        "RMSE": float(np.sqrt(mean_squared_error(y_true, y_pred))),
        "R2": float(r2_score(y_true, y_pred)),
    }


def add_bar_labels(axis: plt.Axes, bars) -> None:
    for bar in bars:
        value = float(bar.get_height())
        vertical_alignment = "bottom" if value >= 0 else "top"
        offset = 3 if value >= 0 else -3
        axis.annotate(
            f"{value:.3f}",
            xy=(bar.get_x() + bar.get_width() / 2, value),
            xytext=(0, offset),
            textcoords="offset points",
            ha="center",
            va=vertical_alignment,
            fontsize=9,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--output", required=True)
    arguments = parser.parse_args()

    dataset_path = Path(arguments.dataset).resolve()
    output_directory = Path(arguments.output).resolve()
    output_directory.mkdir(parents=True, exist_ok=True)

    data = load_student_data(dataset_path)
    if len(data) < 20:
        raise ValueError(f"The dataset has too few rows for evaluation: {len(data)}")

    required_columns = ["G1", "G2", "G3"]
    missing_columns = [column for column in required_columns if column not in data.columns]
    if missing_columns:
        raise ValueError(f"Required columns are missing: {missing_columns}")

    if data.isna().any().any():
        missing_count = int(data.isna().sum().sum())
        raise ValueError(f"The dataset contains {missing_count} missing values. Clean it before rerunning.")

    y = pd.to_numeric(data["G3"], errors="raise").copy()
    full_features = data.drop(columns=["G3"]).copy()
    early_features = data.drop(columns=["G1", "G2", "G3"]).copy()

    row_indices = np.arange(len(data))
    train_indices, test_indices = train_test_split(
        row_indices,
        test_size=0.20,
        random_state=42,
    )

    full_train_raw = full_features.iloc[train_indices].copy()
    full_test_raw = full_features.iloc[test_indices].copy()
    early_train_raw = early_features.iloc[train_indices].copy()
    early_test_raw = early_features.iloc[test_indices].copy()
    y_train = y.iloc[train_indices].copy()
    y_test = y.iloc[test_indices].copy()

    assert full_train_raw.index.equals(early_train_raw.index)
    assert full_test_raw.index.equals(early_test_raw.index)
    assert y_train.index.equals(full_train_raw.index)
    assert y_test.index.equals(full_test_raw.index)
    assert "G1" in full_features.columns and "G2" in full_features.columns
    assert "G1" not in early_features.columns and "G2" not in early_features.columns
    assert "G3" not in full_features.columns and "G3" not in early_features.columns

    full_preprocessor = make_preprocessor(full_train_raw)
    early_preprocessor = make_preprocessor(early_train_raw)

    full_train = full_preprocessor.fit_transform(full_train_raw)
    full_test = full_preprocessor.transform(full_test_raw)
    early_train = early_preprocessor.fit_transform(early_train_raw)
    early_test = early_preprocessor.transform(early_test_raw)

    full_model = RandomForestRegressor(
        n_estimators=300,
        random_state=42,
        n_jobs=-1,
    )
    early_model = RandomForestRegressor(
        n_estimators=300,
        random_state=42,
        n_jobs=-1,
    )

    full_model.fit(full_train, y_train)
    early_model.fit(early_train, y_train)

    full_predictions = full_model.predict(full_test)
    early_predictions = early_model.predict(early_test)

    full = regression_metrics(y_test, full_predictions)
    early = regression_metrics(y_test, early_predictions)

    mae_gap = early["MAE"] - full["MAE"]
    rmse_gap = early["RMSE"] - full["RMSE"]
    r2_change = early["R2"] - full["R2"]
    rmse_percent_increase = (
        (rmse_gap / full["RMSE"]) * 100.0 if full["RMSE"] != 0 else float("nan")
    )

    if full["RMSE"] < early["RMSE"]:
        accuracy_winner = "Full-information"
    elif early["RMSE"] < full["RMSE"]:
        accuracy_winner = "Early-warning"
    else:
        accuracy_winner = "Tie"

    metrics_table = pd.DataFrame(
        [
            {
                "Model": "Full-information",
                "Feature_Timing": "Includes G1 and G2",
                "Raw_Feature_Count": full_features.shape[1],
                "Encoded_Feature_Count": full_train.shape[1],
                "Training_Rows": len(train_indices),
                "Testing_Rows": len(test_indices),
                "MAE": full["MAE"],
                "RMSE": full["RMSE"],
                "R2": full["R2"],
            },
            {
                "Model": "Early-warning",
                "Feature_Timing": "Excludes G1 and G2",
                "Raw_Feature_Count": early_features.shape[1],
                "Encoded_Feature_Count": early_train.shape[1],
                "Training_Rows": len(train_indices),
                "Testing_Rows": len(test_indices),
                "MAE": early["MAE"],
                "RMSE": early["RMSE"],
                "R2": early["R2"],
            },
        ]
    )
    metrics_path = output_directory / "session44_full_vs_early_metrics.csv"
    metrics_table.to_csv(metrics_path, index=False, float_format="%.6f")

    colors = ["#1f77b4", "#ff7f0e"]
    model_labels = ["Full-information", "Early-warning"]
    metric_specs = [
        ("MAE", [full["MAE"], early["MAE"]], "Lower is better"),
        ("RMSE", [full["RMSE"], early["RMSE"]], "Lower is better"),
        ("R2", [full["R2"], early["R2"]], "Higher is better"),
    ]

    figure, axes = plt.subplots(1, 3, figsize=(14, 5.2))
    for axis, (metric_name, values, guidance) in zip(axes, metric_specs):
        bars = axis.bar(model_labels, values, color=colors, edgecolor="black", linewidth=0.7)
        axis.set_title(f"{metric_name}\n{guidance}", fontweight="bold")
        axis.set_ylabel("Metric value")
        axis.grid(axis="y", linestyle="--", alpha=0.3)
        axis.tick_params(axis="x", rotation=15)
        add_bar_labels(axis, bars)

        low = min(0.0, min(values))
        high = max(0.0, max(values))
        span = max(high - low, 0.1)
        axis.set_ylim(low - (0.12 * span if low < 0 else 0), high + 0.18 * span)

    figure.suptitle(
        "Session 44: Full-Information vs Early-Warning Random Forest",
        fontsize=15,
        fontweight="bold",
    )
    figure.text(
        0.5,
        0.01,
        "Same 80/20 student split, 300 trees, and random state 42; only feature timing differs.",
        ha="center",
        fontsize=10,
    )
    figure.tight_layout(rect=(0, 0.05, 1, 0.93))
    figure.savefig(
        output_directory / "session44_full_vs_early_comparison.png",
        dpi=300,
        bbox_inches="tight",
    )
    plt.close(figure)

    minimum_value = float(min(y_test.min(), full_predictions.min(), early_predictions.min()))
    maximum_value = float(max(y_test.max(), full_predictions.max(), early_predictions.max()))

    figure, axes = plt.subplots(1, 2, figsize=(13, 5.5), sharex=True, sharey=True)
    prediction_specs = [
        (axes[0], full_predictions, "Full-Information Model", colors[0], full["RMSE"]),
        (axes[1], early_predictions, "Early-Warning Model", colors[1], early["RMSE"]),
    ]
    for axis, predictions, title, color, rmse in prediction_specs:
        axis.scatter(
            y_test,
            predictions,
            alpha=0.78,
            color=color,
            edgecolor="black",
            linewidth=0.45,
        )
        axis.plot(
            [minimum_value, maximum_value],
            [minimum_value, maximum_value],
            linestyle="--",
            color="#b22222",
            linewidth=1.5,
        )
        axis.set_title(f"{title}\nRMSE = {rmse:.3f}", fontweight="bold")
        axis.set_xlabel("Actual G3")
        axis.grid(alpha=0.25)

    axes[0].set_ylabel("Predicted G3")
    figure.suptitle("Session 44: Actual vs Predicted Final Grades", fontsize=15, fontweight="bold")
    figure.tight_layout(rect=(0, 0, 1, 0.93))
    figure.savefig(
        output_directory / "session44_actual_vs_predicted_comparison.png",
        dpi=300,
        bbox_inches="tight",
    )
    plt.close(figure)

    if rmse_gap > 0:
        accuracy_statement = (
            f"The early-warning model's RMSE was {rmse_gap:.4f} grade points higher "
            f"than the full-information model, a {rmse_percent_increase:.2f}% increase."
        )
    elif rmse_gap < 0:
        accuracy_statement = (
            f"The early-warning model's RMSE was {abs(rmse_gap):.4f} grade points lower "
            "than the full-information model."
        )
    else:
        accuracy_statement = "The two models produced the same RMSE."

    note = f"""SESSION 44: LEAKAGE-AWARE FULL-VS-EARLY COMPARISON

PURPOSE
This analysis evaluates the same 300-tree Random Forest regressor on two feature sets using identical training and testing students. The target is G3. The full-information model includes G1 and G2, while the early-warning model excludes G1 and G2.

RESULTS
Dataset rows: {len(data)}
Training rows: {len(train_indices)}
Testing rows: {len(test_indices)}

Full-information model (includes G1 and G2):
MAE = {full['MAE']:.4f}
RMSE = {full['RMSE']:.4f}
R2 = {full['R2']:.4f}

Early-warning model (excludes G1 and G2):
MAE = {early['MAE']:.4f}
RMSE = {early['RMSE']:.4f}
R2 = {early['R2']:.4f}

More accurate model by RMSE: {accuracy_winner}

ACCURACY GAP
Early MAE minus Full MAE = {mae_gap:.4f}
Early RMSE minus Full RMSE = {rmse_gap:.4f}
Early R2 minus Full R2 = {r2_change:.4f}
Percentage increase in RMSE = {rmse_percent_increase:.2f}%

{accuracy_statement}

LEAKAGE-AWARE INTERPRETATION
G1 and G2 are closely related to G3 and can substantially improve predictive accuracy. However, if the intended intervention occurs before G1 and G2 are available, including them creates timing-related leakage. The full-information result therefore describes later prediction with more information, while the early-warning result is the valid estimate for a genuinely early intervention.

CONCLUSION
Accuracy alone does not determine whether a student-support model is appropriate. Even when the early-warning model is less accurate, it may be the more responsible operational choice because it uses information genuinely available when support can still be offered. Predictions should initiate supportive human review and should never be used for automatic labeling, surveillance, or punitive decisions.

REPRODUCIBILITY
Train-test split: 80/20 using identical row indices
Split random state: 42
Model: RandomForestRegressor
Trees per model: 300
Model random state: 42
Dataset: {dataset_path.name}
"""
    note_path = output_directory / "session44_leakage_aware_comparison_note.txt"
    note_path.write_text(note, encoding="utf-8")

    readme = f"""# Session 44: Full-Information vs Early-Warning Comparison

## Objective

This deliverable compares two 300-tree Random Forest regression models for predicting final grade `G3` on the same train-test split.

- Full-information model: includes `G1` and `G2`.
- Early-warning model: excludes `G1` and `G2`.
- Training students: {len(train_indices)}.
- Testing students: {len(test_indices)}.
- Random state: 42.

## Actual results

| Model | MAE | RMSE | R2 |
| --- | ---: | ---: | ---: |
| Full-information | {full['MAE']:.4f} | {full['RMSE']:.4f} | {full['R2']:.4f} |
| Early-warning | {early['MAE']:.4f} | {early['RMSE']:.4f} | {early['R2']:.4f} |

The more accurate model by RMSE is **{accuracy_winner}**. {accuracy_statement}

## Leakage-aware conclusion

`G1` and `G2` can improve accuracy, but they create timing-related leakage if they are unavailable at the intended intervention time. The early-warning result is therefore the appropriate estimate for a genuinely early support system, even when its accuracy is lower. Predictions are intended to support human review and student assistance, not automatic or punitive decisions.

## Artifacts

- `session44_leakage_aware_comparison_note.txt`: full interpretation and conclusion.
- `session44_full_vs_early_metrics.csv`: reproducible metric table.
- `session44_full_vs_early_comparison.png`: direct MAE, RMSE, and R2 comparison.
- `session44_actual_vs_predicted_comparison.png`: actual-versus-predicted plots.

The repository-root PowerShell file `08_session44_github_deliverable.ps1` reproduces the complete local analysis and GitHub delivery workflow.
"""
    (output_directory / "README.md").write_text(readme, encoding="utf-8")

    expected_files = [
        output_directory / "README.md",
        note_path,
        metrics_path,
        output_directory / "session44_full_vs_early_comparison.png",
        output_directory / "session44_actual_vs_predicted_comparison.png",
    ]
    for expected_file in expected_files:
        if not expected_file.is_file() or expected_file.stat().st_size == 0:
            raise RuntimeError(f"Required artifact was not created: {expected_file}")

    print("SESSION 44 LOCAL ANALYSIS COMPLETED")
    print(f"Full-information: MAE={full['MAE']:.4f}, RMSE={full['RMSE']:.4f}, R2={full['R2']:.4f}")
    print(f"Early-warning:    MAE={early['MAE']:.4f}, RMSE={early['RMSE']:.4f}, R2={early['R2']:.4f}")
    print(f"RMSE winner: {accuracy_winner}")
    print(f"Output directory: {output_directory}")


if __name__ == "__main__":
    main()
'@

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        $TemporaryPythonPath,
        $PythonCode,
        $Utf8NoBom
    )

    & $PythonExecutable @PythonPrefixArguments $TemporaryPythonPath `
        --dataset $DatasetPath `
        --output $ReportDirectory

    if ($LASTEXITCODE -ne 0) {
        throw "The Session 44 local analysis failed. Review the Python error shown above."
    }

    # --------------------------------------------------------
    # 7. Validate every required artifact and its contents
    # --------------------------------------------------------

    Write-Section "VALIDATING ARTIFACTS"

    foreach ($ArtifactName in $ExpectedArtifacts) {
        $ArtifactPath = Join-Path $ReportDirectory $ArtifactName

        if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) {
            throw "Required artifact is missing: $ArtifactPath"
        }

        if ((Get-Item -LiteralPath $ArtifactPath).Length -eq 0) {
            throw "Required artifact is empty: $ArtifactPath"
        }
    }

    $NotePath = Join-Path $ReportDirectory "session44_leakage_aware_comparison_note.txt"
    $NoteText = Get-Content -LiteralPath $NotePath -Raw -Encoding UTF8
    $RequiredNoteTerms = @(
        "PURPOSE",
        "RESULTS",
        "ACCURACY GAP",
        "LEAKAGE-AWARE INTERPRETATION",
        "CONCLUSION",
        "G1",
        "G2",
        "G3",
        "timing-related leakage"
    )

    foreach ($RequiredTerm in $RequiredNoteTerms) {
        if ($NoteText -notmatch [regex]::Escape($RequiredTerm)) {
            throw "The comparison note is incomplete. Missing term: $RequiredTerm"
        }
    }

    $MetricsPath = Join-Path $ReportDirectory "session44_full_vs_early_metrics.csv"
    $MetricsRows = @(Import-Csv -LiteralPath $MetricsPath)
    if ($MetricsRows.Count -ne 2) {
        throw "The metrics CSV must contain exactly two model rows."
    }

    if (
        $MetricsRows.Model -notcontains "Full-information" -or
        $MetricsRows.Model -notcontains "Early-warning"
    ) {
        throw "The metrics CSV does not contain both required models."
    }

    $ExpectedPngSignature = @(137, 80, 78, 71, 13, 10, 26, 10)
    $PngNames = @(
        "session44_full_vs_early_comparison.png",
        "session44_actual_vs_predicted_comparison.png"
    )

    foreach ($PngName in $PngNames) {
        $PngPath = Join-Path $ReportDirectory $PngName
        $PngBytes = [System.IO.File]::ReadAllBytes($PngPath)

        if ($PngBytes.Length -lt 8) {
            throw "PNG file is invalid: $PngPath"
        }

        for ($Index = 0; $Index -lt 8; $Index++) {
            if ($PngBytes[$Index] -ne $ExpectedPngSignature[$Index]) {
                throw "PNG signature validation failed: $PngPath"
            }
        }
    }

    Write-Host "All required Session 44 artifacts passed validation."

    # --------------------------------------------------------
    # 8. Stage only the Session 44 report and automation
    # --------------------------------------------------------

    Write-Section "COMMITTING SESSION 44"

    Invoke-Git -Arguments @(
        "add", "--", $AutomationName, $ReportRelativePath
    ) -FailureMessage "Unable to stage the Session 44 deliverables."

    $AllStaged = @(& git diff --cached --name-only)
    $UnexpectedStaged = @(
        $AllStaged | Where-Object {
            $_ -and
            $_ -ne $AutomationName -and
            $_ -notlike "$ReportRelativePath/*"
        }
    )

    if ($UnexpectedStaged.Count -gt 0) {
        throw (
            "Safety check stopped the commit because unrelated files are staged: " +
            ($UnexpectedStaged -join ", ")
        )
    }

    $RequiredStagedOrTracked = @(
        "$ReportRelativePath/README.md",
        "$ReportRelativePath/session44_leakage_aware_comparison_note.txt",
        "$ReportRelativePath/session44_full_vs_early_metrics.csv",
        "$ReportRelativePath/session44_full_vs_early_comparison.png",
        "$ReportRelativePath/session44_actual_vs_predicted_comparison.png",
        $AutomationName
    )

    foreach ($RequiredPath in $RequiredStagedOrTracked) {
        & git ls-files --error-unmatch -- $RequiredPath 2>$null | Out-Null
        $AlreadyTracked = ($LASTEXITCODE -eq 0)

        if (-not $AlreadyTracked -and $AllStaged -notcontains $RequiredPath) {
            throw "Required deliverable is neither tracked nor staged: $RequiredPath"
        }
    }

    Write-Host "Staged files:"
    & git diff --cached --name-status

    & git diff --cached --quiet
    $NoStagedChanges = ($LASTEXITCODE -eq 0)

    if ($NoStagedChanges) {
        Write-Host "No new Session 44 changes require a commit."
    }
    else {
        Invoke-Git -Arguments @("commit", "-m", $CommitMessage) `
            -FailureMessage "The Session 44 Git commit failed."
        Write-Host "Session 44 commit created."
    }

    # --------------------------------------------------------
    # 9. Push and verify the actual GitHub branch commit
    # --------------------------------------------------------

    Write-Section "PUSHING AND VERIFYING GITHUB"

    Invoke-Git -Arguments @(
        "push", "--set-upstream", "origin", $BranchName
    ) -FailureMessage "GitHub push failed. Confirm authentication with: gh auth status"

    $LocalCommit = [string](& git rev-parse HEAD)
    $LocalCommit = $LocalCommit.Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($LocalCommit)) {
        throw "Unable to read the local commit hash."
    }

    $RemoteReference = @(& git ls-remote --heads origin $BranchName)
    if ($LASTEXITCODE -ne 0 -or $RemoteReference.Count -eq 0) {
        throw "The remote branch is not visible on GitHub: $BranchName"
    }

    $RemoteCommit = ($RemoteReference[0] -split "\s+")[0].Trim()
    if ($LocalCommit -ne $RemoteCommit) {
        throw "Push verification failed. Local commit $LocalCommit does not match remote commit $RemoteCommit."
    }

    # --------------------------------------------------------
    # 10. Display completion evidence
    # --------------------------------------------------------

    Write-Section "FINAL EVIDENCE"

    $MetricsRows |
        Select-Object Model, MAE, RMSE, R2 |
        Format-Table -AutoSize

    Get-ChildItem -LiteralPath $ReportDirectory -File |
        Select-Object Name, Length |
        Sort-Object Name |
        Format-Table -AutoSize

    Write-Host "Branch: $BranchName"
    Write-Host "Commit: $LocalCommit"
    Write-Host "Remote: $RemoteUrl"
    Write-Host ""
    Write-Host "SESSION 44 GITHUB DELIVERABLE COMPLETED"
}
catch {
    Write-Host ""
    Write-Host "SESSION 44 AUTOMATION STOPPED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $TemporaryPythonPath -PathType Leaf) {
        Remove-Item -LiteralPath $TemporaryPythonPath -Force -ErrorAction SilentlyContinue
    }
}
