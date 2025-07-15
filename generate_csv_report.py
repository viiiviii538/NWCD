#!/usr/bin/env python3
"""Generate CSV report from scan data.

This wrapper calls into :mod:`generate_html_report` for the actual
implementation and is kept for backward compatibility.
"""
from __future__ import annotations

import argparse
import json

from generate_html_report import save_csv_report, _extract_devices


def main() -> None:
    parser = argparse.ArgumentParser(description="Create CSV report from scan results")
    parser.add_argument("input", help="Input JSON file with scan results")
    parser.add_argument("-o", "--output", default="scan_report.csv", help="Output CSV file")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    save_csv_report(_extract_devices(data), args.output)
    print(f"Report written to {args.output}")


if __name__ == "__main__":
    main()
