#!/usr/bin/env python3
"""Calculate network security scores from assorted risk indicators."""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, Optional

from common_constants import DANGER_COUNTRIES, SAFE_COUNTRIES

# Weighting factors for each risk level used in the final score calculation
HIGH_WEIGHT = 4.5
MEDIUM_WEIGHT = 1.7
LOW_WEIGHT = 0.5
UTM_BONUS = 2.0

# Ports considered especially dangerous. Used by security_report.py
DANGER_PORTS = {"3389", "445", "23"}

# Default texts describing how to mitigate each risk type
COUNTERMEASURES = {
    "open_ports": "Close unused ports or enable a firewall",
    "ssl_invalid": "Install a valid SSL certificate",
    "spf_missing": "Configure an SPF record",
    "foreign_geoip": "Review foreign traffic or use web filtering",
}

__all__ = ["calc_security_score", "load_config", "DANGER_PORTS", "COUNTERMEASURES"]

# Limits applied to individual metrics
PORT_SCORE_CAP = 6.0
COUNTRY_SCORE_CAP = 4.0
OS_VERSION_POINTS = 0.7

# Base configuration merged with any loaded from file
_DEFAULT_CONFIG = {
    "danger_ports": list(DANGER_PORTS),
    "weights": {
        "high": HIGH_WEIGHT,
        "medium": MEDIUM_WEIGHT,
        "low": LOW_WEIGHT,
    },
    "utm_bonus": UTM_BONUS,
    "countermeasures": COUNTERMEASURES.copy(),
}

# Holds the active configuration in effect
CONFIG = _DEFAULT_CONFIG.copy()


def load_config(path: Optional[str] = None) -> None:
    """Load YAML/JSON config overriding default constants.

    Passing ``None`` resets all values back to the defaults.
    """

    global HIGH_WEIGHT, MEDIUM_WEIGHT, LOW_WEIGHT, UTM_BONUS
    global DANGER_PORTS, COUNTERMEASURES, CONFIG

    cfg = _DEFAULT_CONFIG.copy()

    if path:
        with open(path, "r", encoding="utf-8") as f:
            if path.endswith(('.yaml', '.yml')):
                try:
                    import yaml  # type: ignore
                except Exception as exc:  # pragma: no cover - error path
                    raise ImportError("PyYAML required for YAML configs") from exc
                data = yaml.safe_load(f) or {}
            else:
                data = json.load(f) or {}
        if isinstance(data, dict):
            if "danger_ports" in data:
                cfg["danger_ports"] = [str(p) for p in data["danger_ports"]]
            if "weights" in data and isinstance(data["weights"], dict):
                cfg["weights"].update({
                    k: float(v) for k, v in data["weights"].items()
                    if k in {"high", "medium", "low"}
                })
            if "utm_bonus" in data:
                cfg["utm_bonus"] = float(data["utm_bonus"])
            if "countermeasures" in data and isinstance(data["countermeasures"], dict):
                cfg["countermeasures"].update({
                    str(k): str(v) for k, v in data["countermeasures"].items()
                })

    CONFIG = cfg

    HIGH_WEIGHT = float(cfg["weights"]["high"])
    MEDIUM_WEIGHT = float(cfg["weights"]["medium"])
    LOW_WEIGHT = float(cfg["weights"]["low"])
    UTM_BONUS = float(cfg.get("utm_bonus", UTM_BONUS))

    # Update sets/dicts in place so existing imports see new values
    DANGER_PORTS.clear()
    DANGER_PORTS.update(str(p) for p in cfg.get("danger_ports", []))
    COUNTERMEASURES.clear()
    COUNTERMEASURES.update(cfg.get("countermeasures", {}))

# Initialize module-level constants
load_config(None)



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
    if data.get("utm_active"):
        score += UTM_BONUS
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

