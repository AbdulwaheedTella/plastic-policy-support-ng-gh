"""Check that a re-run reproduces the published tables.

Usage
-----
Before running the notebook, keep a copy of the published tables:

    python compare_tables.py --snapshot          # copies outputs/tables/ to published_tables/

Run the notebook (Kernel > Restart & Run All), then:

    python compare_tables.py                     # compares outputs/tables/ with published_tables/

Every CSV is compared cell by cell. Numbers count as equal when they agree to a relative
tolerance of 1e-6 (or an absolute tolerance of 1e-9). Each table is reported as:
  same      identical
  same*     identical apart from row order (ties, or text sorted under a different locale)
  rounding  differs only by one unit in the last rounded decimal (at most --rounding, default 0.0011),
            which happens when a value sits exactly on a rounding boundary
  DIFFERS   anything else
Exit code 0 = no table DIFFERS, 1 = at least one does.
"""
import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
NEW = ROOT / "outputs" / "tables"
REF = ROOT / "published_tables"


def cell_diffs(a, b, rtol, atol):
    """Compare two tables of the same shape cell by cell.
    Returns (problems, largest numeric difference among the cells that differ)."""
    problems, worst = [], 0.0
    for c in a.columns:
        x, y = a[c], b[c]
        if pd.api.types.is_numeric_dtype(x) and pd.api.types.is_numeric_dtype(y):
            xv, yv = x.to_numpy(float), y.to_numpy(float)
            ok = np.isclose(xv, yv, rtol=rtol, atol=atol, equal_nan=True)
            if not ok.all():
                i = int(np.argmax(~ok))
                worst = max(worst, float(np.nanmax(np.abs(xv[~ok] - yv[~ok]))) if np.isfinite(xv[~ok] - yv[~ok]).any() else np.inf)
                problems.append(f"{c}: {int((~ok).sum())} cell(s) differ (row {i}: {xv[i]} -> {yv[i]})")
        else:
            xs = np.array(["" if pd.isna(v) else str(v) for v in x], dtype=object)   # empty cells count as equal
            ys = np.array(["" if pd.isna(v) else str(v) for v in y], dtype=object)
            bad = xs != ys
            if bad.any():
                i = int(np.argmax(bad))
                worst = np.inf
                problems.append(f"{c}: {int(bad.sum())} cell(s) differ (row {i}: {xs[i]!r} -> {ys[i]!r})")
    return problems, worst


def compare(ref_file, new_file, rtol, atol, rounding):
    """Returns (status, message). status is 'same', 'order', 'rounding' or 'differs'."""
    a, b = pd.read_csv(ref_file), pd.read_csv(new_file)
    if list(a.columns) != list(b.columns):
        return "differs", f"columns differ: {sorted(set(a.columns) ^ set(b.columns))}"
    if a.shape != b.shape:
        return "differs", f"shape {a.shape} -> {b.shape}"
    problems, worst = cell_diffs(a, b, rtol, atol)
    if not problems:
        return "same", ""
    # Same rows in a different order (ties, or text sorted under a different locale)?
    key = lambda t: t.astype(str).sort_values(list(t.columns), kind="stable").index
    sa, sb = a.loc[key(a)].reset_index(drop=True), b.loc[key(b)].reset_index(drop=True)
    p2, w2 = cell_diffs(sa, sb, rtol, atol)
    if not p2:
        return "order", "same rows, different order"
    if w2 < worst:
        problems, worst = p2, w2
    # Tables are rounded to 3-4 decimals; a value on a rounding boundary can flip by one unit.
    if worst <= rounding:
        return "rounding", f"largest difference {worst:g} (rounding of the last decimal): " + "; ".join(problems)
    return "differs", "; ".join(problems)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--snapshot", action="store_true", help="copy outputs/tables/ to published_tables/ and stop")
    ap.add_argument("--ref", type=Path, default=REF, help="folder with the published tables")
    ap.add_argument("--new", type=Path, default=NEW, help="folder with the re-generated tables")
    ap.add_argument("--rtol", type=float, default=1e-6)
    ap.add_argument("--atol", type=float, default=1e-9)
    ap.add_argument("--rounding", type=float, default=0.0011,
                    help="differences up to this size are reported as rounding of the last decimal, not as failures")
    args = ap.parse_args()

    if args.snapshot:
        if args.ref.exists():
            sys.exit(f"{args.ref} already exists; delete it first if you want a fresh snapshot.")
        shutil.copytree(args.new, args.ref)
        print(f"Copied {len(list(args.ref.glob('*.csv')))} tables to {args.ref}")
        return

    if not args.ref.exists():
        sys.exit(f"No reference folder {args.ref}. Run 'python compare_tables.py --snapshot' before the notebook.")
    ref_files = sorted(args.ref.glob("*.csv"))
    labels = {"same": "same    ", "order": "same*   ", "rounding": "rounding", "differs": "DIFFERS "}
    counts = dict.fromkeys(labels, 0)
    for f in ref_files:
        g = args.new / f.name
        status, msg = ("differs", "missing in the new run") if not g.exists() else \
            compare(f, g, args.rtol, args.atol, args.rounding)
        counts[status] += 1
        print(f"{labels[status]} {f.name}" + (f": {msg}" if msg else ""))
    n_bad = counts["differs"]
    print(f"\n{len(ref_files) - n_bad} of {len(ref_files)} tables reproduced"
          f" (rtol={args.rtol}, atol={args.atol}): {counts['same']} identical, {counts['order']} identical apart from"
          f" row order (same*), {counts['rounding']} differing only by rounding of the last decimal (<= {args.rounding}).")
    if n_bad:
        print("T0_data_flow.csv is only re-created from the raw exports, so it cannot differ in a public re-run."
              "\nIf you ran with QUICK = True, bootstrap-based tables are expected to differ.")
    sys.exit(1 if n_bad else 0)


if __name__ == "__main__":
    main()
