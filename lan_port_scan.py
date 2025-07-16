#!/usr/bin/env python3
"""Discover LAN hosts and run port scan on each."""
import argparse
import json

from discover_hosts import _get_subnet, _run_nmap_scan, _lookup_vendor
from port_scan import run_scan, SCAN_TIMEOUT
from concurrent.futures import ThreadPoolExecutor, as_completed

DEFAULT_PORTS = [
    "21",
    "22",
    "23",
    "25",
    "53",
    "80",
    "110",
    "143",
    "443",
    "445",
    "3306",
    "3389",
    "8080",
    "8443",
    "1723",
    "5900",
]


def gather_hosts(subnet: str):
    """Return list of hosts with ip, mac and vendor."""
    hosts = _run_nmap_scan(subnet, timeout=SCAN_TIMEOUT)
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
    max_workers: int | None = None,
):
    hosts = gather_hosts(subnet)
    results = []
    # Limit worker count to avoid exhausting system resources
    if max_workers is None:
        max_workers = min(32, max(1, len(hosts)))
    else:
        max_workers = max(1, max_workers)
    future_to_host = {}
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        for h in hosts:
            future = executor.submit(
                run_scan,
                h["ip"],
                ports,
                service=service,
                os_detect=os_detect,
                scripts=scripts,
                progress_timeout=SCAN_TIMEOUT,
            )
            future_to_host[future] = h

        for fut in as_completed(future_to_host):
            h = future_to_host[fut]
            scanned = fut.result()
            results.append(
                {
                    "ip": h.get("ip", ""),
                    "mac": h.get("mac", ""),
                    "vendor": h.get("vendor", ""),
                    "os": scanned.get("os", ""),
                    "ports": scanned.get("ports", []),
                }
            )
    return results


def main():
    parser = argparse.ArgumentParser(description="LAN host discovery and port scan")
    parser.add_argument("--subnet", help="Subnet like 192.168.1.0/24")
    parser.add_argument("--ports", help="Comma separated port list")
    parser.add_argument(
        "--service", action="store_true", help="Enable service version detection"
    )
    parser.add_argument("--os", action="store_true", help="Enable OS detection")
    parser.add_argument("--script", help="Comma separated nmap scripts")
    parser.add_argument(
        "--workers",
        type=int,
        help="Number of concurrent workers",
    )
    args = parser.parse_args()

    subnet = args.subnet or _get_subnet() or "192.168.1.0/24"
    if args.ports:
        ports = [p.strip() for p in args.ports.split(",") if p.strip()]
    else:
        ports = DEFAULT_PORTS
    scripts = args.script.split(",") if args.script else None
    results = scan_hosts(
        subnet,
        ports,
        service=args.service,
        os_detect=args.os,
        scripts=scripts,
        max_workers=args.workers,
    )
    print(json.dumps(results, ensure_ascii=False))


if __name__ == "__main__":
    print("Deprecated: use nwcd_cli.py lan-scan", file=sys.stderr)
    main()
