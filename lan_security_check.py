#!/usr/bin/env python3
"""Run LAN security diagnostics and output JSON results."""
from __future__ import annotations

import json
import subprocess
import re
from typing import Dict, List, Any
import sys

from discover_hosts import _get_subnet

from external_ip_report import (
    get_external_connections,
    geoip_country,
    geoip2,
)

from common_constants import DANGER_COUNTRIES


def _default_subnet() -> str:
    """Return detected subnet or a reasonable default."""
    return _get_subnet() or "192.168.1.0/24"


def parse_arp_table(output: str) -> Dict[str, List[str]]:
    table: Dict[str, List[str]] = {}
    for line in output.splitlines():
        m = re.search(r"(\d+\.\d+\.\d+\.\d+).*?([0-9A-Fa-f:-]{17})", line)
        if not m:
            continue
        ip = m.group(1)
        mac = m.group(2).lower().replace("-", ":")
        table.setdefault(ip, []).append(mac)
    return table


def check_arp_spoofing() -> Dict[str, Any]:
    try:
        proc = subprocess.run(["arp", "-a"], capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        table = parse_arp_table(proc.stdout)
        suspicious = [ip for ip, macs in table.items() if len(set(macs)) > 1]
        if suspicious:
            return {
                "status": "warning",
                "details": f"Multiple MAC addresses for {', '.join(suspicious)}",
                "utm": ["ips"],
            }
        return {"status": "ok"}
    except Exception as e:
        return {"status": "unknown", "details": str(e)}


def parse_upnp_output(output: str) -> bool:
    return "UPnP" in output or "upnp" in output


def check_upnp(subnet: str) -> Dict[str, Any]:
    cmds = [
        ["upnpc", "-l"],
        ["nmap", "-p", "1900", "-sU", "--script", "upnp-info", "-oN", "-", subnet],
    ]
    for cmd in cmds:
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True)
            if proc.returncode == 0 and parse_upnp_output(proc.stdout):
                return {
                    "status": "warning",
                    "details": "UPnP service detected",
                    "utm": ["firewall"],
                }
            if proc.returncode == 0:
                return {"status": "ok"}
        except FileNotFoundError:
            continue
        except Exception as e:
            return {"status": "unknown", "details": str(e)}
    return {"status": "unknown", "details": "no scanner"}


def parse_netbios_output(output: str) -> List[str]:
    hosts = []
    for line in output.splitlines():
        if "/open/" in line and re.search(r"(\d+\.\d+\.\d+\.\d+)", line):
            m = re.search(r"Host: (\S+)", line)
            if m:
                hosts.append(m.group(1))
    return hosts


def check_netbios(subnet: str) -> Dict[str, Any]:
    cmd = ["nmap", "-p", "137,138,139,445", "--open", "-oG", "-", subnet]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        hosts = parse_netbios_output(proc.stdout)
        if hosts:
            return {
                "status": "warning",
                "details": f"SMB/NetBIOS open on {', '.join(hosts)}",
                "utm": ["ips"],
            }
        return {"status": "ok"}
    except Exception as e:
        return {"status": "unknown", "details": str(e)}


def parse_dhcp_output(output: str) -> int:
    return len(re.findall(r"Server Identifier", output))


def check_dhcp_multiple() -> Dict[str, Any]:
    cmd = ["nmap", "--script", "broadcast-dhcp-discover"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        count = parse_dhcp_output(proc.stdout)
        if count > 1:
            return {
                "status": "warning",
                "details": f"Multiple DHCP servers detected: {count}",
                "utm": ["ips"],
            }
        return {"status": "ok"}
    except Exception as e:
        return {"status": "unknown", "details": str(e)}


def parse_smb_protocol_output(output: str) -> bool:
    return "SMBv1" in output or "SMB1" in output


def check_smb_protocol(subnet: str) -> Dict[str, Any]:
    cmd = ["nmap", "-p", "445", "--script", "smb-protocols", "-oN", "-", subnet]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        if parse_smb_protocol_output(proc.stdout):
            return {
                "status": "warning",
                "details": "SMBv1 enabled",
                "utm": ["ips"],
            }
        return {"status": "ok"}
    except Exception as e:
        return {"status": "unknown", "details": str(e)}


def check_external_comm(geoip_db: str = "GeoLite2-Country.mmdb") -> Dict[str, Any]:
    try:
        conns = get_external_connections()
    except Exception as e:
        return {"status": "unknown", "details": str(e)}
    reader = None
    if geoip2 is not None:
        try:
            reader = geoip2.database.Reader(geoip_db)
        except Exception:
            print("GeoIP database not found \u2013 country information disabled.")
            reader = None
    else:
        print("GeoIP database not found \u2013 country information disabled.")
    suspicious = []
    country_counts: Dict[str, int] = {}
    for ip, _ in conns:
        country = geoip_country(reader, ip)
        if country:
            country_counts[country] = country_counts.get(country, 0) + 1
        if country in DANGER_COUNTRIES:
            suspicious.append({"ip": ip, "country": country})
    if reader:
        reader.close()
    result: Dict[str, Any] = {"status": "ok", "country_counts": country_counts}
    if suspicious:
        result.update(
            {
                "status": "warning",
                "connections": suspicious,
                "utm": ["web_filter"],
            }
        )
    return result


def run_checks(subnet: str | None = None) -> Dict[str, Any]:
    """Run all LAN security checks and return results."""
    subnet = subnet or _default_subnet()
    results = {
        "arp_spoofing": check_arp_spoofing(),
        "upnp": check_upnp(subnet),
        "netbios": check_netbios(subnet),
        "dhcp": check_dhcp_multiple(),
        "external_comm": check_external_comm(),
        "smb_protocol": check_smb_protocol(subnet),
    }
    utm = set()
    for res in results.values():
        if res.get("status") == "warning":
            utm.update(res.get("utm", []))
    results["utm_recommendations"] = sorted(utm)
    return results


def main() -> None:
    subnet = sys.argv[1] if len(sys.argv) > 1 else None
    results = run_checks(subnet)
    print(json.dumps(results, ensure_ascii=False))


if __name__ == "__main__":
    print("Deprecated: use nwcd_cli.py lan-check", file=sys.stderr)
    main()
