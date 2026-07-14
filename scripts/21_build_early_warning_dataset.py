"""
GSSRP 2026
Session 21: Early-Warning Dataset Design

This script:

1. Locates the Session 20 full-information feature matrix and target.
2. Verifies that G1 and G2 are available in X_full.
3. Verifies that G3 is stored separately as the target.
4. Creates X_early by removing G1 and G2.
5. Saves CSV and Parquet artifacts.
6. Reloads and validates the saved files.
7. Creates an artifact summary and reproducibility manifest.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)


def read_table(path: Path) -> pd.DataFrame:
    """Read a supported CSV or Parquet table."""

    suffix = path.suffix.lower()

    if suffix == ".parquet":
        return pd.read_parquet(path)

    if suffix == ".csv":
        return pd.read_csv(path)

    raise ValueError(f"Unsupported file type: {path}")


def remove_exported_index_columns(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """Remove accidental CSV index columns such as Unnamed: 0."""

    unwanted_columns = [
        column
        for column in dataframe.columns
        if str(column).startswith("Unnamed:")
    ]

    if unwanted_columns:
        dataframe = dataframe.drop(columns=unwanted_columns)

    return dataframe


def find_first_existing(
    candidates: list[Path],
) -> Path | None:
    """Return the first existing file from a candidate list."""

    for candidate in candidates:
        if candidate.exists():
            return candidate

    return None


# ============================================================
# Candidate Session 20 files
# ============================================================

feature_candidates = [
    PROCESSED_DIR / "X_full.parquet",
    PROCESSED_DIR / "X_full.csv",
    PROCESSED_DIR / "full_information_features.parquet",
    PROCESSED_DIR / "full_information_features.csv",
]

target_candidates = [
    PROCESSED_DIR / "y_full.parquet",
    PROCESSED_DIR / "y_full.csv",
    PROCESSED_DIR / "y.parquet",
    PROCESSED_DIR / "y.csv",
    PROCESSED_DIR / "target_G3.parquet",
    PROCESSED_DIR / "target_G3.csv",
]

combined_candidates = [
    PROCESSED_DIR / "full_information_dataset.parquet",
    PROCESSED_DIR / "full_information_dataset.csv",
]


feature_path = find_first_existing(feature_candidates)
target_path = find_first_existing(target_candidates)
combined_path = find_first_existing(combined_candidates)


# ============================================================
# Load X_full and y
# ============================================================

if feature_path is not None and target_path is not None:
    X_full = read_table(feature_path)
    target_table = read_table(target_path)

    source_description = (
        f"Features: {feature_path.name}; "
        f"Target: {target_path.name}"
    )

elif combined_path is not None:
    combined_table = read_table(combined_path)
    combined_table = remove_exported_index_columns(combined_table)

    if "G3" not in combined_table.columns:
        raise KeyError(
            f"{combined_path.name} does not contain the G3 target."
        )

    X_full = combined_table.drop(columns=["G3"]).copy()
    target_table = combined_table[["G3"]].copy()

    source_description = (
        f"Combined source: {combined_path.name}"
    )

else:
    expected_files = [
        path.name
        for path in (
            feature_candidates
            + target_candidates
            + combined_candidates
        )
    ]

    raise FileNotFoundError(
        "Session 20 source files were not found in "
        f"{PROCESSED_DIR}.\n\nExpected one of these files:\n- "
        + "\n- ".join(expected_files)
        + "\n\nComplete Session 20 Section 8 before running Session 21."
    )


X_full = remove_exported_index_columns(X_full)
target_table = remove_exported_index_columns(target_table)

X_full = X_full.reset_index(drop=True).copy()
target_table = target_table.reset_index(drop=True).copy()


# ============================================================
# Prepare the G3 target
# ============================================================

if "G3" in target_table.columns:
    y = target_table["G3"].copy()

elif target_table.shape[1] == 1:
    y = target_table.iloc[:, 0].copy()
    y.name = "G3"

else:
    raise ValueError(
        "The target file must contain a G3 column or exactly "
        "one target column."
    )


y = y.reset_index(drop=True).copy()
y.name = "G3"


# ============================================================
# Validate the Session 20 source data
# ============================================================

if "G3" in X_full.columns:
    raise AssertionError(
        "Target leakage detected: G3 is present in X_full."
    )


missing_prior_grade_columns = [
    column
    for column in ("G1", "G2")
    if column not in X_full.columns
]

if missing_prior_grade_columns:
    raise KeyError(
        "The following required Session 20 columns are missing "
        "from X_full: "
        + ", ".join(missing_prior_grade_columns)
    )


if len(X_full) != len(y):
    raise ValueError(
        "X_full and y contain different row counts: "
        f"{len(X_full)} versus {len(y)}."
    )


if X_full.columns.duplicated().any():
    duplicate_columns = (
        X_full.columns[X_full.columns.duplicated()]
        .tolist()
    )

    raise ValueError(
        f"Duplicate X_full columns detected: {duplicate_columns}"
    )


if X_full.empty:
    raise ValueError("X_full contains no rows.")


if y.empty:
    raise ValueError("The G3 target contains no rows.")


# ============================================================
# Create X_early
# ============================================================

removed_columns = [
    column
    for column in X_full.columns
    if column in ("G1", "G2")
]

if set(removed_columns) != {"G1", "G2"}:
    raise AssertionError(
        "Both G1 and G2 must be identified for removal. "
        f"Identified columns: {removed_columns}"
    )


X_early = (
    X_full
    .drop(columns=removed_columns)
    .reset_index(drop=True)
    .copy()
)

y_early = y.to_frame(name="G3")


# ============================================================
# Validate X_early
# ============================================================

assert isinstance(X_early, pd.DataFrame)
assert isinstance(y_early, pd.DataFrame)

assert "G1" not in X_early.columns
assert "G2" not in X_early.columns
assert "G3" not in X_early.columns

assert y_early.columns.tolist() == ["G3"]

assert len(X_early) == len(y_early)

assert X_early.shape[0] == X_full.shape[0]

assert X_early.shape[1] == X_full.shape[1] - 2

assert not X_early.columns.duplicated().any()


# ============================================================
# Define output files
# ============================================================

x_parquet_path = PROCESSED_DIR / "X_early.parquet"
y_parquet_path = PROCESSED_DIR / "y_early.parquet"

x_csv_path = PROCESSED_DIR / "X_early.csv"
y_csv_path = PROCESSED_DIR / "y_early.csv"

summary_path = (
    PROCESSED_DIR
    / "session21_early_warning_artifact_summary.csv"
)

manifest_path = (
    PROCESSED_DIR
    / "session21_early_warning_manifest.json"
)


# ============================================================
# Save the primary artifacts
# ============================================================

X_early.to_parquet(
    x_parquet_path,
    index=False,
)

y_early.to_parquet(
    y_parquet_path,
    index=False,
)

X_early.to_csv(
    x_csv_path,
    index=False,
)

y_early.to_csv(
    y_csv_path,
    index=False,
)


# ============================================================
# Reload and validate the saved files
# ============================================================

X_early_reloaded = pd.read_parquet(x_parquet_path)
y_early_reloaded = pd.read_parquet(y_parquet_path)


pd.testing.assert_frame_equal(
    X_early.reset_index(drop=True),
    X_early_reloaded.reset_index(drop=True),
    check_dtype=True,
)

pd.testing.assert_frame_equal(
    y_early.reset_index(drop=True),
    y_early_reloaded.reset_index(drop=True),
    check_dtype=True,
)


assert "G1" not in X_early_reloaded.columns
assert "G2" not in X_early_reloaded.columns
assert "G3" not in X_early_reloaded.columns

assert y_early_reloaded.columns.tolist() == ["G3"]

assert len(X_early_reloaded) == len(y_early_reloaded)


# ============================================================
# Create the artifact summary
# ============================================================

artifact_summary = pd.DataFrame(
    {
        "Artifact": [
            "X_early",
            "y_early",
        ],
        "Purpose": [
            "Early-warning predictor matrix",
            "Final-grade target",
        ],
        "Rows": [
            X_early.shape[0],
            y_early.shape[0],
        ],
        "Columns": [
            X_early.shape[1],
            y_early.shape[1],
        ],
        "Contains_G1": [
            "G1" in X_early.columns,
            "G1" in y_early.columns,
        ],
        "Contains_G2": [
            "G2" in X_early.columns,
            "G2" in y_early.columns,
        ],
        "Contains_G3": [
            "G3" in X_early.columns,
            "G3" in y_early.columns,
        ],
    }
)

artifact_summary.to_csv(
    summary_path,
    index=False,
)


# ============================================================
# Create the reproducibility manifest
# ============================================================

manifest = {
    "session": 21,
    "title": "Early-warning dataset design",
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "source": source_description,
    "feature_artifact": str(
        x_parquet_path.relative_to(PROJECT_ROOT)
    ),
    "target_artifact": str(
        y_parquet_path.relative_to(PROJECT_ROOT)
    ),
    "csv_feature_backup": str(
        x_csv_path.relative_to(PROJECT_ROOT)
    ),
    "csv_target_backup": str(
        y_csv_path.relative_to(PROJECT_ROOT)
    ),
    "rows": int(X_early.shape[0]),
    "full_feature_count": int(X_full.shape[1]),
    "early_feature_count": int(X_early.shape[1]),
    "features_removed_count": int(
        X_full.shape[1] - X_early.shape[1]
    ),
    "removed_columns": removed_columns,
    "target_column": "G3",
    "validation": {
        "G1_absent_from_X_early": (
            "G1" not in X_early.columns
        ),
        "G2_absent_from_X_early": (
            "G2" not in X_early.columns
        ),
        "G3_absent_from_X_early": (
            "G3" not in X_early.columns
        ),
        "G3_saved_as_target": (
            y_early.columns.tolist() == ["G3"]
        ),
        "row_counts_match": (
            len(X_early) == len(y_early)
        ),
        "exactly_two_features_removed": (
            X_early.shape[1] == X_full.shape[1] - 2
        ),
        "saved_files_match_memory": True,
    },
}

manifest_path.write_text(
    json.dumps(
        manifest,
        indent=2,
    ),
    encoding="utf-8",
)


# ============================================================
# Verify every output file
# ============================================================

output_paths = [
    x_parquet_path,
    y_parquet_path,
    x_csv_path,
    y_csv_path,
    summary_path,
    manifest_path,
]

for output_path in output_paths:
    if not output_path.exists():
        raise FileNotFoundError(
            f"Required output was not created: {output_path}"
        )

    if output_path.stat().st_size <= 0:
        raise ValueError(
            f"Required output is empty: {output_path}"
        )


# ============================================================
# Final output
# ============================================================

print("=" * 72)
print("SESSION 21 DATASET BUILD COMPLETED SUCCESSFULLY")
print("=" * 72)

print(f"\nSource: {source_description}")

print(f"\nOriginal X_full shape: {X_full.shape}")
print(f"Early-warning X_early shape: {X_early.shape}")
print(f"Target y_early shape: {y_early.shape}")

print(f"\nRemoved columns: {removed_columns}")
print(
    "Features removed:",
    X_full.shape[1] - X_early.shape[1],
)

print(
    "G1 absent from X_early:",
    "G1" not in X_early.columns,
)

print(
    "G2 absent from X_early:",
    "G2" not in X_early.columns,
)

print(
    "G3 absent from X_early:",
    "G3" not in X_early.columns,
)

print(
    "G3 saved as target:",
    y_early.columns.tolist() == ["G3"],
)

print(
    "Row counts match:",
    len(X_early) == len(y_early),
)

print("\nCreated files:")

for output_path in output_paths:
    file_size_kb = output_path.stat().st_size / 1024

    print(
        f"- {output_path.relative_to(PROJECT_ROOT)} "
        f"({file_size_kb:.2f} KB)"
    )

print("\nArtifact summary:")
print(artifact_summary.to_string(index=False))
