"""Reusable evaluation helpers for regression models."""

from typing import Dict, Sequence, Union

import numpy as np
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)


ArrayLike1D = Union[Sequence[float], np.ndarray]


def eval_reg(
    y_true: ArrayLike1D,
    y_pred: ArrayLike1D,
) -> Dict[str, float]:
    """Calculate MAE, RMSE, and R-squared for regression predictions."""

    true_values = np.asarray(y_true, dtype=float)
    predicted_values = np.asarray(y_pred, dtype=float)

    if true_values.ndim != 1 or predicted_values.ndim != 1:
        raise ValueError("y_true and y_pred must be one-dimensional.")

    if true_values.size == 0 or predicted_values.size == 0:
        raise ValueError("y_true and y_pred cannot be empty.")

    if true_values.size != predicted_values.size:
        raise ValueError(
            "y_true and y_pred must contain the same number of values."
        )

    if true_values.size < 2:
        raise ValueError(
            "At least two observations are required to calculate R2."
        )

    if not np.all(np.isfinite(true_values)):
        raise ValueError("y_true contains missing or infinite values.")

    if not np.all(np.isfinite(predicted_values)):
        raise ValueError("y_pred contains missing or infinite values.")

    mse = mean_squared_error(true_values, predicted_values)

    return {
        "MAE": float(
            mean_absolute_error(true_values, predicted_values)
        ),
        "RMSE": float(np.sqrt(mse)),
        "R2": float(
            r2_score(true_values, predicted_values)
        ),
    }