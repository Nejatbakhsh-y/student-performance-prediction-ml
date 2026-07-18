# Session 22: Reproducible Train/Test Split

`src/preprocess.py` provides `split_modeling_scenarios`, which applies one
reproducible 80/20 row split (`random_state=42`) to the full-information and
early-warning feature matrices and their shared target.
