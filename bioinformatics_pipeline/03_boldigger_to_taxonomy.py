#!/usr/bin/env python3
"""Convert BOLDigger output to a simple taxonomy table.

Input:  BOLDigger identification result (xlsx or parquet)
Output: TSV with ASV_ID and taxonomy columns
"""

import argparse
from pathlib import Path
import pandas as pd


def read_boldigger(path: Path) -> pd.DataFrame:
    if path.suffix.lower() in {".parquet", ".snappy"}:
        return pd.read_parquet(path)
    if path.suffix.lower() in {".xlsx", ".xls"}:
        return pd.read_excel(path)
    if path.suffix.lower() in {".csv", ".tsv"}:
        sep = "\t" if path.suffix.lower() == ".tsv" else ","
        return pd.read_csv(path, sep=sep)
    raise ValueError(f"Unsupported input format: {path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="BOLDigger results file (xlsx/parquet/csv/tsv)")
    ap.add_argument("--output", required=True, help="Output taxonomy TSV")
    args = ap.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)

    df = read_boldigger(in_path)

    # Normalize column names
    col_map = {"id": "ASV_ID"}
    df = df.rename(columns=col_map)

    wanted = [
        "ASV_ID", "Phylum", "Class", "Order", "Family", "Genus", "Species",
        "pct_identity", "status", "records", "selected_level", "BIN", "flags"
    ]
    missing = [c for c in wanted if c not in df.columns]
    if missing:
        raise SystemExit(f"Missing expected columns: {missing}")

    df = df[wanted]
    df.to_csv(out_path, sep="\t", index=False)
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
