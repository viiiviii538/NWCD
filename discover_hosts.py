#!/usr/bin/env python3
import json
import sys
import subprocess
import xml.etree.ElementTree as ET
import ipaddress
import re
import os

IP_RE = re.compile(r'(?:\d{1,3}\.){3}\d{1,3}|[0-9a-fA-F:]+')

from network_utils import _get_subnet, _run_nmap_scan, _lookup_vendor, SCAN_TIMEOUT

def discover_hosts(subnet: str | None = None) -> list[dict[str, str]]:
    """Return list of discovered hosts with IP, MAC and vendor.

    If ``subnet`` is not provided, the local subnet is determined
    automatically. ``nmap`` is used for host discovery.
    """
    subnet = subnet or _get_subnet() or "192.168.1.0/24"
    hosts = _run_nmap_scan(subnet)
    for h in hosts:
        if not h.get("vendor"):
            h["vendor"] = _lookup_vendor(h.get("mac", ""))
    return hosts

def get_all_ips(subnet: str | None = None) -> list[str]:
    """Return list of IP addresses for all discovered hosts."""
    return [h["ip"] for h in discover_hosts(subnet)]



def main():
    subnet = None
    if len(sys.argv) > 1:
        subnet = sys.argv[1]
    hosts = discover_hosts(subnet)
    print(json.dumps({'hosts': hosts}, ensure_ascii=False))


if __name__ == '__main__':
    main()
