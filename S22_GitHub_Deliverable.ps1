$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = "C:\Users\nejat\OneDrive\Desktop\UN\Skills\GitHub 2026\student-performance-prediction-ml"
Set-Location -LiteralPath $RepoRoot

function Check([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit $LASTEXITCODE)." }
}

if (-not (Test-Path .git)) { throw "Not a Git repository: $RepoRoot" }
$Branch = (git branch --show-current).Trim(); Check "Branch detection"
if (-not $Branch) { throw "Detached HEAD; check out a branch first." }

$Python = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) {
    py -3.11 -m venv .venv; Check "Creating .venv"
}
& $Python -c "import pandas, sklearn, pytest" 2>$null
if ($LASTEXITCODE -ne 0) {
    & $Python -m pip install pandas scikit-learn pytest; Check "Installing packages"
}

New-Item -ItemType Directory -Force src,tests,docs | Out-Null
$Preprocess = Join-Path $RepoRoot "src\preprocess.py"

$Block = @'
# BEGIN SESSION 22 SPLIT UTILITY
import pandas as pd
from sklearn.model_selection import train_test_split


def split_modeling_scenarios(
    X_full, X_early, y, *, test_size=0.20, random_state=42
):
    """Create aligned, reproducible splits for both modeling scenarios."""
    if not isinstance(X_full, pd.DataFrame):
        raise TypeError("X_full must be a pandas DataFrame.")
    if not isinstance(X_early, pd.DataFrame):
        raise TypeError("X_early must be a pandas DataFrame.")
    if isinstance(y, pd.DataFrame):
        if y.shape[1] != 1:
            raise ValueError("The target DataFrame must have one column.")
        y = y.iloc[:, 0].copy()
    elif isinstance(y, pd.Series):
        y = y.copy()
    else:
        raise TypeError("y must be a Series or one-column DataFrame.")
    if not 0 < test_size < 1:
        raise ValueError("test_size must be strictly between 0 and 1.")
    if not X_full.index.is_unique or not X_early.index.is_unique or not y.index.is_unique:
        raise ValueError("All row indices must be unique.")
    if not X_full.index.equals(X_early.index):
        raise ValueError("X_full and X_early must use the same row index.")
    if not X_full.index.equals(y.index):
        raise ValueError("Features and target must use the same row index.")
    if not set(X_early.columns).issubset(X_full.columns):
        raise ValueError("X_early columns must be a subset of X_full columns.")
    if y.name in X_full.columns or y.name in X_early.columns:
        raise ValueError("Target leakage detected.")

    train_idx, test_idx = train_test_split(
        X_full.index.to_numpy(), test_size=test_size,
        random_state=random_state, shuffle=True
    )
    result = {
        "Xtr_f": X_full.loc[train_idx].copy(),
        "Xte_f": X_full.loc[test_idx].copy(),
        "Xtr_e": X_early.loc[train_idx].copy(),
        "Xte_e": X_early.loc[test_idx].copy(),
        "ytr": y.loc[train_idx].copy(),
        "yte": y.loc[test_idx].copy(),
    }
    assert result["Xtr_f"].index.equals(result["Xtr_e"].index)
    assert result["Xte_f"].index.equals(result["Xte_e"].index)
    assert result["Xtr_f"].index.equals(result["ytr"].index)
    assert result["Xte_f"].index.equals(result["yte"].index)
    assert set(train_idx).isdisjoint(test_idx)
    return result
# END SESSION 22 SPLIT UTILITY
'@

$Old = if (Test-Path $Preprocess) { Get-Content $Preprocess -Raw } else { "" }
$Old = [regex]::Replace($Old, '(?s)# BEGIN SESSION 22 SPLIT UTILITY.*?# END SESSION 22 SPLIT UTILITY\s*', '').TrimEnd()
$New = if ($Old) { $Old + "`r`n`r`n" + $Block.Trim() + "`r`n" } else { $Block.Trim() + "`r`n" }
Set-Content -LiteralPath $Preprocess -Value $New -Encoding utf8

$Tests = @'
import sys
from pathlib import Path
import pandas as pd
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from preprocess import split_modeling_scenarios

def data():
    i = pd.Index(range(20), name="student_id")
    full = pd.DataFrame({"studytime": range(20), "G1": range(20), "G2": range(20)}, index=i)
    early = full.drop(columns=["G1", "G2"])
    y = pd.Series(range(20), index=i, name="G3")
    return full, early, y

def test_aligned_and_80_20():
    r = split_modeling_scenarios(*data())
    assert len(r["Xtr_f"]) == 16 and len(r["Xte_f"]) == 4
    assert r["Xtr_f"].index.equals(r["Xtr_e"].index)
    assert r["Xte_f"].index.equals(r["Xte_e"].index)
    assert r["Xtr_f"].index.equals(r["ytr"].index)
    assert set(r["Xtr_f"].index).isdisjoint(r["Xte_f"].index)

def test_reproducible():
    a, b = split_modeling_scenarios(*data()), split_modeling_scenarios(*data())
    pd.testing.assert_frame_equal(a["Xte_f"], b["Xte_f"])

def test_bad_indices_rejected():
    full, early, y = data(); early.index = range(30, 50)
    with pytest.raises(ValueError, match="same row index"):
        split_modeling_scenarios(full, early, y)

def test_leakage_rejected():
    full, early, y = data(); full["G3"] = y
    with pytest.raises(ValueError, match="Target leakage"):
        split_modeling_scenarios(full, early, y)
'@
Set-Content tests\test_preprocess_session22.py $Tests -Encoding utf8

$Docs = @'
# Session 22: Reproducible Train/Test Split

`src/preprocess.py` provides `split_modeling_scenarios`, which applies one
reproducible 80/20 row split (`random_state=42`) to the full-information and
early-warning feature matrices and their shared target.
'@
Set-Content docs\session22_train_test_split.md $Docs -Encoding utf8

& $Python -m py_compile $Preprocess; Check "Python compilation"
& $Python -m pytest tests\test_preprocess_session22.py -v; Check "Session 22 tests"

git add -- src/preprocess.py tests/test_preprocess_session22.py docs/session22_train_test_split.md
Check "Staging"
git diff --cached --check; Check "Diff validation"
git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    git commit -m "Add reproducible scenario train-test split utility"; Check "Commit"
}
git push -u origin $Branch; Check "Push"

Write-Host ""
Write-Host "SESSION 22 SECTION 8 COMPLETED SUCCESSFULLY"
Write-Host "Tests: PASSED"
Write-Host "Commit and GitHub push: COMPLETE"
git status --short
