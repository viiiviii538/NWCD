#!/usr/bin/env python3
import json
import sys
import subprocess
import xml.etree.ElementTree as ET
import ipaddress
import re
import os

IP_RE = re.compile(r'(?:\d{1,3}\.){3}\d{1,3}|[0-9a-fA-F:]+')
from pathlib import Path
from urllib.request import urlopen

# Cache for MAC prefix to vendor lookups
_VENDOR_CACHE: dict[str, str] = {}

def _get_subnet():
    if os.name == 'nt':
        try:
            proc = subprocess.run(['ipconfig'], capture_output=True, text=True)
            if proc.returncode == 0:
                ip = None
                mask = None
                for line in proc.stdout.splitlines():
                    if 'IPv4 Address' in line or line.strip().startswith('IPv4'):
                        parts = line.split(':')
                        if len(parts) > 1:
                            ip = parts[1].strip()
                    elif 'Subnet Mask' in line:
                        parts = line.split(':')
                        if len(parts) > 1:
                            mask = parts[1].strip()
                    if ip and mask:
                        break
                if ip and mask:
                    try:
                        network = ipaddress.IPv4Network(f'{ip}/{mask}', strict=False)
                        return str(network)
                    except Exception:
                        pass
        except Exception:
            pass
    elif sys.platform == 'darwin':
        try:
            proc = subprocess.run(['ifconfig'], capture_output=True, text=True)
            if proc.returncode == 0:
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    m = re.search(r'inet (\d+\.\d+\.\d+\.\d+) netmask (0x[0-9a-fA-F]+)', line)
                    if m and not m.group(1).startswith('127.'):
                        ip = m.group(1)
                        mask_hex = m.group(2)
                        try:
                            mask_addr = ipaddress.IPv4Address(int(mask_hex, 16))
                            network = ipaddress.IPv4Network(f'{ip}/{mask_addr}', strict=False)
                            return str(network)
                        except Exception:
                            continue
        except Exception:
            pass
    else:
        try:
            proc = subprocess.run(['ip', 'addr'], capture_output=True, text=True)
            if proc.returncode == 0:
                inet = None
                mask = None
                for line in proc.stdout.splitlines():
                    line = line.strip()
                    m = re.match(r'inet (\d+\.\d+\.\d+\.\d+)/(\d+)', line)
                    if m and not m.group(1).startswith('127.'):
                        inet = m.group(1)
                        masklen = int(m.group(2))
                        network = ipaddress.IPv4Network(f'{inet}/{masklen}', strict=False)
                        return str(network)
        except Exception:
            pass
    return None


def _run_arp_scan():
    try:
        proc = subprocess.run(['arp-scan', '--localnet'], capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip())
        results = []
        for line in proc.stdout.splitlines():
            parts = line.split()  # whitespace
            if len(parts) >= 2 and IP_RE.fullmatch(parts[0]):
                vendor = ""
                if len(parts) >= 3:
                    vendor = " ".join(parts[2:])
                results.append({'ip': parts[0], 'mac': parts[1], 'vendor': vendor})
        if results:
            return results
    except Exception:
        pass
    raise RuntimeError('arp-scan failed')


def _run_nmap_scan(subnet):
    cmd = ['nmap']
    try:
        if ipaddress.ip_network(subnet, strict=False).version == 6:
            cmd.append('-6')
    except Exception:
        if ':' in subnet:
            cmd.append('-6')
    cmd += ['-sn', subnet, '-oX', '-']
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    root = ET.fromstring(proc.stdout)
    results = []
    for host in root.findall('host'):
        ip = None
        mac = ''
        vendor = ''
        name = ''
        for addr in host.findall('address'):
            if addr.get('addrtype') in ('ipv4', 'ipv6'):
                ip = addr.get('addr')
            elif addr.get('addrtype') == 'mac':
                mac = addr.get('addr')
                vendor = addr.get('vendor', '')
        hn = host.find('hostnames/hostname')
        if hn is not None:
            name = hn.get('name', '')
        if ip:
            results.append({'ip': ip, 'mac': mac, 'vendor': vendor, 'name': name})
    return results


def _lookup_vendor(mac):
    prefix = mac.upper().replace(':', '')[:6]

    if prefix in _VENDOR_CACHE:
        return _VENDOR_CACHE[prefix]

    db_path = Path('oui.txt')
    if db_path.exists():
        try:
            with db_path.open('r', encoding='utf-8', errors='ignore') as f:
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
        with urlopen(f'https://api.macvendors.com/{mac}') as resp:
            vendor = resp.read().decode('utf-8')
            _VENDOR_CACHE[prefix] = vendor
            return vendor
    except Exception:
        _VENDOR_CACHE[prefix] = ''
        return ''


def main():
    subnet = None
    if len(sys.argv) > 1:
        subnet = sys.argv[1]
    subnet = subnet or _get_subnet() or '192.168.1.0/24'
    try:
        hosts = _run_arp_scan()
    except Exception:
        hosts = _run_nmap_scan(subnet)
    for h in hosts:
        if not h.get('vendor'):
            h['vendor'] = _lookup_vendor(h.get('mac', ''))
    print(json.dumps({'hosts': hosts}, ensure_ascii=False))


if __name__ == '__main__':
    main()
