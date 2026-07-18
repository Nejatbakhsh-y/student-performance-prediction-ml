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
