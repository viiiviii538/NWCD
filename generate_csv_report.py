#!/usr/bin/env python3
"""Generate CSV report from scan data with risk scores and UTM recommendations."""
import argparse
import json
import csv
from typing import List, Dict

from risk_score import calc_risk_score
from common_constants import DANGER_COUNTRIES


def calc_utm_items(score: int, open_ports: List[str], countries: List[str]) -> List[str]:
    items = set()
    if open_ports:
        items.add("firewall")
    if any(c.upper() in DANGER_COUNTRIES for c in countries):
        items.add("web_filter")
    if score >= 5:
        items.add("ips")
    return sorted(items)


def generate_report(devices: List[Dict]) -> List[List[str]]:
    rows = []
    for dev in devices:
        name = dev.get("device") or dev.get("ip") or "unknown"
        open_ports = [str(p) for p in dev.get("open_ports", [])]
        countries = [c.upper() for c in dev.get("countries", [])]
        score, _warns = calc_risk_score(open_ports, countries)
        utm = calc_utm_items(score, open_ports, countries)
        rows.append([
            name,
            str(score),
            ",".join(open_ports),
            ",".join(countries),
            ",".join(utm),
        ])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Create CSV report from scan results")
    parser.add_argument("input", help="Input JSON file with scan results")
    parser.add_argument("-o", "--output", default="scan_report.csv", help="Output CSV file")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        devices = json.load(f)

    rows = generate_report(devices)
    header = ["device", "score", "open_ports", "countries", "utm_items"]
    with open(args.output, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"Report written to {args.output}")


if __name__ == "__main__":
    main()
