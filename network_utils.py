#!/usr/bin/env python3
"""Utility functions for network discovery and scanning."""

import ipaddress
import os
import re
import socket
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen
import shutil

# Cache for MAC prefix to vendor lookups
_VENDOR_CACHE: dict[str, str] = {}

# Default timeout for nmap operations
SCAN_TIMEOUT = 60


def _get_subnet():
    """Return the local subnet in CIDR notation or ``None`` if undetected."""
    if os.name == "nt":
        try:
            proc = subprocess.run(["ipconfig"], capture_output=True, text=True)
            if proc.returncode == 0:
                ip = None
                mask = None
                for line in proc.stdout.splitlines():
                    if "IPv4 Address" in line or line.strip().startswith("IPv4"):
                        parts = line.split(":")
                        if len(parts) > 1:
                            ip = parts[1].strip()
                    elif "Subnet Mask" in line:
                        parts = line.split(":")
                        if len(parts) > 1:
                            mask = parts[1].strip()
                    if ip and mask:
                        break
                if ip and mask:
                    try:
                        network = ipaddress.IPv4Network(f"{ip}/{mask}", strict=False)
                        return str(network)
                    except Exception:
                        pass
        except Exception:
            pass
    elif sys.platform == "darwin":
        try:
            proc = subprocess.run(["ifconfig"], capture_output=True, text=True)
            if proc.returncode == 0:
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    m = re.search(r"inet (\d+\.\d+\.\d+\.\d+) netmask (0x[0-9a-fA-F]+)", line)
                    if m and not m.group(1).startswith("127."):
                        ip = m.group(1)
                        mask_hex = m.group(2)
                        try:
                            mask_addr = ipaddress.IPv4Address(int(mask_hex, 16))
                            network = ipaddress.IPv4Network(f"{ip}/{mask_addr}", strict=False)
                            return str(network)
                        except Exception:
                            continue
        except Exception:
            pass
    else:
        try:
            proc = subprocess.run(["ip", "addr"], capture_output=True, text=True)
            if proc.returncode == 0:
                inet = None
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    m = re.match(r"inet (\d+\.\d+\.\d+\.\d+)/(\d+)", line)
                    if m and not m.group(1).startswith("127."):
                        inet = m.group(1)
                        masklen = int(m.group(2))
                        network = ipaddress.IPv4Network(f"{inet}/{masklen}", strict=False)
                        return str(network)
        except Exception:
            pass
    return None


def _run_nmap_scan(subnet: str, *, timeout: int = SCAN_TIMEOUT):
    """Run ``nmap`` host discovery and return parsed results including hostnames."""
    cmd = ["nmap"]
    try:
        if ipaddress.ip_network(subnet, strict=False).version == 6:
            cmd.append("-6")
    except Exception:
        if ":" in subnet:
            cmd.append("-6")
    cmd += ["-R", "-sn", subnet, "-oX", "-"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError("nmap host discovery timed out")
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    root = ET.fromstring(proc.stdout)
    results = []
    for host in root.findall("host"):
        ip = None
        mac = ""
        vendor = ""
        hostname = ""
        for addr in host.findall("address"):
            if addr.get("addrtype") in ("ipv4", "ipv6"):
                ip = addr.get("addr")
            elif addr.get("addrtype") == "mac":
                mac = addr.get("addr")
                vendor = addr.get("vendor", "")
        hn = host.find("hostnames/hostname")
        if hn is not None:
            hostname = hn.get("name", "")
        if ip:
            results.append({"ip": ip, "mac": mac, "vendor": vendor, "hostname": hostname})

    for h in results:
        if h.get("hostname"):
            continue
        if ":" not in h["ip"] and shutil.which("nbtscan"):
            try:
                proc = subprocess.run(
                    ["nbtscan", "-q", h["ip"]],
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                )
                if proc.returncode == 0:
                    line = proc.stdout.strip().splitlines()
                    if line:
                        parts = line[0].split()
                        if len(parts) >= 2:
                            h["hostname"] = parts[1]
            except Exception:
                pass
        if h.get("hostname"):
            continue
        if shutil.which("avahi-resolve"):
            try:
                proc = subprocess.run(
                    ["avahi-resolve", "-a", h["ip"]],
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                )
                if proc.returncode == 0:
                    line = proc.stdout.strip().splitlines()
                    if line:
                        parts = line[0].split()
                        if len(parts) >= 2:
                            name = parts[1]
                            if name.endswith('.'):
                                name = name[:-1]
                            h["hostname"] = name
            except Exception:
                pass
    return results


def _lookup_vendor(mac: str) -> str:
    """Return vendor name for the given MAC address."""
    prefix = mac.upper().replace(":", "")[:6]

    if prefix in _VENDOR_CACHE:
        return _VENDOR_CACHE[prefix]

    db_path = Path("oui.txt")
    if db_path.exists():
        try:
            with db_path.open("r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    if line.upper().startswith(prefix):
                        vendor = line[6:].strip()
                        _VENDOR_CACHE[prefix] = vendor
                        return vendor
        except Exception:
            pass

    try:
        with urlopen(f"https://api.macvendors.com/{mac}", timeout=3) as resp:
            vendor = resp.read().decode("utf-8")
            _VENDOR_CACHE[prefix] = vendor
            return vendor
    except (URLError, socket.timeout):
        _VENDOR_CACHE[prefix] = ""
        return ""

