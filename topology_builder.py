import json
import os
import subprocess
from typing import List, Dict

from discover_hosts import IP_RE


def traceroute(ip: str, *, timeout: int = 30) -> List[str]:
    """Run traceroute/tracert command for given IP and return list of hop IPs."""
    cmd = ["tracert", "-d", ip] if os.name == "nt" else ["traceroute", "-n", ip]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    return _parse_traceroute_output(proc.stdout)


def _parse_traceroute_output(output: str) -> List[str]:
    """Extract hop IPs from traceroute command output."""
    hops: List[str] = []
    for line in output.splitlines():
        line = line.strip()
        if line.lower().startswith("traceroute") or line.lower().startswith("tracing route"):
            continue
        for token in line.split():
            if IP_RE.fullmatch(token) and ("." in token or ":" in token):
                hops.append(token)
                break
    return hops


def _classify_hops(hops: List[str]) -> List[str]:
    """Return list of hop labels such as ['LAN', 'Router', 'Host']."""
    path: List[str] = ["LAN"] + ["Router"] * len(hops)
    if path:
        path[-1] = "Host"
    return path


def _augment_with_snmp(path: List[str], ip: str) -> List[str]:
    """Augment path information using SNMP/LLDP if pysnmp is available.

    Currently this function acts as a placeholder and returns the path
    unchanged when SNMP data cannot be retrieved.
    """
    try:
        from pysnmp.hlapi import SnmpEngine  # type: ignore
    except Exception:
        return path
    # Placeholder for SNMP/LLDP augmentation logic
    return path


def build_paths(hosts: List[Dict[str, str]], use_snmp: bool = False) -> Dict[str, List[Dict[str, List[str]]]]:
    """Build network topology paths for given hosts.

    Args:
        hosts: List of host dictionaries returned by ``discover_hosts``.
        use_snmp: When True, attempt to augment hop data using SNMP/LLDP.

    Returns:
        A dictionary containing a ``paths`` array suitable for JSON
        serialization.
    """
    results = []
    for host in hosts:
        ip = host.get("ip")
        if not ip:
            continue
        hops = traceroute(ip)
        path = _classify_hops(hops)
        if use_snmp:
            path = _augment_with_snmp(path, ip)
        results.append({"ip": ip, "path": path})
    return {"paths": results}


def main() -> None:
    from discover_hosts import discover_hosts

    hosts = discover_hosts()
    data = build_paths(hosts)
    print(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    main()
