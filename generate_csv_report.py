#!/usr/bin/env python3
"""Generate CSV report from scan data with security scores and UTM recommendations."""
import argparse
import json
import csv
from typing import List, Dict

from security_score import calc_security_score
from report_utils import calc_utm_items


def generate_report(devices: List[Dict]) -> List[List[str]]:
    rows = []
    for dev in devices:
        name = dev.get("device") or dev.get("ip") or "unknown"
        ports = [str(p) for p in dev.get("open_ports", [])]
        countries = [c.upper() for c in dev.get("countries", [])]
        danger_list = [p for p in ports if p in {"3389", "445", "23"}]
        data = {
            "danger_ports": danger_list,
            "geoip": countries[0] if countries else "",
            "open_port_count": len(ports),
            "ssl": dev.get("ssl", True),
            "dns_fail_rate": 0.0,
        }
        res = calc_security_score(data)
        score = res["score"]
        utm = calc_utm_items(score, ports, countries)
        rows.append([
            name,
            str(score),
            ",".join(ports),
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
