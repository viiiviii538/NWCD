#!/usr/bin/env python3
"""Calculate network security scores from assorted risk indicators."""

from __future__ import annotations

import json
import sys
from typing import Any, Dict

from common_constants import DANGER_COUNTRIES, SAFE_COUNTRIES

# Weighting factors for each risk level used in the final score calculation
HIGH_WEIGHT = 4.5
MEDIUM_WEIGHT = 1.7
LOW_WEIGHT = 0.5

__all__ = ["calc_security_score"]

# Limits applied to individual metrics
PORT_SCORE_CAP = 6.0
COUNTRY_SCORE_CAP = 4.0
OS_VERSION_POINTS = 0.7


def calc_security_score(data: Dict[str, Any]) -> Dict[str, Any]:
    """Return overall score and risk counts for the given metrics."""

    high = medium = low = 0

    # Number of dangerous ports open (3389, 445, etc.)
    dp = data.get("danger_ports", [])
    try:
        high += len(list(dp))
    except TypeError:
        high += int(dp)

    # Country classification
    geo = str(data.get("geoip", "")).upper()
    if geo in DANGER_COUNTRIES:
        high += 1
    elif geo and geo not in SAFE_COUNTRIES:
        medium += 1

    # SSL certificate status
    ssl_status = str(data.get("ssl", "")).lower()
    if ssl_status in {"invalid", "self-signed"}:
        high += 1

    if data.get("upnp"):
        medium += 1

    firewall = data.get("firewall_enabled")
    if firewall is False:
        high += 1

    defender = data.get("defender_enabled")
    if defender is False:
        high += 1

    ver = str(data.get("os_version") or data.get("windows_version") or "").lower()
    if ver:
        if any(v in ver for v in ("windows xp", "windows vista")):
            high += 1
        elif any(v in ver for v in ("windows 7", "windows 8", "windows 8.1")):
            medium += 1

    if data.get("smbv1") or data.get("smb1") or str(data.get("smb_protocol", "")).lower().startswith("smbv1"):
        high += 1

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

    # LAN security scan results (arp spoofing, netbios exposure, etc.)
    arp = data.get("arp_spoofing")
    if isinstance(arp, dict):
        arp = arp.get("status")
    if str(arp).lower() == "warning":
        high += 1

    netbios = data.get("netbios")
    if isinstance(netbios, dict):
        netbios = netbios.get("status")
    if str(netbios).lower() == "warning":
        high += 1

    dhcp = data.get("dhcp")
    if isinstance(dhcp, dict):
        dhcp = dhcp.get("status")
    if str(dhcp).lower() == "warning":
        medium += 1

    ext_comm = data.get("external_comm")
    if isinstance(ext_comm, dict):
        ext_comm = ext_comm.get("status")
    if str(ext_comm).lower() == "warning":
        high += 1

    score = 10.0 - high * HIGH_WEIGHT - medium * MEDIUM_WEIGHT - low * LOW_WEIGHT
    score = max(0.0, min(10.0, score))

    return {
        "score": round(score, 1),
        "high_risk": int(high),
        "medium_risk": int(medium),
        "low_risk": int(low),
    }


def main() -> None:
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
        print(f"{name}\tScore: {res['score']}")


if __name__ == "__main__":
    main()
