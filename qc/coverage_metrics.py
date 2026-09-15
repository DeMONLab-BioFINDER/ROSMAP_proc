#!/usr/bin/env python3
"""Summarize parcel coverage TSV files produced by XCP-D."""

from __future__ import annotations

import argparse
import glob
from pathlib import Path

import pandas as pd


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Compute mean coverage and the number of entries below a threshold "
            "for each XCP-D coverage TSV."
        )
    )
    parser.add_argument("input_glob", help="Glob matching coverage TSV files (quote it in the shell).")
    parser.add_argument("output_tsv", type=Path, help="Output summary TSV.")
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="Coverage threshold for the low-coverage count (default: 0.5).",
    )
    parser.add_argument(
        "--column",
        help="Coverage column name. By default, the second TSV column is used.",
    )
    return parser.parse_args()


def get_coverage_column(df: pd.DataFrame, column: str | None, source: Path) -> pd.Series:
    if column is not None:
        if column not in df.columns:
            raise ValueError(f"{source}: column {column!r} not found; columns={list(df.columns)!r}")
        values = df[column]
    else:
        if df.shape[1] < 2:
            raise ValueError(f"{source}: expected at least two columns")
        values = df.iloc[:, 1]

    numeric = pd.to_numeric(values, errors="coerce")
    if numeric.notna().sum() == 0:
        raise ValueError(f"{source}: coverage column contains no numeric values")
    return numeric


def subject_session_from_name(path: Path) -> str:
    return path.name.split("_task-rest", maxsplit=1)[0]


def main() -> None:
    args = parse_args()
    files = [Path(p) for p in sorted(glob.glob(args.input_glob))]
    if not files:
        raise SystemExit(f"No files matched: {args.input_glob}")

    rows: list[dict[str, object]] = []
    for path in files:
        df = pd.read_csv(path, sep="\t")
        coverage = get_coverage_column(df, args.column, path)
        rows.append(
            {
                "sub_ses": subject_session_from_name(path),
                "mean_coverage_percent": coverage.mean() * 100,
                "count_below_threshold": int((coverage < args.threshold).sum()),
                "threshold": args.threshold,
            }
        )

    args.output_tsv.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(args.output_tsv, sep="\t", index=False)
    print(f"Wrote {len(rows)} rows to {args.output_tsv}")


if __name__ == "__main__":
    main()
