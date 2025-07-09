#!/usr/bin/env python3
"""Calculate network security scores from assorted risk indicators."""

from __future__ import annotations

import json
import sys
from typing import Any, Dict

from common_constants import DANGER_COUNTRIES, SAFE_COUNTRIES

__all__ = ["calc_security_score"]


def calc_security_score(data: Dict[str, Any]) -> Dict[str, Any]:
    """Return overall score and risk counts for the given metrics.

    Parameters
    ----------
    data : Dict[str, Any]
        Dictionary containing risk values such as ``danger_ports`` or ``geoip``.
    """

    high = medium = low = 0

    # list of ports considered dangerous (e.g. 3389, 445, telnet)
    dp = data.get("danger_ports", [])
    try:
        high += len(list(dp))
    except TypeError:
        # fallback for legacy integer values
        high += int(dp)

    geo = str(data.get("geoip", "")).upper()
    if geo in DANGER_COUNTRIES:
        high += 1
    elif geo and geo not in SAFE_COUNTRIES:
        medium += 1

    if data.get("ssl") is False:
        medium += 1

    if data.get("upnp"):
        medium += 1

    rate = float(data.get("dns_fail_rate", 0.0))
    if rate >= 0.5:
        high += 1
    elif rate >= 0.1:
        medium += 1
    elif rate > 0:
        low += 1

    http_ratio = float(data.get("http_ratio", 0.0))
    if http_ratio >= 0.5:
        medium += 1
    elif http_ratio > 0:
        low += 1

    unknown_ratio = float(data.get("unknown_mac_ratio", 0.0))
    if unknown_ratio >= 0.3:
        medium += 1
    elif unknown_ratio > 0:
        low += 1

    dev_count = int(data.get("device_count", 0))
    if dev_count > 50:
        medium += 1
    elif dev_count > 10:
        low += 1

    open_count = int(data.get("open_port_count", 0))
    if open_count > 15:
        high += 1
    elif open_count > 5:
        medium += 1
    elif open_count > 0:
        low += 1

    intl_ratio = float(data.get("intl_traffic_ratio", 0.0))
    if intl_ratio >= 0.5:
        high += 1
    elif intl_ratio >= 0.2:
        medium += 1
    elif intl_ratio > 0:
        low += 1

    if data.get("ip_conflict"):
        high += 1

    score = 10.0 - high * 0.7 - medium * 0.3 - low * 0.2
    score = max(0.0, min(10.0, score))

    return {
        "score": round(score, 1),
        "high_risk": int(high),
        "medium_risk": int(medium),
        "low_risk": int(low),
    }



def main():
    """Read risk data from JSON and print scores for each entry."""

    if len(sys.argv) < 2:
        print("Usage: security_score.py <input.json>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        devices = json.load(f)

    for dev in devices:
        name = dev.get("device") or dev.get("ip") or "unknown"
        res = calc_security_score(dev)
        print(
            f"{name}\tScore: {res['score']}"
            f"\t(H:{res['high_risk']} M:{res['medium_risk']} L:{res['low_risk']})"
        )

if __name__ == "__main__":
    main()
