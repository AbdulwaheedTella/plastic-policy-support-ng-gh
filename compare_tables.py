"""Check that a re-run reproduces the published tables.

Usage
-----
Before running the notebook, keep a copy of the published tables:

    python compare_tables.py --snapshot          # copies outputs/tables/ to published_tables/

Run the notebook (Kernel > Restart & Run All), then:

    python compare_tables.py                     # compares outputs/tables/ with published_tables/

Every CSV is compared cell by cell. Numbers count as equal when they agree to a relative
tolerance of 1e-6 (or an absolute tolerance of 1e-9), so tiny floating-point differences between
operating systems do not count as failures. Use --rtol to loosen or tighten this.
Exit code 0 = all tables match, 1 = at least one table differs.
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


def compare(ref_file, new_file, rtol, atol):
    a, b = pd.read_csv(ref_file), pd.read_csv(new_file)
    if list(a.columns) != list(b.columns):
        return f"columns differ: {sorted(set(a.columns) ^ set(b.columns))}"
    if a.shape != b.shape:
        return f"shape {a.shape} -> {b.shape}"
    problems = []
    for c in a.columns:
        x, y = a[c], b[c]
        if pd.api.types.is_numeric_dtype(x) and pd.api.types.is_numeric_dtype(y):
            xv, yv = x.to_numpy(float), y.to_numpy(float)
            ok = np.isclose(xv, yv, rtol=rtol, atol=atol, equal_nan=True)
            if not ok.all():
                i = int(np.argmax(~ok))
                problems.append(f"{c}: {int((~ok).sum())} cell(s) differ (row {i}: {xv[i]} -> {yv[i]})")
        else:
            xs, ys = x.astype(str), y.astype(str)
            bad = xs != ys
            if bad.any():
                i = int(np.argmax(bad.to_numpy()))
                problems.append(f"{c}: {int(bad.sum())} cell(s) differ (row {i}: {xs.iloc[i]!r} -> {ys.iloc[i]!r})")
    return "; ".join(problems)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--snapshot", action="store_true", help="copy outputs/tables/ to published_tables/ and stop")
    ap.add_argument("--ref", type=Path, default=REF, help="folder with the published tables")
    ap.add_argument("--new", type=Path, default=NEW, help="folder with the re-generated tables")
    ap.add_argument("--rtol", type=float, default=1e-6)
    ap.add_argument("--atol", type=float, default=1e-9)
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
    n_bad = 0
    for f in ref_files:
        g = args.new / f.name
        if not g.exists():
            msg = "missing in the new run"
        else:
            msg = compare(f, g, args.rtol, args.atol)
        if msg:
            n_bad += 1
            print(f"DIFFERS  {f.name}: {msg}")
        else:
            print(f"same     {f.name}")
    print(f"\n{len(ref_files) - n_bad} of {len(ref_files)} tables reproduced"
          f" (rtol={args.rtol}, atol={args.atol}).")
    if n_bad:
        print("T0_data_flow.csv is only re-created from the raw exports, so it cannot differ in a public re-run."
              "\nIf you ran with QUICK = True, bootstrap-based tables are expected to differ.")
    sys.exit(1 if n_bad else 0)


if __name__ == "__main__":
    main()
