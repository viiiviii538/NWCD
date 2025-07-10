#!/usr/bin/env python3
"""Assign security scores to devices based on open ports and remote countries."""
import json
import sys

from common_constants import (
    DANGER_COUNTRIES,
    SAFE_COUNTRIES,
    RED,
    RESET,
)


# Score added when encountering an unknown port.
# Unknown services still add a small amount of risk.
UNKNOWN_PORT_POINTS = 0.5

PORT_SCORE_CAP = 6.0
COUNTRY_SCORE_CAP = 4.0
OS_VERSION_POINTS = 0.7

__all__ = ["calc_security_score"]

PORT_SCORES = {
    "3389": 4.0,  # RDP
    "445": 3.0,   # SMB
    "23": 2.0,    # Telnet
    "22": 1.5,    # SSH
    "21": 1.0,    # FTP
    "80": 1.0,    # HTTP
    "443": 0.5,   # HTTPS
}




def calc_security_score(
    open_ports: list[str],
    countries: list[str],
    has_utm: bool = False,
    os_version: str | None = None,
) -> tuple[float, list[str]]:
    """Return security score (0.0-10.0) and warnings for the given data."""

    warnings: list[str] = []
    port_points = 0.0
    for p in open_ports:
        if p in PORT_SCORES:
            port_points += PORT_SCORES[p]
            if p == "3389":
                warnings.append(f"{RED}RDP port open (3389){RESET}")
        else:
            port_points += UNKNOWN_PORT_POINTS
    port_points = min(port_points, PORT_SCORE_CAP)

    country_points = 0.0
    for c in countries:
        c_up = c.upper()
        if c_up in DANGER_COUNTRIES:
            country_points += 3.0
            warnings.append(f"{RED}Communicating with {c_up}{RESET}")
        elif c_up not in SAFE_COUNTRIES and c_up:
            country_points += 0.5
    country_points = min(country_points, COUNTRY_SCORE_CAP)

    os_points = 0.0
    if os_version in {"Windows 7", "Windows XP", "Windows 8"}:
        os_points += OS_VERSION_POINTS

    score = port_points + country_points + os_points
    if has_utm:
        score *= 0.8

    score = max(0.0, min(10.0, score))
    return round(score, 1), warnings



def main():
    """Read device data from a JSON file and print each device's security score.

    The path to the JSON file is expected as the first command line argument.
    The file should contain a list of device dictionaries with ``open_ports`` and
    ``countries`` fields. Scores and any warnings are printed to ``stdout``.
    """
    if len(sys.argv) < 2:
        print("Usage: security_score.py <input.json>", file=sys.stderr)
        sys.exit(1)
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        devices = json.load(f)
    for dev in devices:
        name = dev.get("device") or dev.get("ip") or "unknown"
        ports = dev.get("open_ports", [])
        countries = dev.get("countries", [])
        os_ver = dev.get("os_version")
        score, warns = calc_security_score(
            [str(p) for p in ports],
            [c.upper() for c in countries],
            os_version=os_ver,
        )
        warn_text = "; ".join(warns) if warns else ""
        print(f"{name}\tScore: {score}\t{warn_text}")

if __name__ == "__main__":
    main()
