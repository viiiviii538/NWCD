#!/usr/bin/env python3
"""Discover LAN hosts and run port scan on each."""
import argparse
import json

from discover_hosts import _get_subnet, _run_arp_scan, _run_nmap_scan, _lookup_vendor
from port_scan import run_scan

DEFAULT_PORTS = [
    "21", "22", "23", "25", "53", "80", "110", "143",
    "443", "445", "3306", "3389", "8080", "8443", "1723", "5900",
]


def gather_hosts(subnet: str):
    """Return list of hosts with ip, mac and vendor."""
    try:
        hosts = _run_arp_scan()
    except Exception:
        hosts = _run_nmap_scan(subnet)
    for h in hosts:
        if not h.get("vendor"):
            h["vendor"] = _lookup_vendor(h.get("mac", ""))
    return hosts


def scan_hosts(
    subnet: str,
    ports: list[str],
    service: bool = False,
    os_detect: bool = False,
    scripts: list[str] | None = None,
):
    hosts = gather_hosts(subnet)
    results = []
    for h in hosts:
        scanned = run_scan(
            h["ip"],
            ports,
            service=service,
            os_detect=os_detect,
            scripts=scripts,
        )
        results.append({
            "ip": h.get("ip", ""),
            "mac": h.get("mac", ""),
            "vendor": h.get("vendor", ""),
            "ports": scanned,
        })
    return results


def main():
    parser = argparse.ArgumentParser(description="LAN host discovery and port scan")
    parser.add_argument("--subnet", help="Subnet like 192.168.1.0/24")
    parser.add_argument("--ports", help="Comma separated port list")
    parser.add_argument("--service", action="store_true", help="Enable service version detection")
    parser.add_argument("--os", action="store_true", help="Enable OS detection")
    parser.add_argument("--script", help="Comma separated nmap scripts")
    args = parser.parse_args()

    subnet = args.subnet or _get_subnet() or "192.168.1.0/24"
    if args.ports:
        ports = [p.strip() for p in args.ports.split(',') if p.strip()]
    else:
        ports = DEFAULT_PORTS
    scripts = args.script.split(',') if args.script else None
    results = scan_hosts(
        subnet,
        ports,
        service=args.service,
        os_detect=args.os,
        scripts=scripts,
    )
    print(json.dumps(results, ensure_ascii=False))


if __name__ == "__main__":
    main()
