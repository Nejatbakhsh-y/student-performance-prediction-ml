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
