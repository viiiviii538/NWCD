#!/usr/bin/env python3
"""Host discovery utilities."""

import json
import sys

from network_utils import _get_subnet, _lookup_vendor, _run_nmap_scan


def discover_hosts(subnet: str | None = None) -> list[dict[str, str]]:
    """Return list of discovered hosts with IP, MAC, vendor, and hostname."""
    subnet = subnet or _get_subnet() or "192.168.1.0/24"
    hosts = _run_nmap_scan(subnet)
    for host in hosts:
        if not host.get("vendor"):
            host["vendor"] = _lookup_vendor(host.get("mac", ""))
    return hosts


def get_all_ips(subnet: str | None = None) -> list[str]:
    """Return list of IP addresses for all discovered hosts."""
    return [h["ip"] for h in discover_hosts(subnet)]


def main() -> None:
    subnet = sys.argv[1] if len(sys.argv) > 1 else None
    hosts = discover_hosts(subnet)
    print(json.dumps({"hosts": hosts}, ensure_ascii=False))


if __name__ == "__main__":
    print("Deprecated: use nwcd_cli.py discover-hosts", file=sys.stderr)
    main()
